import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yukitas/app/mode_shell.dart';
import 'package:yukitas/domain/requests/snow_request.dart';
import 'package:yukitas/infrastructure/requests/in_memory_request_repository.dart';

const _userId = 'demo-worker-takumi';

void main() {
  testWidgets(
    'a finished (rated) request does not keep reappearing every time you '
    'toggle mode',
    (tester) async {
      final finishedRequest = SnowRequest(
        id: 'finished-1',
        ownerId: _userId,
        placeName: '新潟の実家',
        approximateAddress: '新潟市中央区',
        latitude: 37.9161,
        longitude: 139.0364,
        workAreas: const ['玄関'],
        areaSqm: 18,
        snowDepthCm: 20,
        difficulty: 2,
        estimatedMinutes: 30,
        priceYen: 2500,
        isSos: false,
        sosReason: null,
        beforeImageAsset: 'assets/images/before_driveway.png',
        status: RequestStatus.completed,
        workerId: _userId,
        workerName: '佐藤 拓海さん',
        afterImageAsset: 'assets/images/after_driveway.png',
        workMemo: '除雪しました。',
        completedAt: DateTime(2026, 8, 13, 10),
        createdAt: DateTime(2026, 8, 13, 8),
        paymentStatus: DemoPaymentStatus.paid,
        rating: 5,
        ratingComment: 'ありがとうございました',
      );
      final repository = InMemoryRequestRepository(
        seedRequests: [finishedRequest],
      );
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        MaterialApp(home: ModeShell(repository: repository)),
      );

      // Toggle mode several times, the way the user described repeatedly
      // tapping 依頼する/作業する - the finished job's celebration screens
      // must never come back once it has already been rated.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('mode-switch')));
        await tester.pumpAndSettle();
        expect(find.text('近くの除雪依頼'), findsOneWidget);
        expect(find.text('お疲れさまでした'), findsNothing);
        expect(find.byKey(const Key('find-next-request')), findsNothing);

        await tester.tap(find.byKey(const Key('mode-switch')));
        await tester.pumpAndSettle();
        expect(find.text('おはようございます'), findsOneWidget);
        expect(find.text('雪かき、完了です'), findsNothing);
        expect(find.text('評価してホームへ'), findsNothing);
      }
    },
  );
}
