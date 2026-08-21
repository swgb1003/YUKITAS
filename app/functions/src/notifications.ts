import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";

import { BOARD_CELL_PRECISION, encodeGeohash } from "./geo";

const REGION = "asia-northeast1";

interface RequestDoc {
  ownerId: string;
  location: FirebaseFirestore.GeoPoint;
  placeName: string;
  workerId: string | null;
  workerName: string | null;
  status: string;
  isSos: boolean;
  rating: number | null;
  disputedBy: string | null;
}

/**
 * Pushes the requester (or, for cancellations/ratings, the worker) when a
 * request's status - or its rating, which changes without a status change -
 * moves forward. One notification per meaningful transition; anything not
 * listed here (e.g. draft->waiting, working) isn't user-facing enough to
 * interrupt someone for.
 */
export const notifyOnRequestChange = onDocumentUpdated(
  { document: "requests/{requestId}", region: REGION },
  async (event) => {
    const before = event.data?.before.data() as RequestDoc | undefined;
    const after = event.data?.after.data() as RequestDoc | undefined;
    if (!before || !after) return;

    const notifications = buildChangeNotifications(before, after);
    for (const notification of notifications) {
      await sendToUser(notification.userId, notification.title, notification.body, {
        requestId: event.params.requestId,
      });
    }
  },
);

/**
 * Pushes workers in the request's own area when a new request opens up.
 *
 * Scoped to one geohash cell rather than a single global 'workers' topic,
 * which pushed every request in the country to every worker in it. The body
 * deliberately omits `placeName`: this reaches workers who have not accepted
 * anything, and the place name is often the household's own words for where
 * they live.
 */
export const notifyWorkersOnNewRequest = onDocumentCreated(
  { document: "requests/{requestId}", region: REGION },
  async (event) => {
    const data = event.data?.data() as RequestDoc | undefined;
    if (!data || data.status !== "waiting" || !data.location) return;

    const cell = encodeGeohash(
      data.location.latitude,
      data.location.longitude,
    ).slice(0, BOARD_CELL_PRECISION);

    const title = data.isSos ? "🚨 緊急SOS依頼が届きました" : "新しい除雪依頼があります";
    const body = "お近くで対応できる方はアプリからご確認ください";
    await sendToTopic(`cell_${cell}`, title, body, {
      requestId: event.params.requestId,
    });
  },
);

function buildChangeNotifications(
  before: RequestDoc,
  after: RequestDoc,
): { userId: string; title: string; body: string }[] {
  const notifications: { userId: string; title: string; body: string }[] = [];

  if (before.status !== after.status) {
    const forOwner = ownerStatusNotification(after);
    if (forOwner) notifications.push({ userId: after.ownerId, ...forOwner });

    if (after.status === "cancelled" && after.workerId) {
      notifications.push({
        userId: after.workerId,
        title: "依頼がキャンセルされました",
        body: `${after.placeName}の依頼はキャンセルされました`,
      });
    }

    if (after.status === "expired") {
      notifications.push({
        userId: after.ownerId,
        title: "依頼の募集期限が切れました",
        body: "対応できるワーカーが見つかりませんでした。時間帯を変えて再度ご依頼ください",
      });
    }

    if (
      before.status !== "waiting" &&
      after.status === "waiting" &&
      before.workerId
    ) {
      notifications.push({
        userId: after.ownerId,
        title: "担当ワーカーが対応できなくなりました",
        body: "他のワーカーを再度お探ししています",
      });
    }

    if (after.status === "disputed") {
      const otherPartyId =
        after.disputedBy === after.ownerId ? after.workerId : after.ownerId;
      if (otherPartyId) {
        notifications.push({
          userId: otherPartyId,
          title: "問題が報告されました",
          body: `${after.placeName}の依頼で問題が報告されました。内容を確認してください`,
        });
      }
    }
  }

  // A settled dispute concerns both sides, so both are told.
  if (before.status === "disputed" && after.status !== "disputed") {
    const settled =
      after.status === "completed"
        ? "作業完了として処理されました"
        : "キャンセル・返金として処理されました";
    notifications.push({
      userId: after.ownerId,
      title: "報告された問題が解決しました",
      body: `${after.placeName}の依頼は${settled}`,
    });
    if (after.workerId) {
      notifications.push({
        userId: after.workerId,
        title: "報告された問題が解決しました",
        body: `担当された依頼は${settled}`,
      });
    }
  }

  if (before.rating == null && after.rating != null && after.workerId) {
    notifications.push({
      userId: after.workerId,
      title: "評価が届きました",
      body: `${after.placeName}の依頼で評価★${after.rating}を受け取りました`,
    });
  }

  return notifications;
}

function ownerStatusNotification(
  after: RequestDoc,
): { title: string; body: string } | null {
  switch (after.status) {
    case "matched":
      return {
        title: "ワーカーが見つかりました",
        body: `${after.workerName ?? "担当のワーカー"}さんが除雪に向かいます`,
      };
    case "moving":
      return { title: "ワーカーが向かっています", body: "まもなく現地に到着予定です" };
    case "arrived":
      return { title: "ワーカーが到着しました", body: "まもなく作業が始まります" };
    case "reviewing":
      return {
        title: "除雪作業が完了しました",
        body: "完了写真が届きました。内容をご確認ください",
      };
    default:
      return null;
  }
}

async function sendToUser(
  userId: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<void> {
  const userRef = getFirestore().collection("users").doc(userId);
  const userDoc = await userRef.get();
  const tokens = (userDoc.get("fcmTokens") as string[] | undefined) ?? [];
  if (tokens.length === 0) return;

  const response = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
  });

  const staleTokens = tokens.filter((_, index) => {
    const error = response.responses[index].error;
    return (
      error?.code === "messaging/registration-token-not-registered" ||
      error?.code === "messaging/invalid-registration-token"
    );
  });
  if (staleTokens.length > 0) {
    await userRef.update({
      fcmTokens: FieldValue.arrayRemove(...staleTokens),
    });
  }
  if (response.failureCount > 0) {
    logger.warn("Some push notifications failed", {
      userId,
      failureCount: response.failureCount,
      staleTokenCount: staleTokens.length,
    });
  }
}

async function sendToTopic(
  topic: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<void> {
  try {
    await getMessaging().send({ topic, notification: { title, body }, data });
  } catch (error) {
    logger.error("Topic push failed", { topic, error: String(error) });
  }
}
