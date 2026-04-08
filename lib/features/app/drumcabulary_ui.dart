import 'package:flutter/material.dart';

import 'drumcabulary_theme.dart';

enum DrumPanelTone { surface, warm, dark, blue, green }

class DrumScreen extends StatelessWidget {
  final Widget child;
  final bool warm;

  const DrumScreen({super.key, required this.child, this.warm = true});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: warm
              ? const <Color>[Color(0xFFF7E8C7), Color(0xFFF8F6F1)]
              : const <Color>[Color(0xFFF5EEE1), Color(0xFFF8F6F1)],
        ),
      ),
      child: child,
    );
  }
}

class DrumPanel extends StatelessWidget {
  final Widget child;
  final DrumPanelTone tone;
  final EdgeInsetsGeometry padding;

  const DrumPanel({
    super.key,
    required this.child,
    this.tone = DrumPanelTone.surface,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  Color get _background {
    return switch (tone) {
      DrumPanelTone.surface => DrumcabularyTheme.surface,
      DrumPanelTone.warm => DrumcabularyTheme.paper,
      DrumPanelTone.dark => DrumcabularyTheme.ink,
      DrumPanelTone.blue => const Color(0xFFE5EFF6),
      DrumPanelTone.green => const Color(0xFFE5F0E4),
    };
  }

  Color get _borderColor {
    return switch (tone) {
      DrumPanelTone.dark => const Color(0xFF3A3329),
      _ => DrumcabularyTheme.line,
    };
  }
}

class DrumActionRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const DrumActionRow({super.key, required this.children, this.spacing = 10});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: spacing, runSpacing: spacing, children: children);
  }
}

class DrumSectionTitle extends StatelessWidget {
  final String text;
  final Color? color;

  const DrumSectionTitle({super.key, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: color,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.3,
      ),
    );
  }
}

class DrumEyebrow extends StatelessWidget {
  final String text;
  final Color? color;

  const DrumEyebrow({super.key, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: color ?? DrumcabularyTheme.mutedInk,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    );
  }
}

class DrumStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const DrumStatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x22000000)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
