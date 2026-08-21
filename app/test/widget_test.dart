import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yukitas/app/mode_shell.dart';
import 'package:yukitas/app/yukitas_app.dart';
import 'package:yukitas/domain/requests/snow_request.dart';
import 'package:yukitas/infrastructure/requests/in_memory_request_repository.dart';

void main() {
  Future<void> openHome(WidgetTester tester) async {
    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('google-login')));
    await tester.tap(find.byKey(const Key('google-login')));
    await tester.pumpAndSettle();
  }

  testWidgets('uses Japanese locale and bundled Japanese font', (tester) async {
    await tester.pumpWidget(const YukitasApp());

    final context = tester.element(find.text('雪が積もったを、\n助かったに。'));
    expect(Localizations.localeOf(context), const Locale('ja', 'JP'));
    expect(Theme.of(context).textTheme.bodyMedium?.fontFamily, 'NotoSansJP');
    expect(
      Theme.of(context).textTheme.headlineMedium?.fontFamily,
      'NotoSansJP',
    );
  });

  testWidgets('starts from the branded splash screen', (tester) async {
    await tester.pumpWidget(const YukitasApp());

    expect(find.text('YUKITAS'), findsOneWidget);
    expect(find.text('雪が積もったを、\n助かったに。'), findsOneWidget);
    expect(find.text('はじめる'), findsOneWidget);
  });

  testWidgets('opens the login screen and signs in with the demo provider', (
    tester,
  ) async {
    await tester.pumpWidget(const YukitasApp());
    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();

    expect(find.text('地域の雪を、\nみんなの力で。'), findsOneWidget);
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(find.byKey(const Key('login-password')), findsOneWidget);
    expect(find.byKey(const Key('google-login')), findsOneWidget);
    expect(find.text('Firebase接続前のデモ認証です'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('google-login')));
    await tester.tap(find.byKey(const Key('google-login')));
    await tester.pumpAndSettle();
    expect(find.text('おはようございます'), findsOneWidget);
  });

  testWidgets('switches between sign in and account registration', (
    tester,
  ) async {
    await tester.pumpWidget(YukitasApp());
    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-registration')));
    await tester.pump();
    expect(find.text('アカウント作成'), findsOneWidget);
    expect(find.text('アカウントを作成'), findsOneWidget);
    expect(find.text('ログインへ戻る'), findsOneWidget);
  });

  testWidgets('switches requester and worker modes', (tester) async {
    await tester.pumpWidget(const YukitasApp());
    await openHome(tester);

    expect(find.text('おはようございます'), findsOneWidget);
    expect(find.text('雪かきを依頼する'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mode-switch')));
    await tester.pumpAndSettle();

    expect(find.text('近くの除雪依頼'), findsOneWidget);
    expect(find.text('駐車場・玄関の除雪'), findsOneWidget);
  });

  testWidgets('opens the worker request list from navigation', (tester) async {
    await tester.pumpWidget(const YukitasApp());
    await openHome(tester);
    await tester.tap(find.byKey(const Key('mode-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('worker-nav-1')));
    await tester.pumpAndSettle();

    expect(find.text('依頼一覧'), findsWidgets);
    expect(find.text('3件の依頼があります'), findsOneWidget);
    expect(find.text('2,800円'), findsOneWidget);
  });

  testWidgets('publishes, accepts, and reflects one shared request', (
    tester,
  ) async {
    final repository = InMemoryRequestRepository(seedRequests: []);
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(home: ModeShell(repository: repository)),
    );

    await tester.tap(find.byKey(const Key('create-request')));
    await tester.pumpAndSettle();
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

    expect(repository.requests, hasLength(1));
    expect(repository.requests.single.status, RequestStatus.waiting);
    expect(find.text('ワーカーを検索中'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mode-switch')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('worker-nav-1')));
    await tester.pumpAndSettle();
    expect(find.text('1件の依頼があります'), findsOneWidget);

    await tester.tap(
      find.byKey(Key('worker-request-${repository.requests.single.id}')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('accept-request')));
    await tester.tap(find.byKey(const Key('accept-request')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-accept-request')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(repository.requests.single.status, RequestStatus.matched);
    expect(repository.requests.single.workerName, '佐藤 拓海さん');

    await tester.tap(find.byKey(const Key('mode-switch')));
    await tester.pumpAndSettle();
    expect(find.text('ワーカーが見つかりました'), findsOneWidget);
    expect(find.text('佐藤 拓海さん'), findsOneWidget);
  });

  testWidgets('worker arrival, safety checks, and work sync to requester', (
    tester,
  ) async {
    final request = SnowRequest(
      id: 'active-request',
      ownerId: 'demo-worker-takumi',
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

    expect(find.text('ワーカーが見つかりました'), findsOneWidget);
    await tester.tap(find.byKey(const Key('mode-switch')));
    await tester.pumpAndSettle();
    expect(find.text('受注しました'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('start-moving')));
    await tester.tap(find.byKey(const Key('start-moving')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(repository.findById(request.id)?.status, RequestStatus.moving);
    expect(find.text('現地へ移動'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mark-arrived')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('作業前の安全確認'), findsOneWidget);

    for (var index = 0; index < 3; index++) {
      await tester.ensureVisible(find.byKey(Key('safety-check-$index')));
      await tester.tap(find.byKey(Key('safety-check-$index')));
      await tester.pump();
    }
    await tester.ensureVisible(find.byKey(const Key('start-work')));
    await tester.tap(find.byKey(const Key('start-work')));
    await tester.pump(const Duration(milliseconds: 350));
    expect(repository.findById(request.id)?.status, RequestStatus.working);
    expect(find.text('除雪作業中'), findsOneWidget);

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mode-switch')).last);
    await tester.pumpAndSettle();
    expect(find.text('除雪作業中です'), findsOneWidget);
    expect(find.text('作業進捗'), findsOneWidget);
  });

  testWidgets('completion photos, approval, demo payment, and rating sync', (
    tester,
  ) async {
    final request = SnowRequest(
      id: 'completion-request',
      ownerId: 'demo-worker-takumi',
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
      status: RequestStatus.working,
      workerId: 'demo-worker-takumi',
      workerName: '佐藤 拓海さん',
      startedAt: DateTime(2026, 8, 13, 9, 15),
      createdAt: DateTime(2026, 8, 13),
    );
    final repository = InMemoryRequestRepository(seedRequests: [request]);
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(home: ModeShell(repository: repository)),
    );

    await tester.tap(find.byKey(const Key('mode-switch')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('open-completion')));
    await tester.tap(find.byKey(const Key('open-completion')));
    await tester.pumpAndSettle();
    expect(find.text('作業完了を送信'), findsWidgets);

    await tester.ensureVisible(find.byKey(const Key('submit-completion')));
    await tester.tap(find.byKey(const Key('submit-completion')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(repository.findById(request.id)?.status, RequestStatus.reviewing);
    expect(find.text('依頼者の確認待ち'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mode-switch')));
    await tester.pumpAndSettle();
    expect(find.text('完了写真を確認'), findsOneWidget);
    expect(find.text('BEFORE'), findsOneWidget);
    expect(find.text('AFTER'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('approve-completion')));
    await tester.tap(find.byKey(const Key('approve-completion')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(repository.findById(request.id)?.status, RequestStatus.completed);
    expect(find.text('雪かき、完了です'), findsOneWidget);
    expect(find.text('支払い完了'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('rating-4')));
    await tester.tap(find.byKey(const Key('rating-4')));
    await tester.ensureVisible(find.byKey(const Key('rate-and-home')));
    await tester.tap(find.byKey(const Key('rate-and-home')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(repository.findById(request.id)?.rating, 4);
    expect(find.text('おはようございます'), findsOneWidget);
  });
}
