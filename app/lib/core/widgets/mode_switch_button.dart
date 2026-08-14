import 'package:flutter/material.dart';

import '../../app/user_mode.dart';
import '../../features/common/notifications_screen.dart';
import '../theme/yukitas_colors.dart';
import 'push_notification_scope.dart';

class ModeSwitchButton extends StatelessWidget {
  const ModeSwitchButton({
    required this.mode,
    required this.onPressed,
    super.key,
  });

  final UserMode mode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors =
        mode == UserMode.requester
            ? const [YukitasColors.sky, YukitasColors.action]
            : const [Color(0xFF39CECC), Color(0xFF1597B6)];

    return Semantics(
      button: true,
      label: mode.switchSemanticsLabel,
      child: Tooltip(
        message: mode.switchSemanticsLabel,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33168FE0),
                blurRadius: 14,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('mode-switch'),
              borderRadius: BorderRadius.circular(20),
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Text(
                  mode.actionLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NotificationButton extends StatelessWidget {
  const NotificationButton({super.key});

  @override
  Widget build(BuildContext context) {
    final service = PushNotificationScope.of(context);
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final unread = service.unreadCount;
        return SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Material(
                  color: const Color(0xEFFFFFFF),
                  shape: const CircleBorder(),
                  elevation: 4,
                  shadowColor: const Color(0x26075B9B),
                  child: IconButton(
                    key: const Key('open-notifications'),
                    tooltip: '通知',
                    onPressed:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => NotificationsScreen(service: service),
                          ),
                        ),
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                ),
              ),
              if (unread > 0)
                Positioned(
                  right: 5,
                  top: 3,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: YukitasColors.sos,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
