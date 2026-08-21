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

  /// Subscribes a worker to new-request pushes for the areas they are in.
  ///
  /// [cells] are geohash cells (see `lib/core/geo/geo_cell.dart`); one FCM
  /// topic per cell. This used to be a single global 'workers' topic, which
  /// pushed every request in the country to every worker in it. Requesters
  /// don't need any of these - pass `subscribed: false`.
  ///
  /// Call whenever the user's mode or position changes.
  Future<void> setWorkerSubscribed(
    bool subscribed, {
    List<String> cells = const <String>[],
  });

  void markAllRead();
}
