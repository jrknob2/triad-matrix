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

  // Drummer Edge visual direction
  static const Color edgeBackground = Color(0xFF0B0B0D);
  static const Color edgeSurface = Color(0xFF141416);
  static const Color edgeSurfaceSecondary = Color(0xFF1F2023);
  static const Color edgeBorder = Color(0xFF2C2D31);
  static const Color edgeTextPrimary = Color(0xFFFFFFFF);
  static const Color edgeTextSecondary = Color(0xFFB5B5B8);
  static const Color edgeTextMuted = Color(0xFF8A8A8D);
  static const Color edgeOrange = Color(0xFFFF6A00);
  static const Color edgeOrangePressed = Color(0xFFFF8C42);
  static const Color edgeShadow = Color(0x99000000);
  static const Color edgeNotationPanel = Color(0xFFF7F3EA);
  static const Color edgeNotationInk = Color(0xFF0D0D0F);

  static ThemeData get drummerEdge {
    const ColorScheme scheme = ColorScheme.dark(
      primary: edgeOrange,
      onPrimary: edgeTextPrimary,
      secondary: edgeOrangePressed,
      onSecondary: edgeBackground,
      surface: edgeSurface,
      onSurface: edgeTextPrimary,
      outline: edgeBorder,
      error: Color(0xFFFF5A5F),
      onError: edgeTextPrimary,
    );

    final TextTheme textTheme = Typography.whiteCupertino.apply(
      bodyColor: edgeTextPrimary,
      displayColor: edgeTextPrimary,
      fontFamily: 'Avenir Next',
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: edgeBackground,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: edgeBackground,
        foregroundColor: edgeTextPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: edgeTextPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: edgeSurface,
        shadowColor: edgeShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: edgeBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: edgeSurfaceSecondary,
        selectedColor: edgeOrange,
        disabledColor: edgeSurface,
        checkmarkColor: edgeTextPrimary,
        labelStyle: const TextStyle(
          color: edgeTextPrimary,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
        secondaryLabelStyle: const TextStyle(
          color: edgeTextPrimary,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
        side: const BorderSide(color: edgeBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              backgroundColor: edgeOrange,
              foregroundColor: edgeTextPrimary,
              disabledBackgroundColor: edgeSurfaceSecondary,
              disabledForegroundColor: edgeTextMuted,
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return edgeOrangePressed.withValues(alpha: 0.28);
                }
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)) {
                  return edgeOrangePressed.withValues(alpha: 0.16);
                }
                return null;
              }),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              foregroundColor: edgeTextPrimary,
              disabledForegroundColor: edgeTextMuted,
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
              side: const BorderSide(color: edgeBorder, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return edgeOrange.withValues(alpha: 0.18);
                }
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)) {
                  return edgeOrange.withValues(alpha: 0.12);
                }
                return null;
              }),
              side: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed) ||
                    states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)) {
                  return const BorderSide(color: edgeOrange, width: 1.2);
                }
                return const BorderSide(color: edgeBorder, width: 1.2);
              }),
            ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: edgeTextPrimary,
          disabledForegroundColor: edgeTextMuted.withValues(alpha: 0.52),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? edgeTextPrimary
                : edgeTextSecondary;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? edgeOrange
                : edgeSurface;
          }),
          side: WidgetStateProperty.all(const BorderSide(color: edgeBorder)),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: edgeSurface,
        indicatorColor: edgeSurfaceSecondary,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w900
                : FontWeight.w700,
            color: states.contains(WidgetState.selected)
                ? edgeTextPrimary
                : edgeTextSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? edgeOrange
                : edgeTextSecondary,
          );
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: edgeOrange,
        inactiveTrackColor: edgeBorder,
        thumbColor: edgeOrange,
        overlayColor: edgeOrange.withValues(alpha: 0.16),
      ),
      dividerTheme: const DividerThemeData(color: edgeBorder),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: edgeSurfaceSecondary,
        contentTextStyle: TextStyle(color: edgeTextPrimary),
      ),
    );
  }

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
