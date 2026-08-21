import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../application/notifications/push_notification_service.dart';
import '../../domain/notifications/app_notification.dart';

/// FCM-backed [PushNotificationService]. Registers this device's token under
/// `users/{userId}.fcmTokens` so Cloud Functions can target it, and surfaces
/// foreground messages as an in-memory, session-scoped notification list.
class FirebasePushNotificationService extends ChangeNotifier
    implements PushNotificationService {
  FirebasePushNotificationService({required this.userId});

  final String userId;
  final List<AppNotification> _notifications = [];
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  int _nextLocalId = 0;

  @override
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  @override
  int get unreadCount => _notifications.where((n) => !n.read).length;

  @override
  void markAllRead() {
    if (_notifications.isEmpty) return;
    for (final notification in _notifications) {
      notification.read = true;
    }
    notifyListeners();
  }

  /// Best-effort end to end: a platform without push support, a denied
  /// permission, or an unreachable Firestore just leaves [notifications]
  /// empty rather than crashing the app.
  @override
  Future<void> initialize() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token != null) unawaited(_saveToken(token));
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen(_saveToken);
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );
    } catch (_) {
      // No push support on this platform/build - the bell just stays empty.
    }
  }

  /// Cells this device is currently subscribed to, so switching areas can
  /// drop the topics that no longer apply.
  Set<String> _subscribedCells = <String>{};

  @override
  Future<void> setWorkerSubscribed(
    bool subscribed, {
    List<String> cells = const <String>[],
  }) async {
    final wanted = subscribed ? cells.toSet() : <String>{};
    try {
      final messaging = FirebaseMessaging.instance;
      for (final cell in _subscribedCells.difference(wanted)) {
        await messaging.unsubscribeFromTopic('cell_$cell');
      }
      for (final cell in wanted.difference(_subscribedCells)) {
        await messaging.subscribeToTopic('cell_$cell');
      }
      _subscribedCells = wanted;
    } catch (_) {
      // Best-effort, same as initialize().
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _notifications.insert(
      0,
      AppNotification(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}-${_nextLocalId++}',
        title: notification.title ?? 'YUKITAS',
        body: notification.body ?? '',
        receivedAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  Future<void> _saveToken(String token) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // This device just won't receive push until the next successful sync.
    }
  }

  @override
  void dispose() {
    _foregroundSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
    super.dispose();
  }
}
