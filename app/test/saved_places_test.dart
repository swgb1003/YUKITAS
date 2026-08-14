import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yukitas/app/mode_shell.dart';
import 'package:yukitas/domain/places/saved_place.dart';
import 'package:yukitas/infrastructure/places/in_memory_saved_place_repository.dart';
import 'package:yukitas/infrastructure/requests/in_memory_request_repository.dart';

const _secondPlace = SavedPlace(
  id: 'demo-place-tokyo',
  label: '東京の自宅',
  approximateAddress: '東京都渋谷区',
  latitude: 35.6595,
  longitude: 139.7005,
);

Future<void> _openProfile(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('requester-nav-3')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('profile lists saved places and links to the manager', (
    tester,
  ) async {
    final requestRepository = InMemoryRequestRepository(seedRequests: const []);
    addTearDown(requestRepository.dispose);
    final placeRepository = InMemorySavedPlaceRepository();
    addTearDown(placeRepository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ModeShell(
          repository: requestRepository,
          savedPlaceRepository: placeRepository,
        ),
      ),
    );

    await _openProfile(tester);
    expect(find.text('新潟の実家'), findsOneWidget);
    expect(find.text('大雪通知の対象'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('profile-manage-places')));
    await tester.tap(find.byKey(const Key('profile-manage-places')));
    await tester.pumpAndSettle();
    expect(find.text('登録した場所'), findsOneWidget);
    expect(find.byKey(const Key('saved-place-demo-place-niigata-home')), findsOneWidget);
  });

  testWidgets('adding a place through the editor updates the list', (
    tester,
  ) async {
    final requestRepository = InMemoryRequestRepository(seedRequests: const []);
    addTearDown(requestRepository.dispose);
    final placeRepository = InMemorySavedPlaceRepository(seedPlaces: const []);
    addTearDown(placeRepository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ModeShell(
          repository: requestRepository,
          savedPlaceRepository: placeRepository,
        ),
      ),
    );

    await _openProfile(tester);
    expect(find.text('まだ場所が登録されていません'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('profile-manage-places')));
    await tester.tap(find.byKey(const Key('profile-manage-places')));
    await tester.pumpAndSettle();
    expect(find.text('まだ場所が登録されていません'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('add-saved-place')));
    await tester.tap(find.byKey(const Key('add-saved-place')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('place-label-field')),
      '実家',
    );
    await tester.enterText(
      find.byKey(const Key('place-beneficiary-field')),
      'お父さん',
    );
    await tester.ensureVisible(find.byKey(const Key('save-place')));
    await tester.tap(find.byKey(const Key('save-place')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(placeRepository.places, hasLength(1));
    expect(placeRepository.places.single.label, '実家');
    expect(placeRepository.places.single.beneficiaryName, 'お父さん');
    expect(find.text('実家'), findsOneWidget);
  });

  testWidgets('deleting a place removes it from the list', (tester) async {
    final requestRepository = InMemoryRequestRepository(seedRequests: const []);
    addTearDown(requestRepository.dispose);
    final placeRepository = InMemorySavedPlaceRepository();
    addTearDown(placeRepository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ModeShell(
          repository: requestRepository,
          savedPlaceRepository: placeRepository,
        ),
      ),
    );

    await _openProfile(tester);
    await tester.ensureVisible(find.byKey(const Key('profile-manage-places')));
    await tester.tap(find.byKey(const Key('profile-manage-places')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('saved-place-demo-place-niigata-home')),
    );
    await tester.tap(
      find.byKey(const Key('saved-place-demo-place-niigata-home')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('delete-place')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(placeRepository.places, isEmpty);
    expect(find.text('まだ場所が登録されていません'), findsOneWidget);
  });

  testWidgets('picking a different saved place is used as the request place', (
    tester,
  ) async {
    final requestRepository = InMemoryRequestRepository(seedRequests: const []);
    addTearDown(requestRepository.dispose);
    final placeRepository = InMemorySavedPlaceRepository(
      seedPlaces: const [
        SavedPlace(
          id: 'demo-place-niigata-home',
          label: '新潟の実家',
          approximateAddress: '新潟市中央区',
          latitude: 37.9161,
          longitude: 139.0364,
          beneficiaryName: 'お母さま',
        ),
        _secondPlace,
      ],
    );
    addTearDown(placeRepository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ModeShell(
          repository: requestRepository,
          savedPlaceRepository: placeRepository,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('create-request')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('use-saved-place-demo-place-tokyo')));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('東京の自宅'), findsWidgets);

    await tester.tap(find.byKey(const Key('location-continue')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('analyze-request')));
    await tester.tap(find.byKey(const Key('analyze-request')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('analysis-continue')));
    await tester.tap(find.byKey(const Key('analysis-continue')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('publish-request')));
    await tester.tap(find.byKey(const Key('publish-request')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 500));

    expect(requestRepository.requests, hasLength(1));
    expect(requestRepository.requests.single.placeName, '東京の自宅');
    expect(requestRepository.requests.single.latitude, _secondPlace.latitude);
    expect(
      requestRepository.requests.single.longitude,
      _secondPlace.longitude,
    );
  });
}
