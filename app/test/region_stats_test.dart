import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yukitas/app/mode_shell.dart';
import 'package:yukitas/domain/requests/snow_request.dart';
import 'package:yukitas/domain/stats/region_stats.dart';
import 'package:yukitas/domain/stats/region_stats_repository.dart';
import 'package:yukitas/infrastructure/requests/in_memory_request_repository.dart';

const _userId = 'demo-worker-takumi';

class _FakeRegionStatsRepository extends ChangeNotifier
    implements RegionStatsRepository {
  _FakeRegionStatsRepository(this._stats);

  final RegionStats _stats;

  @override
  RegionStats get stats => _stats;
}

SnowRequest _completedRequest() {
  return SnowRequest(
    id: 'completed-1',
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
    distanceKm: 0.5,
    isSos: false,
    sosReason: null,
    beforeImageAsset: 'assets/images/before_driveway.png',
    status: RequestStatus.completed,
    workerId: 'w-1',
    workerName: '佐藤 拓海さん',
    afterImageAsset: 'assets/images/after_driveway.png',
    workMemo: '除雪しました。',
    completedAt: DateTime(2026, 8, 13, 10),
    createdAt: DateTime(2026, 8, 13, 8),
    paymentStatus: DemoPaymentStatus.paid,
  );
}

void main() {
  testWidgets('home screen shows real region stats instead of the '
      'placeholder numbers', (tester) async {
    final requestRepository = InMemoryRequestRepository(seedRequests: const []);
    addTearDown(requestRepository.dispose);
    final statsRepository = _FakeRegionStatsRepository(
      const RegionStats(completedToday: 12, sosSupportedToday: 3, activeNow: 7),
    );
    addTearDown(statsRepository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ModeShell(
          repository: requestRepository,
          regionStatsRepository: statsRepository,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('12'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('347'), findsNothing);
  });

  testWidgets('completion screen shows the real completedToday count', (
    tester,
  ) async {
    final requestRepository = InMemoryRequestRepository(
      seedRequests: [_completedRequest()],
    );
    addTearDown(requestRepository.dispose);
    final statsRepository = _FakeRegionStatsRepository(
      const RegionStats(completedToday: 58, sosSupportedToday: 4, activeNow: 9),
    );
    addTearDown(statsRepository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ModeShell(
          repository: requestRepository,
          regionStatsRepository: statsRepository,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('本日の完了 58件'), findsOneWidget);
  });
}
