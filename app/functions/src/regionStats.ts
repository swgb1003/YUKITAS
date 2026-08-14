import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";

const REGION = "asia-northeast1";

// matched/moving/arrived/working/reviewing - a job is "active" from the
// moment a worker takes it until the requester approves completion.
const ACTIVE_STATUSES = new Set([
  "matched",
  "moving",
  "arrived",
  "working",
  "reviewing",
]);

interface RequestDoc {
  status: string;
  isSos: boolean;
}

/**
 * Keeps `regionStats/summary` in sync with every status change, so the
 * requester home screen's 本日完了/SOS支援/活動中 counters (and the
 * completion screen's LOCAL IMPACT card) reflect real activity instead of
 * the placeholder numbers the UI shipped with.
 */
export const updateRegionStats = onDocumentUpdated(
  { document: "requests/{requestId}", region: REGION },
  async (event) => {
    const before = event.data?.before.data() as RequestDoc | undefined;
    const after = event.data?.after.data() as RequestDoc | undefined;
    if (!before || !after || before.status === after.status) return;

    const wasActive = ACTIVE_STATUSES.has(before.status);
    const isActive = ACTIVE_STATUSES.has(after.status);
    const activeDelta = Number(isActive) - Number(wasActive);
    const justCompleted =
      before.status !== "completed" && after.status === "completed";

    if (activeDelta === 0 && !justCompleted) return;

    await applyRegionStatsUpdate({
      activeDelta,
      completedIncrement: justCompleted ? 1 : 0,
      sosIncrement: justCompleted && after.isSos ? 1 : 0,
    });
  },
);

async function applyRegionStatsUpdate(delta: {
  activeDelta: number;
  completedIncrement: number;
  sosIncrement: number;
}): Promise<void> {
  const ref = getFirestore().collection("regionStats").doc("summary");
  const today = jstDateString();

  await getFirestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data() ?? {};
    // completedToday/sosSupportedToday reset the first time a write lands
    // on a new JST day; activeNow is a live gauge and never resets.
    const sameDay = data.date === today;
    const completedToday =
      (sameDay ? (data.completedToday as number | undefined) ?? 0 : 0) +
      delta.completedIncrement;
    const sosSupportedToday =
      (sameDay ? (data.sosSupportedToday as number | undefined) ?? 0 : 0) +
      delta.sosIncrement;
    const activeNow = Math.max(
      0,
      ((data.activeNow as number | undefined) ?? 0) + delta.activeDelta,
    );

    transaction.set(ref, {
      date: today,
      completedToday,
      sosSupportedToday,
      activeNow,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

function jstDateString(): string {
  const jstMillis = Date.now() + 9 * 60 * 60 * 1000;
  return new Date(jstMillis).toISOString().slice(0, 10);
}
