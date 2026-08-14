import 'package:flutter/material.dart';

import '../theme/yukitas_colors.dart';

class GradientActionButton extends StatelessWidget {
  const GradientActionButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.workerStyle = false,
    this.height = 58,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool workerStyle;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final colors =
        !enabled
            ? const [Color(0xFFD7E4E9), Color(0xFFB7CCD5)]
            : workerStyle
            ? const [Color(0xFF35C9C7), Color(0xFF1192B5)]
            : const [YukitasColors.sky, YukitasColors.action];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(19),
        boxShadow:
            enabled
                ? const [
                  BoxShadow(
                    color: Color(0x33168FE0),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ]
                : null,
      ),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(19),
            onTap: onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 23),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(width: 9),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
