import 'package:flutter/foundation.dart';

import '../../application/notifications/push_notification_service.dart';
import '../../domain/notifications/app_notification.dart';

/// No-op stand-in for demo/non-Firebase builds, so the notification bell
/// exists and renders without a real FCM setup behind it.
class DemoPushNotificationService extends ChangeNotifier
    implements PushNotificationService {
  @override
  List<AppNotification> get notifications => const [];

  @override
  int get unreadCount => 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> setWorkerSubscribed(bool subscribed) async {}

  @override
  void markAllRead() {}
}
