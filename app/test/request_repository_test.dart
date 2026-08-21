import 'package:flutter_test/flutter_test.dart';
import 'package:yukitas/domain/requests/snow_request.dart';
import 'package:yukitas/infrastructure/requests/in_memory_request_repository.dart';

void main() {
  test('only the first worker can accept a waiting request', () async {
    final request = SnowRequest(
      id: 'request-1',
      ownerId: 'owner-1',
      placeName: '新潟の実家',
      approximateAddress: '新潟市中央区',
      latitude: 37.9161,
      longitude: 139.0364,
      workAreas: const ['玄関', '駐車場'],
      areaSqm: 18,
      snowDepthCm: 28,
      difficulty: 3,
      estimatedMinutes: 45,
      priceYen: 3200,
      isSos: true,
      sosReason: '高齢の家族宅',
      beforeImageAsset: 'assets/images/before_driveway.png',
      status: RequestStatus.waiting,
      createdAt: DateTime(2026, 8, 13),
    );
    final repository = InMemoryRequestRepository(seedRequests: [request]);
    addTearDown(repository.dispose);

    final firstAccepted = await repository.accept(
      requestId: request.id,
      workerId: 'worker-1',
      workerName: '佐藤 拓海さん',
    );
    final secondAccepted = await repository.accept(
      requestId: request.id,
      workerId: 'worker-2',
      workerName: '別のワーカー',
    );

    expect(firstAccepted, isTrue);
    expect(secondAccepted, isFalse);
    expect(repository.findById(request.id)?.workerId, 'worker-1');
    expect(repository.findById(request.id)?.status, RequestStatus.matched);
  });

  test('worker progress follows the safe ordered state machine', () async {
    final request = SnowRequest(
      id: 'request-progress',
      ownerId: 'owner-1',
      placeName: '新潟の実家',
      approximateAddress: '新潟市中央区',
      latitude: 37.9161,
      longitude: 139.0364,
      workAreas: const ['玄関', '駐車場'],
      areaSqm: 18,
      snowDepthCm: 28,
      difficulty: 3,
      estimatedMinutes: 45,
      priceYen: 3200,
      isSos: true,
      sosReason: '高齢の家族宅',
      beforeImageAsset: 'assets/images/before_driveway.png',
      status: RequestStatus.matched,
      workerId: 'worker-1',
      workerName: '佐藤 拓海さん',
      acceptedAt: DateTime(2026, 8, 13, 9),
      createdAt: DateTime(2026, 8, 13),
    );
    final repository = InMemoryRequestRepository(seedRequests: [request]);
    addTearDown(repository.dispose);

    expect(
      await repository.transitionWorkerStatus(
        requestId: request.id,
        workerId: 'another-worker',
        nextStatus: RequestStatus.moving,
      ),
      isFalse,
    );
    expect(
      await repository.transitionWorkerStatus(
        requestId: request.id,
        workerId: 'worker-1',
        nextStatus: RequestStatus.arrived,
      ),
      isFalse,
    );
    expect(
      await repository.transitionWorkerStatus(
        requestId: request.id,
        workerId: 'worker-1',
        nextStatus: RequestStatus.moving,
      ),
      isTrue,
    );
    expect(repository.findById(request.id)?.movingAt, isNotNull);

    expect(
      await repository.transitionWorkerStatus(
        requestId: request.id,
        workerId: 'worker-1',
        nextStatus: RequestStatus.arrived,
      ),
      isTrue,
    );
    expect(repository.findById(request.id)?.arrivedAt, isNotNull);

    expect(
      await repository.transitionWorkerStatus(
        requestId: request.id,
        workerId: 'worker-1',
        nextStatus: RequestStatus.working,
      ),
      isFalse,
    );
    expect(
      await repository.transitionWorkerStatus(
        requestId: request.id,
        workerId: 'worker-1',
        nextStatus: RequestStatus.working,
        safetyChecksConfirmed: true,
      ),
      isTrue,
    );
    expect(repository.findById(request.id)?.status, RequestStatus.working);
    expect(repository.findById(request.id)?.startedAt, isNotNull);

    expect(
      await repository.transitionWorkerStatus(
        requestId: request.id,
        workerId: 'worker-1',
        nextStatus: RequestStatus.reviewing,
        afterImageAsset: 'assets/images/after_driveway.png',
      ),
      isFalse,
    );
    expect(
      await repository.transitionWorkerStatus(
        requestId: request.id,
        workerId: 'worker-1',
        nextStatus: RequestStatus.reviewing,
        afterImageAsset: 'assets/images/after_driveway.png',
        workMemo: '玄関から門まで除雪しました。',
      ),
      isTrue,
    );
    expect(repository.findById(request.id)?.submittedAt, isNotNull);

    expect(
      await repository.approveCompletion(
        requestId: request.id,
        ownerId: 'another-owner',
      ),
      isFalse,
    );
    expect(
      await repository.approveCompletion(
        requestId: request.id,
        ownerId: 'owner-1',
      ),
      isTrue,
    );
    expect(repository.findById(request.id)?.status, RequestStatus.completed);
    expect(
      repository.findById(request.id)?.paymentStatus,
      DemoPaymentStatus.paid,
    );

    expect(
      await repository.submitRating(
        requestId: request.id,
        ownerId: 'owner-1',
        rating: 5,
        comment: 'ありがとうございました',
      ),
      isTrue,
    );
    expect(repository.findById(request.id)?.rating, 5);
  });
}
