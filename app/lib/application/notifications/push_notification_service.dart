import 'package:flutter/foundation.dart';

import '../../domain/notifications/app_notification.dart';

/// Push notifications (FCM) for request status changes and, in worker mode,
/// newly published requests. [DemoPushNotificationService] is a no-op stand-in
/// for builds without Firebase; [FirebasePushNotificationService] (in
/// infrastructure/) is the real implementation.
abstract interface class PushNotificationService implements Listenable {
  List<AppNotification> get notifications;
  int get unreadCount;

  /// Requests permission, registers this device's FCM token, and starts
  /// listening for foreground messages. Safe to call once, best-effort - a
  /// platform without push support (or a denied permission) just means
  /// [notifications] stays empty.
  Future<void> initialize();

  /// Workers get pushed newly published requests via the 'workers' FCM
  /// topic; requesters don't need it. Call whenever the user's mode changes.
  Future<void> setWorkerSubscribed(bool subscribed);

  void markAllRead();
}
