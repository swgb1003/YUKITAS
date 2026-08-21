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
    distanceKm: 0.8,
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

  test('a request already matched to a worker cannot be cancelled this way', () async {
    final repository = InMemoryRequestRepository(
      seedRequests: [
        _waitingRequest().copyWith(
          status: RequestStatus.matched,
          workerId: 'worker-1',
        ),
      ],
    );
    addTearDown(repository.dispose);

    final succeeded = await repository.cancel(
      requestId: 'cancel-request',
      ownerId: 'demo-worker-takumi',
      reason: 'やっぱりやめたい',
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
