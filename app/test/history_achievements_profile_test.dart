import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yukitas/app/mode_shell.dart';
import 'package:yukitas/application/requests/worker_achievements.dart';
import 'package:yukitas/domain/requests/snow_request.dart';
import 'package:yukitas/infrastructure/requests/in_memory_request_repository.dart';

const _userId = 'demo-worker-takumi';

SnowRequest _completedRequest({
  required String id,
  required String ownerId,
  String? workerId,
  bool isSos = true,
  int priceYen = 2800,
  double areaSqm = 18,
  int? rating = 5,
}) {
  return SnowRequest(
    id: id,
    ownerId: ownerId,
    placeName: '新潟の実家',
    approximateAddress: '新潟市中央区',
    latitude: 37.9161,
    longitude: 139.0364,
    workAreas: const ['玄関', '駐車場'],
    areaSqm: areaSqm,
    snowDepthCm: 28,
    difficulty: 3,
    estimatedMinutes: 40,
    priceYen: priceYen,
    isSos: isSos,
    sosReason: isSos ? '高齢の家族宅' : null,
    beforeImageAsset: 'assets/images/before_driveway.png',
    status: RequestStatus.completed,
    workerId: workerId,
    workerName: workerId == null ? null : '佐藤 拓海さん',
    afterImageAsset: 'assets/images/after_driveway.png',
    workMemo: '玄関から門まで除雪しました。',
    completedAt: DateTime(2026, 8, 13, 10),
    createdAt: DateTime(2026, 8, 13, 8),
    paymentStatus: DemoPaymentStatus.paid,
    rating: rating,
  );
}

void main() {
  testWidgets('requester history lists finished requests with evidence', (
    tester,
  ) async {
    final repository = InMemoryRequestRepository(
      seedRequests: [
        _completedRequest(id: 'history-1', ownerId: _userId, workerId: 'w-1'),
      ],
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(home: ModeShell(repository: repository)),
    );

    await tester.tap(find.byKey(const Key('requester-nav-2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history-request-history-1')), findsOneWidget);
    expect(find.text('完了'), findsWidgets);
    expect(find.text('2,800円'), findsWidgets);

    // Opening an entry surfaces the Before / After completion evidence.
    await tester.tap(find.byKey(const Key('history-request-history-1')));
    await tester.pumpAndSettle();
    expect(find.text('BEFORE'), findsOneWidget);
    expect(find.text('AFTER'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('玄関から門まで除雪しました。'),
      find.byType(ListView).last,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    expect(find.text('玄関から門まで除雪しました。'), findsOneWidget);
  });

  testWidgets('requester history shows an empty state with no requests', (
    tester,
  ) async {
    final repository = InMemoryRequestRepository(seedRequests: const []);
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(home: ModeShell(repository: repository)),
    );

    await tester.tap(find.byKey(const Key('requester-nav-2')));
    await tester.pumpAndSettle();

    expect(find.text('まだ依頼はありません'), findsOneWidget);
    expect(find.byKey(const Key('history-create-request')), findsOneWidget);
  });

  testWidgets('worker achievements aggregate completed work into points', (
    tester,
  ) async {
    final repository = InMemoryRequestRepository(
      seedRequests: [
        _completedRequest(
          id: 'assigned-1',
          ownerId: 'other-owner',
          workerId: _userId,
        ),
      ],
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(home: ModeShell(repository: repository)),
    );

    await tester.tap(find.byKey(const Key('mode-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('worker-nav-2')));
    await tester.pumpAndSettle();

    // Demo baseline (32件 / SOS 4件 / 410m²) plus this one SOS job lands on
    // the figures used across the design mockups.
    expect(find.text('33'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('428'), findsOneWidget);
    expect(find.text('COMMUNITY POINTS'), findsOneWidget);
    expect(find.text('地域貢献 Lv.4'), findsOneWidget);
  });

  testWidgets('profile shows the account and adapts to the active mode', (
    tester,
  ) async {
    final repository = InMemoryRequestRepository(
      seedRequests: [
        _completedRequest(id: 'owned-1', ownerId: _userId, workerId: 'w-1'),
      ],
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(home: ModeShell(repository: repository)),
    );

    await tester.tap(find.byKey(const Key('requester-nav-3')));
    await tester.pumpAndSettle();
    expect(find.text('佐藤 拓海さん'), findsOneWidget);
    expect(find.text('依頼者'), findsOneWidget);
    expect(find.text('登録した場所'), findsOneWidget);

    // Switching role from the profile lands on the worker's own main screen,
    // the same as every other mode switch in the app.
    await tester.tap(find.byKey(const Key('profile-toggle-mode')));
    await tester.pumpAndSettle();
    expect(find.text('近くの除雪依頼'), findsOneWidget);

    await tester.tap(find.byKey(const Key('worker-nav-3')));
    await tester.pumpAndSettle();
    expect(find.text('ワーカー'), findsOneWidget);
    expect(find.text('対応条件'), findsOneWidget);
    expect(find.text('屋根雪下ろし・公道・重機'), findsOneWidget);
  });

  test('achievements stay at zero without the demo baseline', () {
    final achievements = WorkerAchievements.fromRequests(
      [_completedRequest(id: 'a', ownerId: 'o', workerId: _userId)],
      includeDemoBaseline: false,
    );

    expect(achievements.completedCount, 1);
    expect(achievements.sosCount, 1);
    expect(achievements.points, 120);
    expect(achievements.level, 1);
    expect(achievements.pointsToNextLevel, 880);
    expect(achievements.averageRating, 5);
  });
}
