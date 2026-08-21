import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yukitas/app/mode_shell.dart';
import 'package:yukitas/domain/requests/snow_request.dart';
import 'package:yukitas/infrastructure/requests/in_memory_request_repository.dart';

SnowRequest _requestAt(RequestStatus status) {
  return SnowRequest(
    id: 'dispute-request',
    ownerId: 'owner-1',
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
    status: status,
    workerId: 'worker-1',
    workerName: '佐藤 拓海さん',
    acceptedAt: DateTime(2026, 8, 13, 9),
    createdAt: DateTime(2026, 8, 13),
  );
}

void main() {
  test('either party can report a problem while the job is active', () async {
    final repository = InMemoryRequestRepository(
      seedRequests: [_requestAt(RequestStatus.arrived)],
    );
    addTearDown(repository.dispose);

    final succeeded = await repository.reportProblem(
      requestId: 'dispute-request',
      reporterId: 'worker-1',
      reason: '玄関前に不明な障害物があり安全確認できません',
    );

    expect(succeeded, isTrue);
    final updated = repository.findById('dispute-request');
    expect(updated?.status, RequestStatus.disputed);
    expect(updated?.disputeReason, '玄関前に不明な障害物があり安全確認できません');
    expect(updated?.disputedBy, 'worker-1');
    expect(updated?.disputedAt, isNotNull);
  });

  test('a bystander cannot report a problem on someone else\'s job', () async {
    final repository = InMemoryRequestRepository(
      seedRequests: [_requestAt(RequestStatus.working)],
    );
    addTearDown(repository.dispose);

    final succeeded = await repository.reportProblem(
      requestId: 'dispute-request',
      reporterId: 'someone-else',
      reason: '関係ない理由',
    );

    expect(succeeded, isFalse);
    expect(repository.findById('dispute-request')?.status, RequestStatus.working);
  });

  test('a blank reason is rejected', () async {
    final repository = InMemoryRequestRepository(
      seedRequests: [_requestAt(RequestStatus.working)],
    );
    addTearDown(repository.dispose);

    final succeeded = await repository.reportProblem(
      requestId: 'dispute-request',
      reporterId: 'owner-1',
      reason: '   ',
    );

    expect(succeeded, isFalse);
    expect(repository.findById('dispute-request')?.status, RequestStatus.working);
  });

  test('a problem cannot be reported once the job is already completed', () async {
    final repository = InMemoryRequestRepository(
      seedRequests: [_requestAt(RequestStatus.completed)],
    );
    addTearDown(repository.dispose);

    final succeeded = await repository.reportProblem(
      requestId: 'dispute-request',
      reporterId: 'owner-1',
      reason: '今さら見つけた問題',
    );

    expect(succeeded, isFalse);
  });

  testWidgets(
    'worker reporting a problem during the safety check pauses the job for '
    'both roles',
    (tester) async {
      final request = SnowRequest(
        id: 'active-request',
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
        status: RequestStatus.arrived,
        workerId: 'demo-worker-takumi',
        workerName: '佐藤 拓海さん',
        acceptedAt: DateTime(2026, 8, 13, 9),
        createdAt: DateTime(2026, 8, 13),
      );
      final repository = InMemoryRequestRepository(seedRequests: [request]);
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        MaterialApp(home: ModeShell(repository: repository)),
      );
      await tester.tap(find.byKey(const Key('mode-switch')));
      await tester.pumpAndSettle();
      expect(find.text('作業前の安全確認'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('report-problem')));
      await tester.tap(find.byKey(const Key('report-problem')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('reason-dialog-field')),
        '玄関前に不明な障害物があり安全確認できません',
      );
      await tester.tap(find.byKey(const Key('reason-dialog-submit')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(repository.findById(request.id)?.status, RequestStatus.disputed);
      expect(find.text('問題が報告されています'), findsOneWidget);
      expect(find.text('玄関前に不明な障害物があり安全確認できません'), findsOneWidget);

      await tester.tap(find.byKey(const Key('mode-switch')).last);
      await tester.pumpAndSettle();
      expect(find.text('問題が報告されています'), findsOneWidget);

      // Regression: dismissing a disputed job from the worker side ("次の
      // 依頼を探す") must not let it reappear the next time the worker
      // switches back into worker mode - it must be added to
      // _finishedRequestIds the same way a rated completion is, not just
      // have its id cleared locally.
      await tester.tap(find.byKey(const Key('mode-switch')).last);
      await tester.pumpAndSettle();
      expect(find.text('問題が報告されています'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('find-next-request')));
      await tester.tap(find.byKey(const Key('find-next-request')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mode-switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mode-switch')).last);
      await tester.pumpAndSettle();
      expect(find.text('問題が報告されています'), findsNothing);
    },
  );
}
