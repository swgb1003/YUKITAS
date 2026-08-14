import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/stats/region_stats.dart';
import '../../domain/stats/region_stats_repository.dart';

/// Reads the `regionStats/summary` document Cloud Functions keeps updated
/// (see functions/src/regionStats.ts) in real time.
class FirestoreRegionStatsRepository extends ChangeNotifier
    implements RegionStatsRepository {
  FirestoreRegionStatsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance {
    _subscription = _firestore
        .collection('regionStats')
        .doc('summary')
        .snapshots()
        .listen(_onSnapshot, onError: (Object error) {
          debugPrint('Region stats sync failed: $error');
        });
  }

  final FirebaseFirestore _firestore;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  RegionStats _stats = RegionStats.demo;

  @override
  RegionStats get stats => _stats;

  void _onSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) return;
    _stats = RegionStats(
      completedToday: (data['completedToday'] as num?)?.toInt() ?? 0,
      sosSupportedToday: (data['sosSupportedToday'] as num?)?.toInt() ?? 0,
      activeNow: (data['activeNow'] as num?)?.toInt() ?? 0,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
