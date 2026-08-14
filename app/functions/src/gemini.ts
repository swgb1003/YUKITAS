export interface GeminiAnalysisResult {
  snowDepthCm: number;
  difficulty: number;
  estimatedMinutes: number;
  confidence: number;
  hazards: string[];
}

// A subset of the OpenAPI schema Gemini's structured output accepts. Keeping
// the model to exactly these fields avoids free-text JSON parsing failures.
const RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    snowDepthCm: {
      type: "integer",
      description: "Estimated snow depth in centimeters, 0-200.",
    },
    difficulty: {
      type: "integer",
      description: "Work difficulty from 1 (easy) to 5 (hard).",
    },
    estimatedMinutes: {
      type: "integer",
      description:
        "Estimated minutes for one worker to clear the given area.",
    },
    confidence: {
      type: "number",
      description: "Confidence in this estimate, from 0 to 1.",
    },
    hazards: {
      type: "array",
      items: { type: "string" },
      description:
        "Short Japanese phrases describing hazards visible in the photo " +
        "(steps, parked vehicles, obstacles, poor visibility). Empty array " +
        "if none are visible.",
    },
  },
  required: [
    "snowDepthCm",
    "difficulty",
    "estimatedMinutes",
    "confidence",
    "hazards",
  ],
};

function buildPrompt(workAreas: string[], selectedAreaSqm: number): string {
  return [
    "あなたは日本の積雪地域における除雪作業の写真解析アシスタントです。",
    "提供された除雪前の写真をもとに、除雪作業の見積りに使う情報を推定してください。",
    `作業箇所: ${workAreas.length > 0 ? workAreas.join("、") : "指定なし"}`,
    `依頼者が選択したおおよその作業面積: 約${selectedAreaSqm}平方メートル`,
    "この面積を前提に、写真に写る積雪の深さ・作業難易度・所要時間・注意点を推定してください。",
    "estimatedMinutesは1人の作業者がこの面積を除雪するのにかかるおおよその分数です。",
    "hazardsには、写真から確認できる具体的な注意点のみを日本語の短い句で最大4件まで挙げてください（見えない場合は空配列にしてください）。",
    "安全性や結果を断定せず、あくまで参考情報としての推定値を返してください。",
  ].join("\n");
}

export async function analyzePhotoWithGemini(options: {
  apiKey: string;
  model: string;
  imageBase64: string;
  mimeType: string;
  workAreas: string[];
  selectedAreaSqm: number;
  timeoutMs: number;
}): Promise<GeminiAnalysisResult> {
  const {
    apiKey,
    model,
    imageBase64,
    mimeType,
    workAreas,
    selectedAreaSqm,
    timeoutMs,
  } = options;
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  let response: Response;
  try {
    response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            role: "user",
            parts: [
              { text: buildPrompt(workAreas, selectedAreaSqm) },
              { inlineData: { mimeType, data: imageBase64 } },
            ],
          },
        ],
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: RESPONSE_SCHEMA,
          temperature: 0.2,
        },
      }),
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeout);
  }

  if (!response.ok) {
    const body = await response.text().catch(() => "");
    throw new Error(`Gemini API error ${response.status}: ${body.slice(0, 500)}`);
  }

  const payload = (await response.json()) as {
    candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
  };
  const text = payload.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error("Gemini response did not include any content");

  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch (error) {
    throw new Error(
      `Gemini response was not valid JSON: ${(error as Error).message}`,
    );
  }

  return validateAnalysisResult(parsed);
}

function validateAnalysisResult(value: unknown): GeminiAnalysisResult {
  if (typeof value !== "object" || value === null) {
    throw new Error("Gemini response was not a JSON object");
  }
  const data = value as Record<string, unknown>;
  const snowDepthCm = clamp(toNumber(data.snowDepthCm, "snowDepthCm"), 0, 200);
  const difficulty = Math.round(
    clamp(toNumber(data.difficulty, "difficulty"), 1, 5),
  );
  const estimatedMinutes = Math.round(
    clamp(toNumber(data.estimatedMinutes, "estimatedMinutes"), 10, 240),
  );
  const confidence = clamp(toNumber(data.confidence, "confidence"), 0, 1);
  const hazards = Array.isArray(data.hazards)
    ? data.hazards
        .filter(
          (item): item is string =>
            typeof item === "string" && item.trim().length > 0,
        )
        .slice(0, 4)
    : [];

  return {
    snowDepthCm: Math.round(snowDepthCm),
    difficulty,
    estimatedMinutes,
    confidence,
    hazards,
  };
}

function toNumber(value: unknown, field: string): number {
  const num = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(num)) {
    throw new Error(`Gemini response field "${field}" was not a number`);
  }
  return num;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}
