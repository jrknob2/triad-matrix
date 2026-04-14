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

class DrumHorizontalControlStrip extends StatefulWidget {
  final Widget child;
  final double indicatorTopPadding;

  const DrumHorizontalControlStrip({
    super.key,
    required this.child,
    this.indicatorTopPadding = 4,
  });

  @override
  State<DrumHorizontalControlStrip> createState() =>
      _DrumHorizontalControlStripState();
}

class _DrumHorizontalControlStripState extends State<DrumHorizontalControlStrip> {
  late final ScrollController _controller;
  int _pageCount = 1;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()..addListener(_updateOverflow);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateOverflow());
  }

  @override
  void didUpdateWidget(covariant DrumHorizontalControlStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateOverflow());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_updateOverflow)
      ..dispose();
    super.dispose();
  }

  void _updateOverflow() {
    if (!mounted || !_controller.hasClients) return;
    final double viewportWidth = _controller.position.viewportDimension;
    if (viewportWidth <= 0) return;
    final double contentWidth =
        _controller.position.maxScrollExtent + viewportWidth;
    final int nextPageCount = (contentWidth / viewportWidth).ceil().clamp(
      1,
      1000,
    );
    final int nextCurrentPage = (_controller.offset / viewportWidth)
        .round()
        .clamp(0, nextPageCount - 1);
    if (nextPageCount == _pageCount && nextCurrentPage == _currentPage) return;
    setState(() {
      _pageCount = nextPageCount;
      _currentPage = nextCurrentPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateOverflow());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          child: widget.child,
        ),
        if (_pageCount > 1)
          Padding(
            padding: EdgeInsets.only(top: widget.indicatorTopPadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(_pageCount, (int index) {
                final bool active = index == _currentPage;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    width: active ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? DrumcabularyTheme.ink
                          : DrumcabularyTheme.line,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
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

class DrumSelectablePill extends StatelessWidget {
  final Widget label;
  final bool selected;
  final VoidCallback? onPressed;

  const DrumSelectablePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: DefaultTextStyle.merge(
        style: TextStyle(
          color: selected ? Colors.white : DrumcabularyTheme.ink,
          fontWeight: FontWeight.w900,
        ),
        child: label,
      ),
      selected: selected,
      onSelected: onPressed == null ? null : (_) => onPressed!(),
      visualDensity: VisualDensity.compact,
      showCheckmark: false,
      side: BorderSide(
        color: selected ? DrumcabularyTheme.ink : DrumcabularyTheme.line,
      ),
      selectedColor: DrumcabularyTheme.ink,
      backgroundColor: DrumcabularyTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class DrumActionPill extends StatelessWidget {
  final Widget label;
  final VoidCallback? onPressed;
  final bool prominent;

  const DrumActionPill({
    super.key,
    required this.label,
    required this.onPressed,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: DefaultTextStyle.merge(
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: prominent ? DrumcabularyTheme.surface : DrumcabularyTheme.ink,
        ),
        child: label,
      ),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      side: BorderSide(
        color: prominent ? DrumcabularyTheme.ink : DrumcabularyTheme.line,
      ),
      backgroundColor: prominent
          ? DrumcabularyTheme.ink
          : DrumcabularyTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class DrumIndexedPill extends StatelessWidget {
  final String indexLabel;
  final Widget label;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color borderColor;

  const DrumIndexedPill({
    super.key,
    required this.indexLabel,
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Text(
        indexLabel,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
      label: DefaultTextStyle.merge(
        style: const TextStyle(fontWeight: FontWeight.w900),
        child: label,
      ),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      backgroundColor: backgroundColor,
      side: BorderSide(color: borderColor),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
    );
  }
}

class DrumTag extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final Color? borderColor;

  const DrumTag({
    super.key,
    required this.child,
    this.backgroundColor = DrumcabularyTheme.surface,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? DrumcabularyTheme.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: child,
      ),
    );
  }
}
