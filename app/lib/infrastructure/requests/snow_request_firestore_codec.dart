import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/requests/snow_request.dart';

class SnowRequestFirestoreCodec {
  const SnowRequestFirestoreCodec._();

  static const schemaVersion = 1;

  static Map<String, Object?> encode(SnowRequest request, {Object? updatedAt}) {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'ownerId': request.ownerId,
      'placeName': request.placeName,
      'approximateAddress': request.approximateAddress,
      'location': GeoPoint(request.latitude, request.longitude),
      'workAreas': request.workAreas,
      'areaSqm': request.areaSqm,
      'snowDepthCm': request.snowDepthCm,
      'difficulty': request.difficulty,
      'estimatedMinutes': request.estimatedMinutes,
      'priceYen': request.priceYen,
      'distanceKm': request.distanceKm,
      'isSos': request.isSos,
      'sosReason': request.sosReason,
      'beforeImageAsset': request.beforeImageAsset,
      'status': request.status.name,
      'createdAt': Timestamp.fromDate(request.createdAt),
      'workerId': request.workerId,
      'workerName': request.workerName,
      'acceptedAt': _encodeDate(request.acceptedAt),
      'movingAt': _encodeDate(request.movingAt),
      'arrivedAt': _encodeDate(request.arrivedAt),
      'safetyConfirmedAt': _encodeDate(request.safetyConfirmedAt),
      'startedAt': _encodeDate(request.startedAt),
      'afterImageAsset': request.afterImageAsset,
      'workMemo': request.workMemo,
      'submittedAt': _encodeDate(request.submittedAt),
      'completedAt': _encodeDate(request.completedAt),
      'paymentStatus': request.paymentStatus.name,
      'rating': request.rating,
      'ratingComment': request.ratingComment,
      'updatedAt': updatedAt ?? Timestamp.now(),
    };
  }

  static SnowRequest decode(String id, Map<String, dynamic> data) {
    return SnowRequest(
      id: id,
      ownerId: _requiredString(data, 'ownerId'),
      placeName: _requiredString(data, 'placeName'),
      approximateAddress: _requiredString(data, 'approximateAddress'),
      latitude: _requiredGeoPoint(data, 'location').latitude,
      longitude: _requiredGeoPoint(data, 'location').longitude,
      workAreas: (data['workAreas'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
      areaSqm: _requiredNumber(data, 'areaSqm').toDouble(),
      snowDepthCm: _requiredNumber(data, 'snowDepthCm').toInt(),
      difficulty: _requiredNumber(data, 'difficulty').toInt(),
      estimatedMinutes: _requiredNumber(data, 'estimatedMinutes').toInt(),
      priceYen: _requiredNumber(data, 'priceYen').toInt(),
      distanceKm: _requiredNumber(data, 'distanceKm').toDouble(),
      isSos: data['isSos'] as bool? ?? false,
      sosReason: data['sosReason'] as String?,
      beforeImageAsset: _requiredString(data, 'beforeImageAsset'),
      status: _requestStatus(data['status']),
      createdAt: _requiredDate(data, 'createdAt'),
      workerId: data['workerId'] as String?,
      workerName: data['workerName'] as String?,
      acceptedAt: _decodeDate(data['acceptedAt']),
      movingAt: _decodeDate(data['movingAt']),
      arrivedAt: _decodeDate(data['arrivedAt']),
      safetyConfirmedAt: _decodeDate(data['safetyConfirmedAt']),
      startedAt: _decodeDate(data['startedAt']),
      afterImageAsset: data['afterImageAsset'] as String?,
      workMemo: data['workMemo'] as String?,
      submittedAt: _decodeDate(data['submittedAt']),
      completedAt: _decodeDate(data['completedAt']),
      paymentStatus: _paymentStatus(data['paymentStatus']),
      rating: (data['rating'] as num?)?.toInt(),
      ratingComment: data['ratingComment'] as String?,
    );
  }

  static Object? _encodeDate(DateTime? value) =>
      value == null ? null : Timestamp.fromDate(value);

  static DateTime? _decodeDate(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime dateTime => dateTime,
    _ => null,
  };

  static DateTime _requiredDate(Map<String, dynamic> data, String key) {
    final value = _decodeDate(data[key]);
    if (value == null) throw FormatException('$key must be a timestamp');
    return value;
  }

  static String _requiredString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('$key must be a non-empty string');
    }
    return value;
  }

  static num _requiredNumber(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! num) throw FormatException('$key must be a number');
    return value;
  }

  static GeoPoint _requiredGeoPoint(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! GeoPoint) throw FormatException('$key must be a GeoPoint');
    return value;
  }

  static RequestStatus _requestStatus(Object? value) {
    return RequestStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => throw FormatException('Unknown request status: $value'),
    );
  }

  static DemoPaymentStatus _paymentStatus(Object? value) {
    return DemoPaymentStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => throw FormatException('Unknown payment status: $value'),
    );
  }
}
