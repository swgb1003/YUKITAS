import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/yukitas_colors.dart';

class FrostedCard extends StatelessWidget {
  const FrostedCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.color = const Color(0xDFFFFFFF),
    this.borderColor = const Color(0xEFFFFFFF),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary isolates this card's BackdropFilter blur into its own
    // compositor layer. Without it, Android has been seen corrupting glyphs
    // in nearby text sharing the same frame (a stray white box replacing the
    // character) - a known BackdropFilter/text interaction issue, not
    // something a font change can fix.
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F075B9B),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
                BoxShadow(
                  color: YukitasColors.mist,
                  blurRadius: 1,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
