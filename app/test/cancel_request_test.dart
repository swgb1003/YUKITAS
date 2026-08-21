import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yukitas/app/mode_shell.dart';
import 'package:yukitas/domain/requests/snow_request.dart';
import 'package:yukitas/infrastructure/requests/in_memory_request_repository.dart';

SnowRequest _waitingRequest() {
  return SnowRequest(
    id: 'cancel-request',
    ownerId: 'demo-worker-takumi',
    placeName: '新潟の実家',
    approximateAddress: '新潟市中央区',
    latitude: 37.9161,
    longitude: 139.0364,
    workAreas: const ['玄関'],
    areaSqm: 18,
    snowDepthCm: 28,
    difficulty: 3,
    estimatedMinutes: 45,
    priceYen: 3200,
    isSos: false,
    sosReason: null,
    beforeImageAsset: 'assets/images/before_driveway.png',
    status: RequestStatus.waiting,
    createdAt: DateTime(2026, 8, 13),
  );
}

void main() {
  test('the owner can cancel a still-unmatched request', () async {
    final repository = InMemoryRequestRepository(
      seedRequests: [_waitingRequest()],
    );
    addTearDown(repository.dispose);

    final succeeded = await repository.cancel(
      requestId: 'cancel-request',
      ownerId: 'demo-worker-takumi',
      reason: '積雪が想定より少なかったため',
    );

    expect(succeeded, isTrue);
    final updated = repository.findById('cancel-request');
    expect(updated?.status, RequestStatus.cancelled);
    expect(updated?.cancelReason, '積雪が想定より少なかったため');
    expect(updated?.cancelledAt, isNotNull);
  });

  test('a bystander cannot cancel someone else\'s request', () async {
    final repository = InMemoryRequestRepository(
      seedRequests: [_waitingRequest()],
    );
    addTearDown(repository.dispose);

    final succeeded = await repository.cancel(
      requestId: 'cancel-request',
      ownerId: 'someone-else',
      reason: '関係ない理由',
    );

    expect(succeeded, isFalse);
    expect(repository.findById('cancel-request')?.status, RequestStatus.waiting);
  });

  test('a blank reason is rejected', () async {
    final repository = InMemoryRequestRepository(
      seedRequests: [_waitingRequest()],
    );
    addTearDown(repository.dispose);

    final succeeded = await repository.cancel(
      requestId: 'cancel-request',
      ownerId: 'demo-worker-takumi',
      reason: '   ',
    );

    expect(succeeded, isFalse);
    expect(repository.findById('cancel-request')?.status, RequestStatus.waiting);
  });

  test('the owner can still cancel after a worker has accepted but not '
      'started', () async {
    for (final status in [
      RequestStatus.matched,
      RequestStatus.moving,
      RequestStatus.arrived,
    ]) {
      final repository = InMemoryRequestRepository(
        seedRequests: [
          _waitingRequest().copyWith(status: status, workerId: 'worker-1'),
        ],
      );
      addTearDown(repository.dispose);

      final succeeded = await repository.cancel(
        requestId: 'cancel-request',
        ownerId: 'demo-worker-takumi',
        reason: 'ワーカーが到着しないため',
      );

      expect(succeeded, isTrue, reason: 'should be cancellable from $status');
      expect(
        repository.findById('cancel-request')?.status,
        RequestStatus.cancelled,
      );
    }
  });

  test('cancelling stops once the worker has actually started clearing snow', () async {
    // From here on there is labour to account for, so the way out is a
    // dispute with a resolution rather than a unilateral cancel.
    for (final status in [RequestStatus.working, RequestStatus.reviewing]) {
      final repository = InMemoryRequestRepository(
        seedRequests: [
          _waitingRequest().copyWith(status: status, workerId: 'worker-1'),
        ],
      );
      addTearDown(repository.dispose);

      final succeeded = await repository.cancel(
        requestId: 'cancel-request',
        ownerId: 'demo-worker-takumi',
        reason: 'やっぱりやめたい',
      );

      expect(succeeded, isFalse, reason: 'should be blocked at $status');
    }
  });

  test('a worker who cannot make it hands the job back to the pool', () async {
    final repository = InMemoryRequestRepository(
      seedRequests: [
        _waitingRequest().copyWith(
          status: RequestStatus.moving,
          workerId: 'worker-1',
          workerName: '佐藤 拓海さん',
        ),
      ],
    );
    addTearDown(repository.dispose);

    final succeeded = await repository.releaseAssignment(
      requestId: 'cancel-request',
      workerId: 'worker-1',
      reason: '車が動かなくなったため',
    );

    expect(succeeded, isTrue);
    final updated = repository.findById('cancel-request');
    expect(updated?.status, RequestStatus.waiting);
    expect(updated?.workerId, isNull);
    expect(updated?.workerName, isNull);
    expect(updated?.acceptedAt, isNull);
  });

  test('a worker cannot hand back a job once it is under way', () async {
    final repository = InMemoryRequestRepository(
      seedRequests: [
        _waitingRequest().copyWith(
          status: RequestStatus.working,
          workerId: 'worker-1',
        ),
      ],
    );
    addTearDown(repository.dispose);

    final succeeded = await repository.releaseAssignment(
      requestId: 'cancel-request',
      workerId: 'worker-1',
      reason: '面倒になった',
    );

    expect(succeeded, isFalse);
  });

  testWidgets('cancelling from the matching screen returns to the home tab', (
    tester,
  ) async {
    final repository = InMemoryRequestRepository(
      seedRequests: [_waitingRequest()],
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(home: ModeShell(repository: repository)),
    );
    // _SearchingDots animates continuously while a request is waiting, so
    // pumpAndSettle() would hang here - pump explicit frames instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('近くのワーカーを探しています'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('cancel-request')));
    await tester.tap(find.byKey(const Key('cancel-request')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(
      find.byKey(const Key('reason-dialog-field')),
      '積雪が想定より少なかったため',
    );
    await tester.tap(find.byKey(const Key('reason-dialog-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(
      repository.findById('cancel-request')?.status,
      RequestStatus.cancelled,
    );
    expect(find.text('近くのワーカーを探しています'), findsNothing);
  });
}
