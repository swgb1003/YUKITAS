import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yukitas/app/mode_shell.dart';
import 'package:yukitas/domain/requests/snow_request.dart';
import 'package:yukitas/infrastructure/requests/in_memory_request_repository.dart';

const _workerId = 'demo-worker-takumi';

void main() {
  testWidgets(
    "a job worked on for someone else's request doesn't take over the "
    'worker account\'s own 依頼履歴 tab',
    (tester) async {
      final othersRequest = SnowRequest(
        id: 'others-request',
        ownerId: 'someone-elses-account',
        placeName: '他人の家',
        approximateAddress: '新潟市西区',
        latitude: 37.9,
        longitude: 139.0,
        workAreas: const ['玄関'],
        areaSqm: 15,
        snowDepthCm: 20,
        difficulty: 2,
        estimatedMinutes: 30,
        priceYen: 2000,
        isSos: false,
        sosReason: null,
        beforeImageAsset: 'assets/images/before_driveway.png',
        status: RequestStatus.matched,
        workerId: _workerId,
        workerName: '佐藤 拓海さん',
        acceptedAt: DateTime(2026, 8, 13, 9),
        createdAt: DateTime(2026, 8, 13),
      );
      final repository = InMemoryRequestRepository(
        seedRequests: [othersRequest],
      );
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        MaterialApp(home: ModeShell(repository: repository)),
      );

      // Requester mode, own history tab: must show this account's (empty)
      // history, never the other owner's request they merely worked on.
      await tester.tap(find.byKey(const Key('requester-nav-2')));
      await tester.pumpAndSettle();
      expect(find.text('まだ依頼はありません'), findsOneWidget);
      expect(find.text('他人の家'), findsNothing);
      expect(find.text('ワーカーが見つかりました'), findsNothing);

      // Worker mode: the same job must still show as their active job.
      await tester.tap(find.byKey(const Key('mode-switch')));
      await tester.pumpAndSettle();
      expect(find.text('玄関の除雪'), findsWidgets);
    },
  );
}
