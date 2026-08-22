import '../../core/geo/geo_cell.dart';
import 'snow_request.dart';

/// The public projection of an open request - everything a worker needs to
/// decide whether to take a job, and nothing that identifies the household.
///
/// This exists because Firestore rules grant or deny a whole document: there
/// is no way to let every signed-in user read a request's price while hiding
/// its address. So the full request stays readable only by its owner and
/// assigned worker, and Cloud Functions mirror this subset into a separate
/// `requestBoard` collection (see functions/src/requestBoard.ts).
///
/// Deliberately absent, per spec 08.4 and acceptance criterion AC-08
/// ("未受注ユーザーは正確な住所・画像へアクセスできない"):
///  - the exact coordinate (only a [publicLocationPrecision] cell center)
///  - the street address and access notes
///  - the before/after photos
///  - [SnowRequest.sosReason], which describes the resident's circumstances
///
/// The AI-derived figures below carry the decision instead, and are better
/// signal for judging a job than a photo of someone's driveway.
class RequestSummary {
  const RequestSummary({
    required this.id,
    required this.ownerId,
    required this.cell,
    required this.coarseLatitude,
    required this.coarseLongitude,
    required this.workAreas,
    required this.areaSqm,
    required this.snowDepthCm,
    required this.difficulty,
    required this.estimatedMinutes,
    required this.priceYen,
    required this.isSos,
    required this.parkingAvailable,
    required this.toolsProvided,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String ownerId;

  /// The [boardCellPrecision] geohash cell this request is bucketed into.
  final String cell;

  /// Center of the request's [publicLocationPrecision] cell - roughly within
  /// a kilometre of the real address, never the address itself.
  final double coarseLatitude;
  final double coarseLongitude;

  final List<String> workAreas;
  final double areaSqm;
  final int snowDepthCm;
  final int difficulty;
  final int estimatedMinutes;
  final int priceYen;
  final bool isSos;

  /// Whether a worker can park on site and whether tools are provided - see
  /// [SnowRequest.parkingAvailable]/[SnowRequest.toolsProvided]. Safe to
  /// publish: they describe the site, not the household.
  final bool parkingAvailable;
  final bool toolsProvided;

  final RequestStatus status;
  final DateTime createdAt;

  bool get isAvailable => status == RequestStatus.waiting;

  String get workTitle => '${workAreas.join('・')}の除雪';

  /// Straight-line distance from a worker's own position. Approximate by
  /// construction - it measures to the published cell center, not the house.
  double distanceKmFrom(double latitude, double longitude) {
    return distanceKmBetween(
      latitude,
      longitude,
      coarseLatitude,
      coarseLongitude,
    );
  }

  /// Projects a full request onto its public form. Used by demo builds,
  /// which have no Cloud Functions to do it server-side; Firebase builds
  /// read the projection Cloud Functions already wrote.
  factory RequestSummary.fromRequest(SnowRequest request) {
    final hash = encodeGeohash(
      request.latitude,
      request.longitude,
      precision: publicLocationPrecision,
    );
    final center = geohashCenter(hash);
    return RequestSummary(
      id: request.id,
      ownerId: request.ownerId,
      cell: hash.substring(0, boardCellPrecision),
      coarseLatitude: center.latitude,
      coarseLongitude: center.longitude,
      workAreas: request.workAreas,
      areaSqm: request.areaSqm,
      snowDepthCm: request.snowDepthCm,
      difficulty: request.difficulty,
      estimatedMinutes: request.estimatedMinutes,
      priceYen: request.priceYen,
      isSos: request.isSos,
      parkingAvailable: request.parkingAvailable,
      toolsProvided: request.toolsProvided,
      status: request.status,
      createdAt: request.createdAt,
    );
  }
}

/// Statuses that appear on the public board. Open jobs so workers can take
/// them, in-progress jobs so the community map can show current activity -
/// and nothing past that, since a finished or withdrawn job is not activity.
const boardVisibleStatuses = {
  RequestStatus.waiting,
  RequestStatus.matched,
  RequestStatus.moving,
  RequestStatus.arrived,
  RequestStatus.working,
  RequestStatus.reviewing,
};
