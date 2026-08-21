import { FieldValue, GeoPoint, getFirestore } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";

import { BOARD_CELL_PRECISION, encodeGeohash, geohashCenter } from "./geo";

const REGION = "asia-northeast1";

/**
 * Statuses that belong on the public board: open jobs so workers can take
 * them, in-progress jobs so the community map shows current activity.
 * Anything past that is no longer activity and is removed.
 */
const BOARD_STATUSES = new Set([
  "waiting",
  "matched",
  "moving",
  "arrived",
  "working",
  "reviewing",
]);

interface RequestDoc {
  ownerId: string;
  location: GeoPoint;
  workAreas: string[];
  areaSqm: number;
  snowDepthCm: number;
  difficulty: number;
  estimatedMinutes: number;
  priceYen: number;
  isSos: boolean;
  status: string;
  createdAt: FirebaseFirestore.Timestamp;
}

/**
 * Mirrors each request onto `requestBoard`, the only view of other people's
 * requests a client is allowed to read.
 *
 * Firestore rules grant or deny a whole document, so a request that every
 * worker can read is a request whose address and photos every worker can
 * read. Splitting the document is what makes AC-08 enforceable rather than
 * merely intended: the full request stays restricted to its owner and
 * assigned worker, and only the fields written here go out to everyone.
 *
 * What is deliberately NOT copied: the exact coordinate (a cell center goes
 * out instead), `approximateAddress`, `beforeImageAsset`/`afterImageAsset`,
 * and `sosReason` - which describes the resident's circumstances and, next
 * to a precise location, is exactly what makes a household a target.
 */
export const syncRequestBoard = onDocumentWritten(
  { document: "requests/{requestId}", region: REGION },
  async (event) => {
    const requestId = event.params.requestId;
    const boardRef = getFirestore().collection("requestBoard").doc(requestId);
    const after = event.data?.after.data() as RequestDoc | undefined;

    if (!after || !BOARD_STATUSES.has(after.status)) {
      try {
        await boardRef.delete();
      } catch (error) {
        logger.warn("Could not remove board entry", {
          requestId,
          error: String(error),
        });
      }
      return;
    }

    const location = after.location;
    if (!location) {
      logger.error("Request has no location; skipping board sync", {
        requestId,
      });
      return;
    }

    const hash = encodeGeohash(location.latitude, location.longitude);
    const center = geohashCenter(hash);

    await boardRef.set({
      ownerId: after.ownerId,
      cell: hash.slice(0, BOARD_CELL_PRECISION),
      coarseLocation: new GeoPoint(center.latitude, center.longitude),
      workAreas: after.workAreas ?? [],
      areaSqm: after.areaSqm ?? 0,
      snowDepthCm: after.snowDepthCm ?? 0,
      difficulty: after.difficulty ?? 1,
      estimatedMinutes: after.estimatedMinutes ?? 0,
      priceYen: after.priceYen ?? 0,
      isSos: after.isSos ?? false,
      status: after.status,
      createdAt: after.createdAt ?? FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  },
);
