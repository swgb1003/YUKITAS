import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yukitas/domain/requests/snow_request.dart';
import 'package:yukitas/infrastructure/requests/snow_request_firestore_codec.dart';

void main() {
  test('Firestore codec preserves a request through a round trip', () {
    final createdAt = DateTime.utc(2026, 1, 15, 1, 30);
    final startedAt = DateTime.utc(2026, 1, 15, 2, 15);
    final disputedAt = DateTime.utc(2026, 1, 15, 2, 40);
    final request = SnowRequest(
      id: 'request-1',
      ownerId: 'owner-1',
      placeName: '新潟の実家',
      approximateAddress: '新潟市中央区',
      latitude: 37.9161,
      longitude: 139.0364,
      workAreas: const ['玄関', '駐車場'],
      areaSqm: 18.5,
      snowDepthCm: 28,
      difficulty: 3,
      estimatedMinutes: 45,
      priceYen: 3200,
      isSos: true,
      sosReason: '高齢の家族宅',
      beforeImageAsset: 'assets/images/before_driveway.png',
      status: RequestStatus.working,
      createdAt: createdAt,
      workerId: 'worker-1',
      workerName: '佐藤 拓海さん',
      safetyConfirmedAt: startedAt,
      startedAt: startedAt,
      disputeReason: '玄関前に不明な障害物があり安全確認できません',
      disputedAt: disputedAt,
      disputedBy: 'worker-1',
    );

    final encoded = SnowRequestFirestoreCodec.encode(
      request,
      updatedAt: Timestamp.fromDate(startedAt),
    );
    final decoded = SnowRequestFirestoreCodec.decode(request.id, encoded);

    expect(decoded.id, request.id);
    expect(decoded.ownerId, request.ownerId);
    expect(decoded.workAreas, request.workAreas);
    expect(decoded.latitude, request.latitude);
    expect(decoded.longitude, request.longitude);
    expect(decoded.areaSqm, request.areaSqm);
    expect(decoded.status, RequestStatus.working);
    expect(
      decoded.safetyConfirmedAt?.millisecondsSinceEpoch,
      startedAt.millisecondsSinceEpoch,
    );
    expect(
      decoded.startedAt?.millisecondsSinceEpoch,
      startedAt.millisecondsSinceEpoch,
    );
    expect(decoded.paymentStatus, DemoPaymentStatus.authorized);
    expect(decoded.disputeReason, request.disputeReason);
    expect(
      decoded.disputedAt?.millisecondsSinceEpoch,
      disputedAt.millisecondsSinceEpoch,
    );
    expect(decoded.disputedBy, request.disputedBy);
  });
}
