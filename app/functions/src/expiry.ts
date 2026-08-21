import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";

const REGION = "asia-northeast1";

/**
 * How long an unclaimed request stays open.
 *
 * Snow removal is worth something because it happens before the morning
 * commute; a request nobody took overnight has no value left, and leaving it
 * "募集中" on the map indefinitely misleads both sides - the requester thinks
 * help may still come, and workers scroll past dead listings. Six hours is
 * long enough to survive a quiet night and short enough that the board only
 * ever shows work someone could still turn up for.
 */
const EXPIRY_HOURS = 6;

/** Firestore caps a batch at 500 writes. */
const BATCH_LIMIT = 400;

/**
 * Closes out requests nobody accepted.
 *
 * This is the missing counterpart to publishing: before it existed, a
 * `waiting` request had no path out except being accepted, so an unmatched
 * request simply stayed open forever.
 */
export const expireStaleRequests = onSchedule(
  { schedule: "every 30 minutes", region: REGION, timeoutSeconds: 120 },
  async () => {
    const cutoff = new Date(Date.now() - EXPIRY_HOURS * 60 * 60 * 1000);
    const stale = await getFirestore()
      .collection("requests")
      .where("status", "==", "waiting")
      .where("createdAt", "<=", cutoff)
      .limit(BATCH_LIMIT)
      .get();

    if (stale.empty) return;

    const batch = getFirestore().batch();
    for (const document of stale.docs) {
      batch.update(document.ref, {
        status: "expired",
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    logger.info("Expired unclaimed requests", { count: stale.size });
  },
);
