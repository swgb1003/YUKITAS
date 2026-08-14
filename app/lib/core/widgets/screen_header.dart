import 'package:flutter/material.dart';

import '../../app/user_mode.dart';
import '../theme/yukitas_colors.dart';
import 'mode_switch_button.dart';

class YukitasScreenHeader extends StatelessWidget {
  const YukitasScreenHeader({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.onToggleMode,
    super.key,
    this.eyebrow,
    this.trailing,
  });

  final UserMode mode;
  final String title;
  final String subtitle;
  final String? eyebrow;
  final VoidCallback onToggleMode;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow ??
                    (mode == UserMode.worker ? 'WORKER MODE' : 'YUKITAS'),
                style: const TextStyle(
                  color: YukitasColors.action,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              Text(title, style: Theme.of(context).textTheme.headlineLarge),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: YukitasColors.muted),
              ),
            ],
          ),
        ),
        if (trailing != null)
          trailing!
        else ...[
          ModeSwitchButton(mode: mode, onPressed: onToggleMode),
          const SizedBox(width: 8),
          const NotificationButton(),
        ],
      ],
    );
  }
}
