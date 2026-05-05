import 'package:flutter/material.dart';

class PatternTextStyles {
  static const String notationFontFamily = 'Courier';
  static const double editableInputFontSize = 24;
  static const double editableInputLineHeight = 1.0;
  static const EdgeInsets editableInputPadding = EdgeInsets.fromLTRB(
    16,
    14,
    16,
    14,
  );

  static TextStyle compact(BuildContext context, {Color? color}) {
    return _base(
      context,
      fallbackFontSize: 18,
      source: Theme.of(context).textTheme.titleMedium,
      color: color,
    );
  }

  static TextStyle card(BuildContext context, {Color? color}) {
    return _base(
      context,
      fallbackFontSize: 20,
      source: Theme.of(context).textTheme.titleLarge,
      color: color,
    );
  }

  static TextStyle summary(BuildContext context, {Color? color}) {
    return _base(
      context,
      fallbackFontSize: 24,
      source: Theme.of(context).textTheme.headlineSmall,
      color: color,
    );
  }

  static TextStyle editableInput(BuildContext context) {
    return _base(
      context,
      fallbackFontSize: editableInputFontSize,
      source: Theme.of(context).textTheme.titleMedium,
    ).copyWith(
      fontSize: editableInputFontSize,
      height: editableInputLineHeight,
    );
  }

  static TextStyle applyNotationFace(TextStyle style) {
    return style.copyWith(
      fontFamily: notationFontFamily,
      fontWeight: style.fontWeight ?? FontWeight.w900,
      letterSpacing: 0,
    );
  }

  static TextStyle _base(
    BuildContext context, {
    required double fallbackFontSize,
    required TextStyle? source,
    Color? color,
  }) {
    return (source ?? TextStyle(fontSize: fallbackFontSize)).copyWith(
      color: color,
      fontFamily: notationFontFamily,
      fontWeight: FontWeight.w900,
      letterSpacing: 0,
    );
  }
}
