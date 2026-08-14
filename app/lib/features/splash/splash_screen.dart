import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/theme/yukitas_colors.dart';
import '../../core/widgets/gradient_action_button.dart';
import '../../core/widgets/yukitas_snow_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.nextRoute = AppRoutes.login});

  final String nextRoute;

  void _start(BuildContext context) {
    Navigator.of(context).pushReplacementNamed(nextRoute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [YukitasColors.snow, YukitasColors.ice],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: MediaQuery.sizeOf(context).height * 0.56,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback:
                      (bounds) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.white],
                        stops: [0, 0.28],
                      ).createShader(bounds),
                  child: Image.asset(
                    'assets/images/snow_town_hero.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 44, 30, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const YukitasSnowLogo(size: 86),
                    const SizedBox(height: 28),
                    Text(
                      'YUKITAS',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 48,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '雪が積もったを、\n助かったに。',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(height: 1.45),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'AIと地域の力でつなぐ\n新しい雪国の生活インフラ',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF55758C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    GradientActionButton(
                      key: const Key('splash-start'),
                      label: 'はじめる',
                      onPressed: () => _start(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
