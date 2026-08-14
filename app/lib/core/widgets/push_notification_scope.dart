import 'package:flutter/widgets.dart';

import '../../application/notifications/push_notification_service.dart';

/// Makes the active [PushNotificationService] available to [NotificationButton]
/// without threading it through every screen that shows one.
class PushNotificationScope extends InheritedNotifier<PushNotificationService> {
  const PushNotificationScope({
    required PushNotificationService service,
    required super.child,
    super.key,
  }) : super(notifier: service);

  static PushNotificationService of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<PushNotificationScope>();
    assert(scope != null, 'No PushNotificationScope found in context');
    return scope!.notifier!;
  }
}
