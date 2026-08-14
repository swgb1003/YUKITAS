import 'package:flutter/material.dart';

import '../theme/yukitas_colors.dart';

class YukitasSnowLogo extends StatelessWidget {
  const YukitasSnowLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'YUKITAS',
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.13),
        decoration: BoxDecoration(
          color: const Color(0x4D48BDF7),
          borderRadius: BorderRadius.circular(size * 0.35),
          border: Border.all(color: const Color(0x6648BDF7)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3348BDF7),
              blurRadius: 28,
              spreadRadius: 5,
            ),
          ],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF79D7FF), YukitasColors.action],
            ),
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x5948BDF7),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Icon(
            Icons.ac_unit_rounded,
            size: size * 0.5,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
