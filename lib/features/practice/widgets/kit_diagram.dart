// lib/features/practice/widgets/kit_diagram.dart
//
// Triad Trainer — Kit Diagram Widget (v1)
//
// Purpose:
// - Render a simple pad/kit graphic ABOVE the pattern card.
// - Show voice labels on each surface.
// - Keep this as a pure widget (no controller, no models defined here).
//
// Usage idea (from a screen/widget):
//   KitDiagram(
//     title: 'Pad',
//     surfaces: const <KitSurfaceSpec>[
//       KitSurfaceSpec(id: 'S', label: 'S', kind: KitSurfaceKind.snare),
//       KitSurfaceSpec(id: 'K', label: 'K', kind: KitSurfaceKind.kick),
//     ],
//   )
//
// Notes:
// - "label" is what you want printed on the surface (S, 1, F, H, R, K, etc).
// - For pad mode: pass only snare (S) (and optionally kick).
// - For kit mode: pass the set you want shown.

import 'package:flutter/material.dart';

/* ------------------------------- Public API -------------------------------- */

enum KitSurfaceKind {
  snare,
  tom1,
  tom2,
  floorTom,
  hiHat,
  ride,
  kick,
}

class KitSurfaceSpec {
  final String id;
  final String label;
  final KitSurfaceKind kind;

  /// Optional hint to emphasize a surface (later: show active limb hits).
  final bool emphasized;

  const KitSurfaceSpec({
    required this.id,
    required this.label,
    required this.kind,
    this.emphasized = false,
  });
}

class KitDiagram extends StatelessWidget {
  final String? title;

  /// Ordered list of surfaces to render.
  final List<KitSurfaceSpec> surfaces;

  /// Compact is useful for narrow screens.
  final bool compact;

  const KitDiagram({
    super.key,
    required this.surfaces,
    this.title,
    this.compact = false
  });

  @override
  Widget build(BuildContext context) {
    // Use theme colors; keep it calm.
    final ColorScheme cs = Theme.of(context).colorScheme;

    final double height = compact ? 92 : 116;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (title != null) ...<Widget>[
              Row(
                children: <Widget>[
                  Text(
                    title!,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              height: height,
              width: double.infinity,
              child: CustomPaint(
                painter: _KitDiagramPainter(
                  surfaces: surfaces,
                  onSurface: cs.onSurface,
                  outline: cs.outlineVariant,
                  fill: cs.surface,
                  emphasizedFill: cs.surfaceContainerHighest,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------- Painter ----------------------------------- */

class _KitDiagramPainter extends CustomPainter {
  final List<KitSurfaceSpec> surfaces;

  final Color onSurface;
  final Color outline;
  final Color fill;
  final Color emphasizedFill;

  _KitDiagramPainter({
    required this.surfaces,
    required this.onSurface,
    required this.outline,
    required this.fill,
    required this.emphasizedFill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = outline;

    // Slightly different fill when emphasized
    Paint fillPaint(bool emphasized) => Paint()
      ..style = PaintingStyle.fill
      ..color = emphasized ? emphasizedFill : fill;

    // Layout: a simple “kit map” that adapts to what surfaces are present.
    // We compute anchor positions for each kind and then draw only what's included.
    final Map<KitSurfaceKind, Offset> pos = _positions(size);
    final Map<KitSurfaceKind, double> r = _radii(size);

    final TextStyle labelStyle = TextStyle(
      color: onSurface,
      fontWeight: FontWeight.w800,
      fontSize: _labelFontSize(size),
      height: 1.0,
    );

    for (final KitSurfaceSpec s in surfaces) {
      final Offset? c = pos[s.kind];
      final double? rad = r[s.kind];
      if (c == null || rad == null) continue;

      final Rect bounds = Rect.fromCircle(center: c, radius: rad);

      // Surface body
      canvas.drawOval(bounds, fillPaint(s.emphasized));
      canvas.drawOval(bounds, borderPaint);

      // Label centered
      _drawCenteredText(canvas, bounds, s.label, labelStyle);
    }

    // Subtle “stand” line under kick if kick exists (nice touch, still calm)
    if (surfaces.any((s) => s.kind == KitSurfaceKind.kick)) {
      final Offset c = pos[KitSurfaceKind.kick]!;
      final double rad = r[KitSurfaceKind.kick]!;
      final Paint stand = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = outline;

      final double y = c.dy + rad + 6;
      canvas.drawLine(Offset(c.dx - rad * 0.65, y), Offset(c.dx + rad * 0.65, y), stand);
    }
  }

  Map<KitSurfaceKind, Offset> _positions(Size size) {
    final double w = size.width;
    final double h = size.height;

    // Top row
    final Offset hh = Offset(w * 0.22, h * 0.30);
    final Offset ride = Offset(w * 0.78, h * 0.30);
    final Offset tom1 = Offset(w * 0.42, h * 0.28);
    final Offset tom2 = Offset(w * 0.58, h * 0.28);

    // Middle row
    final Offset snare = Offset(w * 0.38, h * 0.62);
    final Offset floor = Offset(w * 0.66, h * 0.62);

    // Bottom
    final Offset kick = Offset(w * 0.52, h * 0.86);

    return <KitSurfaceKind, Offset>{
      KitSurfaceKind.hiHat: hh,
      KitSurfaceKind.ride: ride,
      KitSurfaceKind.tom1: tom1,
      KitSurfaceKind.tom2: tom2,
      KitSurfaceKind.snare: snare,
      KitSurfaceKind.floorTom: floor,
      KitSurfaceKind.kick: kick,
    };
  }

  Map<KitSurfaceKind, double> _radii(Size size) {
    final double base = (size.shortestSide * 0.16).clamp(16.0, 26.0);

    return <KitSurfaceKind, double>{
      KitSurfaceKind.hiHat: base * 0.95,
      KitSurfaceKind.ride: base * 1.05,
      KitSurfaceKind.tom1: base * 0.90,
      KitSurfaceKind.tom2: base * 0.90,
      KitSurfaceKind.snare: base * 1.05,
      KitSurfaceKind.floorTom: base * 1.00,
      KitSurfaceKind.kick: base * 1.15,
    };
  }

  double _labelFontSize(Size size) {
    final double s = size.shortestSide;
    if (s < 120) return 12;
    if (s < 180) return 14;
    return 16;
  }

  void _drawCenteredText(
    Canvas canvas,
    Rect bounds,
    String text,
    TextStyle style,
  ) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final Offset p = Offset(
      bounds.center.dx - tp.width / 2,
      bounds.center.dy - tp.height / 2,
    );

    tp.paint(canvas, p);
  }

  @override
  bool shouldRepaint(covariant _KitDiagramPainter oldDelegate) {
    if (identical(oldDelegate.surfaces, surfaces)) return false;
    if (oldDelegate.surfaces.length != surfaces.length) return true;
    for (int i = 0; i < surfaces.length; i++) {
      final a = oldDelegate.surfaces[i];
      final b = surfaces[i];
      if (a.kind != b.kind || a.label != b.label || a.emphasized != b.emphasized) return true;
    }
    return false;
  }
}
