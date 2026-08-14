import 'package:flutter/material.dart';

import 'yukitas_colors.dart';

class YukitasTheme {
  const YukitasTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: YukitasColors.action,
        brightness: Brightness.light,
        primary: YukitasColors.action,
        secondary: YukitasColors.safe,
        surface: YukitasColors.snow,
        error: YukitasColors.sos,
      ),
      scaffoldBackgroundColor: YukitasColors.snow,
      splashFactory: InkSparkle.splashFactory,
      fontFamily: 'NotoSansJP',
      fontFamilyFallback: const ['Noto Sans JP', 'Yu Gothic', 'Meiryo'],
    );

    final japaneseTextTheme = base.textTheme
        .copyWith(
          displayLarge: const TextStyle(
            color: YukitasColors.ink,
            fontSize: 54,
            fontWeight: FontWeight.w800,
            height: 1.05,
            letterSpacing: -1.6,
          ),
          headlineLarge: const TextStyle(
            color: YukitasColors.ink,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.18,
            letterSpacing: -0.8,
          ),
          headlineMedium: const TextStyle(
            color: YukitasColors.ink,
            fontSize: 23,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
          titleLarge: const TextStyle(
            color: YukitasColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
          titleMedium: const TextStyle(
            color: YukitasColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          bodyLarge: const TextStyle(
            color: YukitasColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.55,
          ),
          bodyMedium: const TextStyle(
            color: YukitasColors.ink,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
          labelLarge: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        )
        .apply(fontFamily: 'NotoSansJP');

    return base.copyWith(
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'NotoSansJP'),
      textTheme: japaneseTextTheme,
      dividerColor: YukitasColors.outline,
      iconTheme: const IconThemeData(color: YukitasColors.deep),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: YukitasColors.ice,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'NotoSansJP',
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
