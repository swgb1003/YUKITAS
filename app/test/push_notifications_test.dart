import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yukitas/app/mode_shell.dart';
import 'package:yukitas/application/notifications/push_notification_service.dart';
import 'package:yukitas/domain/notifications/app_notification.dart';
import 'package:yukitas/infrastructure/requests/in_memory_request_repository.dart';

class _FakePushNotificationService extends ChangeNotifier
    implements PushNotificationService {
  final List<AppNotification> _notifications = [];

  @override
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  @override
  int get unreadCount => _notifications.where((n) => !n.read).length;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> setWorkerSubscribed(bool subscribed) async {}

  @override
  void markAllRead() {
    for (final n in _notifications) {
      n.read = true;
    }
    notifyListeners();
  }

  void push(AppNotification notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }
}

void main() {
  testWidgets('bell shows an unread badge and clears it after opening', (
    tester,
  ) async {
    final requestRepository = InMemoryRequestRepository(seedRequests: const []);
    addTearDown(requestRepository.dispose);
    final pushService = _FakePushNotificationService();
    addTearDown(pushService.dispose);
    pushService.push(
      AppNotification(
        id: 'n1',
        title: 'ワーカーが見つかりました',
        body: 'まもなく現地へ向かいます',
        receivedAt: DateTime(2026, 1, 10, 9, 30),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ModeShell(
          repository: requestRepository,
          pushNotificationService: pushService,
        ),
      ),
    );
    await tester.pump();
    expect(pushService.unreadCount, 1);

    await tester.tap(find.byKey(const Key('open-notifications')));
    await tester.pumpAndSettle();

    expect(find.text('通知'), findsOneWidget);
    expect(find.text('1件の通知'), findsOneWidget);
    expect(find.text('ワーカーが見つかりました'), findsOneWidget);
    expect(find.text('まもなく現地へ向かいます'), findsOneWidget);
    expect(pushService.unreadCount, 0, reason: 'opening the screen marks all read');

    await tester.tap(find.byKey(const Key('close-notifications')));
    await tester.pumpAndSettle();
  });

  testWidgets('empty state is shown when there are no notifications', (
    tester,
  ) async {
    final requestRepository = InMemoryRequestRepository(seedRequests: const []);
    addTearDown(requestRepository.dispose);
    final pushService = _FakePushNotificationService();
    addTearDown(pushService.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ModeShell(
          repository: requestRepository,
          pushNotificationService: pushService,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('open-notifications')));
    await tester.pumpAndSettle();

    expect(find.text('まだ通知はありません'), findsOneWidget);
    expect(find.text('通知はまだ届いていません'), findsOneWidget);
  });
}
