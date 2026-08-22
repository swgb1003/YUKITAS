import 'package:flutter_test/flutter_test.dart';
import 'package:yukitas/core/geo/geo_cell.dart';
import 'package:yukitas/domain/requests/request_summary.dart';
import 'package:yukitas/domain/requests/snow_request.dart';
import 'package:yukitas/infrastructure/requests/in_memory_request_board_repository.dart';
import 'package:yukitas/infrastructure/requests/in_memory_request_repository.dart';

SnowRequest _request({
  required String id,
  required RequestStatus status,
  double latitude = 37.9161,
  double longitude = 139.0364,
  bool parkingAvailable = true,
  bool toolsProvided = true,
}) {
  return SnowRequest(
    id: id,
    ownerId: 'owner-1',
    placeName: '新潟の実家',
    approximateAddress: '新潟市中央区米山1-2-3',
    latitude: latitude,
    longitude: longitude,
    workAreas: const ['玄関'],
    areaSqm: 18,
    snowDepthCm: 28,
    difficulty: 3,
    estimatedMinutes: 45,
    priceYen: 3200,
    isSos: true,
    sosReason: '高齢の家族が一人で暮らしています',
    parkingAvailable: parkingAvailable,
    toolsProvided: toolsProvided,
    beforeImageAsset: 'requestMedia/$id/before/owner-1/photo.jpg',
    status: status,
    createdAt: DateTime(2026, 8, 13),
  );
}

void main() {
  group('the public projection withholds what identifies a household', () {
    test('publishes a blurred cell center, never the real coordinate', () {
      final request = _request(id: 'r1', status: RequestStatus.waiting);
      final summary = RequestSummary.fromRequest(request);

      expect(summary.coarseLatitude, isNot(request.latitude));
      expect(summary.coarseLongitude, isNot(request.longitude));

      // Close enough to be useful, far enough to be useless for navigation.
      final offset = distanceKmBetween(
        request.latitude,
        request.longitude,
        summary.coarseLatitude,
        summary.coarseLongitude,
      );
      expect(offset, lessThan(1.0));
      expect(offset, greaterThan(0.0));
    });

    test('carries no address, photo or SOS reason', () {
      // A compile-time guarantee as much as a runtime one: RequestSummary
      // simply has no field for any of these, so nothing downstream can
      // render them for a worker who has not accepted the job (AC-08).
      final summary = RequestSummary.fromRequest(
        _request(id: 'r1', status: RequestStatus.waiting),
      );
      final published = <String, Object?>{
        'ownerId': summary.ownerId,
        'cell': summary.cell,
        'coarseLatitude': summary.coarseLatitude,
        'coarseLongitude': summary.coarseLongitude,
        'workAreas': summary.workAreas,
        'areaSqm': summary.areaSqm,
        'snowDepthCm': summary.snowDepthCm,
        'difficulty': summary.difficulty,
        'estimatedMinutes': summary.estimatedMinutes,
        'priceYen': summary.priceYen,
        'isSos': summary.isSos,
        'status': summary.status,
        'createdAt': summary.createdAt,
      };

      final leaked = published.values
          .whereType<String>()
          .where(
            (value) =>
                value.contains('米山') ||
                value.contains('requestMedia/') ||
                value.contains('一人で暮らし'),
          );
      expect(leaked, isEmpty);
    });

    test('keeps the SOS flag so priority still works without the reason', () {
      final summary = RequestSummary.fromRequest(
        _request(id: 'r1', status: RequestStatus.waiting),
      );
      expect(summary.isSos, isTrue);
    });

    test('publishes parking and tool availability - they describe the site, '
        'not who lives there', () {
      final summary = RequestSummary.fromRequest(
        _request(
          id: 'r1',
          status: RequestStatus.waiting,
          parkingAvailable: true,
          toolsProvided: false,
        ),
      );
      expect(summary.parkingAvailable, isTrue);
      expect(summary.toolsProvided, isFalse);
    });
  });

  group('board membership', () {
    test('carries open and in-progress work, and drops the rest', () {
      final repository = InMemoryRequestRepository(
        seedRequests: [
          _request(id: 'open', status: RequestStatus.waiting),
          _request(id: 'live', status: RequestStatus.working),
          _request(id: 'done', status: RequestStatus.completed),
          _request(id: 'gone', status: RequestStatus.cancelled),
          _request(id: 'stale', status: RequestStatus.expired),
          _request(id: 'held', status: RequestStatus.disputed),
        ],
      );
      addTearDown(repository.dispose);
      final board = InMemoryRequestBoardRepository(requests: repository);
      addTearDown(board.dispose);

      expect(
        board.summaries.map((s) => s.id),
        unorderedEquals(<String>['open', 'live']),
      );
    });
  });

  group('geohash', () {
    test('round-trips a coordinate back to within its own cell', () {
      const latitude = 37.9161;
      const longitude = 139.0364;
      final hash = encodeGeohash(latitude, longitude);
      final bounds = decodeGeohashBounds(hash);

      expect(latitude, inInclusiveRange(bounds.latMin, bounds.latMax));
      expect(longitude, inInclusiveRange(bounds.lngMin, bounds.lngMax));
    });

    test('nearby points share a query cell; distant ones do not', () {
      String cellFor(double lat, double lng) =>
          encodeGeohash(lat, lng, precision: boardCellPrecision);

      // Two points a few hundred metres apart in Niigata.
      expect(cellFor(37.9161, 139.0364), cellFor(37.9155, 139.0370));
      // Niigata vs Sapporo - different region entirely.
      expect(
        cellFor(37.9161, 139.0364),
        isNot(cellFor(43.0618, 141.3545)),
      );
    });

    test('neighbours cover the surrounding cells including its own', () {
      final hash = encodeGeohash(
        37.9161,
        139.0364,
        precision: boardCellPrecision,
      );
      final neighbours = geohashNeighbours(hash);

      expect(neighbours, contains(hash));
      expect(neighbours.length, lessThanOrEqualTo(9));
      expect(neighbours.toSet().length, neighbours.length);
    });

    test('measures a real distance between two points', () {
      // Niigata station to Sapporo is roughly 570km as the crow flies.
      final km = distanceKmBetween(37.9161, 139.0364, 43.0618, 141.3545);
      expect(km, closeTo(590, 60));
    });
  });
}
