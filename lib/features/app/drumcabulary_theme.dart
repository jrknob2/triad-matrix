import 'package:flutter/material.dart';

class DrumcabularyTheme {
  // Legacy warm tokens (kept for backward compat)
  static const Color ink = Color(0xFF17130F);
  static const Color paper = Color(0xFFFBF4E7);
  static const Color surface = Color(0xFFFFFAF0);
  static const Color surfaceStrong = Color(0xFFF0E3CC);
  static const Color line = Color(0xFFD8C8B0);
  static const Color mutedInk = Color(0xFF665C4E);
  static const Color orange = Color(0xFFF05A28);
  static const Color gold = Color(0xFFF0C35B);
  static const Color blue = Color(0xFF2F6FCC);
  static const Color green = Color(0xFF3C8B58);

  // Dark palette tokens
  static const Color appBackground = Color(0xFF0A0F14);
  static const Color darkSurface = Color(0xFF121A22);
  static const Color tealPrimary = Color(0xFF00C2C7);
  static const Color tealSecondary = Color(0xFF147A7E);
  static const Color pulsePrimary = Color(0xFFBF5700);
  static const Color pulseHover = Color(0xFFD46A1A);
  static const Color progressPrimary = Color(0xFF3FAF7A);
  static const Color progressActive = Color(0xFF58C98A);
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF8A9AA8);
  static const Color darkDivider = Color(0xFF1F2A33);
  static const Color tickNeutral = Color(0xFF2A343D);
  static const Color creamText = Color(0xFFFFF4DC);

  static ThemeData get light {
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: orange,
          brightness: Brightness.light,
        ).copyWith(
          primary: orange,
          onPrimary: surface,
          secondary: gold,
          secondaryContainer: ink,
          onSecondaryContainer: surface,
          tertiary: blue,
          surface: surface,
          onSurface: ink,
          outline: line,
        );

    final TextTheme textTheme = Typography.blackCupertino.apply(
      bodyColor: ink,
      displayColor: ink,
      fontFamily: 'Avenir Next',
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: paper,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: paper,
        foregroundColor: ink,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shadowColor: ink.withValues(alpha: 0.16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: line),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceStrong,
        selectedColor: ink,
        disabledColor: const Color(0xFFE8E0D2),
        checkmarkColor: surface,
        labelStyle: const TextStyle(
          color: ink,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.1,
        ),
        secondaryLabelStyle: const TextStyle(
          color: surface,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.1,
        ),
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: surface,
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              foregroundColor: ink,
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
              side: const BorderSide(color: ink, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return ink.withValues(alpha: 0.14);
                }
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)) {
                  return orange.withValues(alpha: 0.12);
                }
                return null;
              }),
            ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected) ? surface : ink;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected) ? ink : surface;
          }),
          side: WidgetStateProperty.all(const BorderSide(color: line)),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFFF6EFE2),
        indicatorColor: surfaceStrong,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w900
                : FontWeight.w700,
            color: ink,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected) ? ink : mutedInk,
          );
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: ink,
        inactiveTrackColor: line,
        thumbColor: orange,
        overlayColor: orange.withValues(alpha: 0.16),
      ),
      dividerTheme: const DividerThemeData(color: line),
    );
  }
}
