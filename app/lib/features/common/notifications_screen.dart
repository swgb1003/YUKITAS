import 'package:flutter/material.dart';

import '../../app/user_mode.dart';
import '../../application/notifications/push_notification_service.dart';
import '../../core/theme/yukitas_colors.dart';
import '../../core/widgets/frosted_card.dart';
import '../../core/widgets/screen_header.dart';
import '../../domain/notifications/app_notification.dart';

/// Push notifications received this session (依頼の状態変化、新着依頼など).
/// Opened from the notification bell; marks everything read on open.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({required this.service, super.key});

  final PushNotificationService service;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.service.markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE7F7FF), YukitasColors.snow],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: widget.service,
            builder: (context, _) {
              final notifications = widget.service.notifications;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    YukitasScreenHeader(
                      mode: UserMode.requester,
                      eyebrow: 'YUKITAS',
                      title: '通知',
                      subtitle:
                          notifications.isEmpty
                              ? 'まだ通知はありません'
                              : '${notifications.length}件の通知',
                      onToggleMode: () {},
                      trailing: IconButton.filledTonal(
                        key: const Key('close-notifications'),
                        tooltip: '閉じる',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (notifications.isEmpty)
                      const _EmptyNotifications()
                    else
                      for (var index = 0; index < notifications.length; index++) ...[
                        _NotificationCard(
                          key: Key('notification-${notifications[index].id}'),
                          notification: notifications[index],
                        ),
                        if (index != notifications.length - 1)
                          const SizedBox(height: 12),
                      ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, super.key});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      padding: const EdgeInsets.all(16),
      radius: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: YukitasColors.ice,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: YukitasColors.action,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  notification.body,
                  style: const TextStyle(
                    color: YukitasColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatTime(notification.receivedAt),
                  style: const TextStyle(
                    color: YukitasColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
      radius: 26,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: YukitasColors.ice,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 34,
              color: YukitasColors.action,
            ),
          ),
          const SizedBox(height: 18),
          Text('通知はまだ届いていません', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text(
            '依頼の状況が変わったときや\n新しい依頼が届いたときにここでお知らせします',
            textAlign: TextAlign.center,
            style: TextStyle(color: YukitasColors.muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}
