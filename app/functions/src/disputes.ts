import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

const REGION = "asia-northeast1";

/**
 * How a dispute was settled. `disputed` used to have no outgoing transition
 * at all, which left the payment stuck on `authorized` forever: the worker
 * was never paid, the requester was never charged or refunded, and nobody
 * could close the job. These are the exits.
 */
const OUTCOMES = {
  /** The work stands. Job completes, worker is paid. */
  payWorker: {
    status: "completed",
    paymentStatus: "paid",
  },
  /** The work does not stand. Job is cancelled, requester is refunded. */
  refundRequester: {
    status: "cancelled",
    paymentStatus: "refunded",
  },
} as const;

type Outcome = keyof typeof OUTCOMES;

function isOutcome(value: unknown): value is Outcome {
  return typeof value === "string" && value in OUTCOMES;
}

/**
 * Settles a disputed request. Operator-only: resolution is the one
 * transition neither party may make for themselves, since both have a stake
 * in the outcome. Firestore rules deny every client write out of `disputed`,
 * so this callable (running under the Admin SDK) is the only way through.
 *
 * Guarded by an `admin` custom claim, set out of band on operator accounts.
 */
export const resolveDispute = onCall(
  { region: REGION, timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "サインインが必要です。");
    }
    if (request.auth.token.admin !== true) {
      throw new HttpsError(
        "permission-denied",
        "この操作は運営アカウントのみ実行できます。",
      );
    }

    const data = (request.data ?? {}) as Record<string, unknown>;
    const { requestId, outcome, note } = data;

    if (typeof requestId !== "string" || requestId.length === 0) {
      throw new HttpsError("invalid-argument", "requestIdが必要です。");
    }
    if (!isOutcome(outcome)) {
      throw new HttpsError(
        "invalid-argument",
        "outcomeはpayWorkerまたはrefundRequesterを指定してください。",
      );
    }
    if (typeof note !== "string" || note.trim().length === 0) {
      throw new HttpsError("invalid-argument", "判断理由の記録が必要です。");
    }

    const reference = getFirestore().collection("requests").doc(requestId);
    const resolution = OUTCOMES[outcome];

    await getFirestore().runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "依頼が見つかりません。");
      }
      if (snapshot.get("status") !== "disputed") {
        throw new HttpsError(
          "failed-precondition",
          "この依頼は問題報告中ではありません。",
        );
      }
      transaction.update(reference, {
        status: resolution.status,
        paymentStatus: resolution.paymentStatus,
        resolutionNote: note.trim().slice(0, 1000),
        resolvedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    logger.info("Dispute resolved", {
      requestId,
      outcome,
      resolvedBy: request.auth.uid,
    });
    return { status: resolution.status };
  },
);
