import { getStorage } from "firebase-admin/storage";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret, defineString } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";

import { analyzePhotoWithGemini } from "./gemini";

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
// Override in functions/.env (see .env.example) without touching this file.
const GEMINI_MODEL = defineString("GEMINI_MODEL", {
  default: "gemini-flash-lite-latest",
});

// Only "before" photos the caller themselves uploaded may be analyzed -
// matches the Storage path convention from FirebaseRequestPhotoStorage.
const STORAGE_PATH_PATTERN = /^requestMedia\/[^/]+\/before\/([^/]+)\/[^/]+$/;
const MAX_IMAGE_BYTES = 10 * 1024 * 1024;
const GEMINI_TIMEOUT_MS = 45_000;

interface AnalyzeRequest {
  storagePath: string;
  workAreas: string[];
  selectedAreaSqm: number;
}

export const analyzeSnowPhoto = onCall(
  {
    region: "asia-northeast1",
    secrets: [GEMINI_API_KEY],
    timeoutSeconds: 60,
    memory: "512MiB",
  },
  async (request) => {
    const auth = request.auth;
    if (!auth) {
      throw new HttpsError("unauthenticated", "サインインが必要です。");
    }

    const data = parseRequest(request.data);
    const ownerMatch = STORAGE_PATH_PATTERN.exec(data.storagePath);
    if (!ownerMatch || ownerMatch[1] !== auth.uid) {
      throw new HttpsError("permission-denied", "この写真を解析する権限がありません。");
    }

    const bucket = getStorage().bucket();
    const file = bucket.file(data.storagePath);
    const [exists] = await file.exists();
    if (!exists) {
      throw new HttpsError("not-found", "写真が見つかりませんでした。");
    }

    const [metadata] = await file.getMetadata();
    const size = Number(metadata.size ?? 0);
    if (size <= 0 || size > MAX_IMAGE_BYTES) {
      throw new HttpsError("invalid-argument", "写真のサイズが不正です。");
    }
    const mimeType = metadata.contentType ?? "image/jpeg";

    const [buffer] = await file.download();

    try {
      const result = await analyzePhotoWithGemini({
        apiKey: GEMINI_API_KEY.value(),
        model: GEMINI_MODEL.value(),
        imageBase64: buffer.toString("base64"),
        mimeType,
        workAreas: data.workAreas,
        selectedAreaSqm: data.selectedAreaSqm,
        timeoutMs: GEMINI_TIMEOUT_MS,
      });
      return { ...result, areaSqm: data.selectedAreaSqm };
    } catch (error) {
      logger.error("Gemini snow analysis failed", {
        error: String(error),
        storagePath: data.storagePath,
      });
      if (error instanceof Error && error.name === "AbortError") {
        throw new HttpsError("deadline-exceeded", "AI解析がタイムアウトしました。");
      }
      throw new HttpsError("internal", "AI解析に失敗しました。");
    }
  },
);

function parseRequest(data: unknown): AnalyzeRequest {
  if (typeof data !== "object" || data === null) {
    throw new HttpsError("invalid-argument", "リクエスト形式が不正です。");
  }
  const value = data as Record<string, unknown>;
  const { storagePath, workAreas, selectedAreaSqm } = value;

  if (typeof storagePath !== "string" || storagePath.length === 0) {
    throw new HttpsError("invalid-argument", "storagePathが必要です。");
  }
  if (
    !Array.isArray(workAreas) ||
    !workAreas.every((item) => typeof item === "string")
  ) {
    throw new HttpsError("invalid-argument", "workAreasが不正です。");
  }
  if (
    typeof selectedAreaSqm !== "number" ||
    !Number.isFinite(selectedAreaSqm) ||
    selectedAreaSqm <= 0
  ) {
    throw new HttpsError("invalid-argument", "selectedAreaSqmが不正です。");
  }

  return { storagePath, workAreas: workAreas as string[], selectedAreaSqm };
}
