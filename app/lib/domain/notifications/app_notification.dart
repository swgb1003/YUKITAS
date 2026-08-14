/// A push notification received while the app was open, kept in memory for
/// the session so the notification bell (see [NotificationButton]) has
/// something to show. Not persisted - a fresh launch starts empty, same as
/// the underlying FCM message stream.
class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;
  bool read;
}
