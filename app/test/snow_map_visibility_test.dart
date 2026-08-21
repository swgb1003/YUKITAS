import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:yukitas/app/mode_shell.dart';
import 'package:yukitas/domain/requests/snow_request.dart';
import 'package:yukitas/infrastructure/requests/in_memory_request_repository.dart';

const _userId = 'demo-worker-takumi';

SnowRequest _request({
  required String id,
  required RequestStatus status,
}) {
  return SnowRequest(
    id: id,
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
    status: status,
    workerId: status == RequestStatus.waiting ? null : 'w-1',
    workerName: status == RequestStatus.waiting ? null : '佐藤 拓海さん',
    afterImageAsset:
        status == RequestStatus.completed
            ? 'assets/images/after_driveway.png'
            : null,
    workMemo: status == RequestStatus.completed ? '除雪しました。' : null,
    completedAt:
        status == RequestStatus.completed ? DateTime(2026, 8, 13, 10) : null,
    createdAt: DateTime(2026, 8, 13, 8),
  );
}

void main() {
  testWidgets('completed requests drop off the aggregate snow map', (
    tester,
  ) async {
    final repository = InMemoryRequestRepository(
      seedRequests: [
        _request(id: 'waiting-1', status: RequestStatus.waiting),
        _request(id: 'completed-1', status: RequestStatus.completed),
      ],
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ModeShell(repository: repository)),
    );
    await tester.tap(find.byKey(const Key('requester-nav-1')));
    await tester.pumpAndSettle();

    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    final markerIds = map.markers.map((m) => m.markerId.value).toSet();
    expect(markerIds, contains('waiting-1'));
    expect(markerIds, isNot(contains('completed-1')));
  });
}
