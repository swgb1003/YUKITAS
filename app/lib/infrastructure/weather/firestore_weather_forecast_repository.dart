import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/weather/snowfall_forecast.dart';
import '../../domain/weather/weather_forecast_repository.dart';

/// Reads the `weatherSnapshots/niigata-shi` document Cloud Functions keeps
/// updated (see functions/src/weather.ts) in real time. The contest demo
/// covers Niigata city only, so there is one fixed snapshot id rather than a
/// per-region lookup (matches FirestoreRegionStatsRepository's single
/// `regionStats/summary` doc).
class FirestoreWeatherForecastRepository extends ChangeNotifier
    implements WeatherForecastRepository {
  FirestoreWeatherForecastRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance {
    _subscription = _firestore
        .collection('weatherSnapshots')
        .doc('niigata-shi')
        .snapshots()
        .listen(_onSnapshot, onError: (Object error) {
          debugPrint('Weather snapshot sync failed: $error');
        });
  }

  final FirebaseFirestore _firestore;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  SnowfallForecast _forecast = SnowfallForecast.demo;

  @override
  SnowfallForecast get forecast => _forecast;

  void _onSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) return;
    final temperatureC = (data['temperatureC'] as num?)?.toInt();
    final expectedSnowfallCm = (data['expectedSnowfallCm'] as num?)?.toInt();
    if (temperatureC == null || expectedSnowfallCm == null) return;
    _forecast = SnowfallForecast(
      temperatureC: temperatureC,
      expectedSnowfallCm: expectedSnowfallCm,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
