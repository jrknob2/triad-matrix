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
  static const Color defaultAccent = Color(0xFFFF6A00);
  static const Color _edgeDarkBackground = Color(0xFF0B0B0D);
  static const Color _edgeDarkSurface = Color(0xFF141416);
  static const Color _edgeDarkSurfaceSecondary = Color(0xFF1F2023);
  static const Color _edgeDarkBorder = Color(0xFF2C2D31);
  static const Color _edgeDarkTextPrimary = Color(0xFFFFFFFF);
  static const Color _edgeDarkTextSecondary = Color(0xFFB5B5B8);
  static const Color _edgeDarkTextMuted = Color(0xFF8A8A8D);
  static const Color _edgeLightBackground = Color(0xFFF7F3EA);
  static const Color _edgeLightSurface = Color(0xFFFFFCF5);
  static const Color _edgeLightSurfaceSecondary = Color(0xFFF0E6D8);
  static const Color _edgeLightBorder = Color(0xFFD8C8B0);
  static const Color _edgeLightTextPrimary = Color(0xFF18130F);
  static const Color _edgeLightTextSecondary = Color(0xFF61584F);
  static const Color _edgeLightTextMuted = Color(0xFF85796D);

  static Color edgeBackground = _edgeDarkBackground;
  static Color edgeSurface = _edgeDarkSurface;
  static Color edgeSurfaceSecondary = _edgeDarkSurfaceSecondary;
  static Color edgeBorder = _edgeDarkBorder;
  static Color edgeTextPrimary = _edgeDarkTextPrimary;
  static Color edgeTextSecondary = _edgeDarkTextSecondary;
  static Color edgeTextMuted = _edgeDarkTextMuted;
  static Color edgeOrange = defaultAccent;
  static Color edgeOrangePressed = const Color(0xFFFF8C42);
  static Color edgeShadow = const Color(0x99000000);
  static const Color edgeNotationPanel = Color(0xFFF7F3EA);
  static const Color edgeNotationInk = Color(0xFF0D0D0F);

  static void configureRuntime({
    required Brightness brightness,
    required Color accentColor,
  }) {
    final bool dark = brightness == Brightness.dark;
    edgeBackground = dark ? _edgeDarkBackground : _edgeLightBackground;
    edgeSurface = dark ? _edgeDarkSurface : _edgeLightSurface;
    edgeSurfaceSecondary = dark
        ? _edgeDarkSurfaceSecondary
        : _edgeLightSurfaceSecondary;
    edgeBorder = dark ? _edgeDarkBorder : _edgeLightBorder;
    edgeTextPrimary = dark ? _edgeDarkTextPrimary : _edgeLightTextPrimary;
    edgeTextSecondary = dark ? _edgeDarkTextSecondary : _edgeLightTextSecondary;
    edgeTextMuted = dark ? _edgeDarkTextMuted : _edgeLightTextMuted;
    edgeOrange = accentColor;
    edgeOrangePressed =
        Color.lerp(accentColor, dark ? Colors.white : Colors.black, 0.18) ??
        accentColor;
    edgeShadow = dark ? const Color(0x99000000) : const Color(0x22000000);
  }

  static ThemeData get drummerEdge {
    final ColorScheme scheme = ColorScheme.dark(
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
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: edgeBackground,
        foregroundColor: edgeTextPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: edgeTextPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: edgeSurface,
        shadowColor: edgeShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: edgeBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: edgeSurfaceSecondary,
        selectedColor: edgeOrange,
        disabledColor: edgeSurface,
        checkmarkColor: edgeTextPrimary,
        labelStyle: TextStyle(
          color: edgeTextPrimary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        secondaryLabelStyle: TextStyle(
          color: edgeTextPrimary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        side: BorderSide(color: edgeBorder),
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
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
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
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
              side: BorderSide(color: edgeBorder, width: 1.2),
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
                  return BorderSide(color: edgeOrange, width: 1.2);
                }
                return BorderSide(color: edgeBorder, width: 1.2);
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
          side: WidgetStateProperty.all(BorderSide(color: edgeBorder)),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w700),
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
                ? FontWeight.w700
                : FontWeight.w600,
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
      dividerTheme: DividerThemeData(color: edgeBorder),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: edgeSurfaceSecondary,
        contentTextStyle: TextStyle(color: edgeTextPrimary),
      ),
    );
  }

  static ThemeData get light {
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: edgeOrange,
          brightness: Brightness.light,
        ).copyWith(
          primary: edgeOrange,
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
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
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
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        secondaryLabelStyle: const TextStyle(
          color: surface,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: edgeOrange,
          foregroundColor: surface,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
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
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
              side: BorderSide(color: edgeOrange, width: 1.5),
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
                  return edgeOrange.withValues(alpha: 0.12);
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
            return states.contains(WidgetState.selected) ? edgeOrange : surface;
          }),
          side: WidgetStateProperty.all(const BorderSide(color: line)),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w700),
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
                ? FontWeight.w700
                : FontWeight.w600,
            color: ink,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? edgeOrange
                : mutedInk,
          );
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: edgeOrange,
        inactiveTrackColor: line,
        thumbColor: edgeOrange,
        overlayColor: edgeOrange.withValues(alpha: 0.16),
      ),
      dividerTheme: const DividerThemeData(color: line),
    );
  }
}
