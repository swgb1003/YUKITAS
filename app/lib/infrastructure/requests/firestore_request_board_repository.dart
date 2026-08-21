import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/geo/geo_cell.dart';
import '../../domain/requests/request_board_repository.dart';
import '../../domain/requests/request_summary.dart';
import '../../domain/requests/snow_request.dart';

/// Subscribes to the `requestBoard` cells around the worker's position.
///
/// The board is the only view of other people's requests a client can read -
/// the full `requests` documents are restricted to each request's owner and
/// assigned worker by Firestore rules, so the address and photos never reach
/// a worker who has not taken the job (AC-08).
class FirestoreRequestBoardRepository extends ChangeNotifier
    implements RequestBoardRepository {
  FirestoreRequestBoardRepository({
    required double latitude,
    required double longitude,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance {
    setOrigin(latitude: latitude, longitude: longitude);
  }

  final FirebaseFirestore _firestore;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  List<String> _cells = const <String>[];
  List<RequestSummary> _summaries = const <RequestSummary>[];

  @override
  List<RequestSummary> get summaries =>
      List<RequestSummary>.unmodifiable(_summaries);

  @override
  void setOrigin({required double latitude, required double longitude}) {
    final cells = geohashNeighbours(
      encodeGeohash(latitude, longitude, precision: boardCellPrecision),
    );
    // Moving a few metres keeps you in the same cells; only a real change of
    // area is worth tearing down and rebuilding the listener.
    if (_cells.length == cells.length &&
        List.generate(cells.length, (i) => _cells[i] == cells[i]).every((e) => e)) {
      return;
    }
    _cells = cells;
    unawaited(_subscription?.cancel());
    _subscription = _firestore
        .collection('requestBoard')
        // 9 cells at most, well inside the 30-value `whereIn` limit.
        .where('cell', whereIn: cells)
        .limit(200)
        .snapshots()
        .listen(
          _onSnapshot,
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Request board sync failed: $error');
            debugPrintStack(stackTrace: stackTrace);
          },
        );
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final next = <RequestSummary>[];
    for (final document in snapshot.docs) {
      try {
        next.add(_decode(document.id, document.data()));
      } on FormatException catch (error) {
        debugPrint('Skipped invalid board entry ${document.id}: $error');
      }
    }
    next.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _summaries = next;
    notifyListeners();
  }

  RequestSummary _decode(String id, Map<String, dynamic> data) {
    final location = data['coarseLocation'];
    if (location is! GeoPoint) {
      throw const FormatException('coarseLocation must be a GeoPoint');
    }
    final status = RequestStatus.values.firstWhere(
      (value) => value.name == data['status'],
      orElse: () => throw FormatException('Unknown status: ${data['status']}'),
    );
    final createdAt = data['createdAt'];
    return RequestSummary(
      id: id,
      ownerId: data['ownerId'] as String? ?? '',
      cell: data['cell'] as String? ?? '',
      coarseLatitude: location.latitude,
      coarseLongitude: location.longitude,
      workAreas:
          (data['workAreas'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(growable: false),
      areaSqm: (data['areaSqm'] as num?)?.toDouble() ?? 0,
      snowDepthCm: (data['snowDepthCm'] as num?)?.toInt() ?? 0,
      difficulty: (data['difficulty'] as num?)?.toInt() ?? 1,
      estimatedMinutes: (data['estimatedMinutes'] as num?)?.toInt() ?? 0,
      priceYen: (data['priceYen'] as num?)?.toInt() ?? 0,
      isSos: data['isSos'] as bool? ?? false,
      status: status,
      createdAt:
          createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
