import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";

const REGION = "asia-northeast1";
const REGION_ID = "niigata-shi";
const NIIGATA_LAT = 37.9161;
const NIIGATA_LNG = 139.0364;

// Matches SnowfallForecast.heavySnowThresholdCm on the client (spec 06.2:
// 大雪しきい値→家族へ通知).
const HEAVY_SNOW_THRESHOLD_CM = 20;

interface WeatherSnapshot {
  temperatureC: number;
  expectedSnowfallCm: number;
}

interface OpenMeteoResponse {
  current?: { temperature_2m?: number };
  daily?: { snowfall_sum?: number[] };
}

/**
 * Fetches the current temperature and tomorrow's expected snowfall for
 * Niigata city from Open-Meteo, which needs no API key - matching spec
 * 07章's "コンテスト版は固定/キャッシュ済み予報でも成立させる" while still
 * showing real conditions instead of a value baked into the client.
 */
async function fetchNiigataForecast(): Promise<WeatherSnapshot> {
  const url =
    `https://api.open-meteo.com/v1/forecast?latitude=${NIIGATA_LAT}&longitude=${NIIGATA_LNG}` +
    "&current=temperature_2m&daily=snowfall_sum&timezone=Asia%2FTokyo&forecast_days=2";
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Open-Meteo request failed: ${response.status}`);
  }
  const data = (await response.json()) as OpenMeteoResponse;
  const temperatureC = data.current?.temperature_2m;
  const tomorrowSnowfallCm = data.daily?.snowfall_sum?.[1];
  if (temperatureC == null || tomorrowSnowfallCm == null) {
    throw new Error("Open-Meteo response was missing expected fields");
  }
  return {
    temperatureC: Math.round(temperatureC),
    expectedSnowfallCm: Math.max(0, Math.round(tomorrowSnowfallCm)),
  };
}

/**
 * Refreshes `weatherSnapshots/niigata-shi` so the home screen's forecast
 * card (spec 06.2 降雪予測) reflects real conditions. Runs every 3 hours -
 * frequent enough for a same-day demo without hammering the free API.
 */
export const refreshWeatherSnapshot = onSchedule(
  { schedule: "every 3 hours", region: REGION, timeoutSeconds: 30 },
  async () => {
    let snapshot: WeatherSnapshot;
    try {
      snapshot = await fetchNiigataForecast();
    } catch (error) {
      logger.error("Weather forecast fetch failed", { error: String(error) });
      return;
    }
    await getFirestore().collection("weatherSnapshots").doc(REGION_ID).set({
      ...snapshot,
      updatedAt: FieldValue.serverTimestamp(),
    });
  },
);

/**
 * Pushes registered family homes (spec 03章 遠隔家族依頼: savedPlaces with
 * notifyOnSnowfall=true) when a refreshed snapshot crosses the heavy-snow
 * threshold, matching the 06.2 flow "天気API→登録地点照合→大雪しきい値→家族へ通知".
 * Only fires on the transition into a heavy-snow forecast so a family isn't
 * re-notified every 3 hours while the same storm is still forecast.
 */
export const notifyFamilyOnHeavySnowfall = onDocumentWritten(
  { document: "weatherSnapshots/{regionId}", region: REGION },
  async (event) => {
    const before = event.data?.before.data() as
      | { expectedSnowfallCm?: number }
      | undefined;
    const after = event.data?.after.data() as
      | { expectedSnowfallCm?: number }
      | undefined;
    if (!after) return;

    const wasHeavy = (before?.expectedSnowfallCm ?? 0) >= HEAVY_SNOW_THRESHOLD_CM;
    const isHeavy = (after.expectedSnowfallCm ?? 0) >= HEAVY_SNOW_THRESHOLD_CM;
    if (!isHeavy || wasHeavy) return;

    const tokens = await fcmTokensForFamiliesToNotify();
    if (tokens.length === 0) return;

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: "大雪が予想されています",
        body: `明朝、${after.expectedSnowfallCm}cmの降雪予報です。登録した場所の除雪を早めに依頼できます。`,
      },
      data: { expectedSnowfallCm: String(after.expectedSnowfallCm ?? "") },
    });
    if (response.failureCount > 0) {
      logger.warn("Some heavy-snowfall pushes failed", {
        failureCount: response.failureCount,
      });
    }
  },
);

async function fcmTokensForFamiliesToNotify(): Promise<string[]> {
  const places = await getFirestore()
    .collectionGroup("savedPlaces")
    .where("notifyOnSnowfall", "==", true)
    .get();

  const userIds = new Set<string>();
  for (const doc of places.docs) {
    const userId = doc.ref.parent.parent?.id;
    if (userId) userIds.add(userId);
  }

  const tokenLists = await Promise.all(
    Array.from(userIds).map(async (userId) => {
      const userDoc = await getFirestore().collection("users").doc(userId).get();
      return (userDoc.get("fcmTokens") as string[] | undefined) ?? [];
    }),
  );
  return tokenLists.flat();
}
