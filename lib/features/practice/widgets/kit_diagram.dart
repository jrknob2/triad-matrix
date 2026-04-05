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
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    final double height = compact ? 92 : 116;

    // IMPORTANT: no Card/background. We want it to feel "painted" on the screen.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
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
                fill: cs.onSurface.withValues(alpha: 0.06),
                emphasizedFill: cs.onSurface.withValues(alpha: 0.10),
              ),
            ),
          ),
        ],
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

    Paint fillPaint(bool emphasized) => Paint()
      ..style = PaintingStyle.fill
      ..color = emphasized ? emphasizedFill : fill;

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

      final bool isPadSurface = _isPadOnlySurface(s);

      if (isPadSurface) {
        // Pad should be octagonal (your requirement).
        final Path oct = _octagonPath(bounds, cutFactor: 0.22);
        canvas.drawPath(oct, fillPaint(s.emphasized));
        canvas.drawPath(oct, borderPaint);
        _drawCenteredText(canvas, bounds, s.label, labelStyle);
      } else {
        // Default: oval/circle for kit pieces.
        canvas.drawOval(bounds, fillPaint(s.emphasized));
        canvas.drawOval(bounds, borderPaint); // <-- uses borderPaint (fixes warning)
        _drawCenteredText(canvas, bounds, s.label, labelStyle);
      }
    }

    // Subtle “stand” line under kick if kick exists.
    if (surfaces.any((s) => s.kind == KitSurfaceKind.kick)) {
      final Offset c = pos[KitSurfaceKind.kick]!;
      final double rad = r[KitSurfaceKind.kick]!;
      final Paint stand = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = outline;

      final double y = c.dy + rad + 6;
      canvas.drawLine(
        Offset(c.dx - rad * 0.65, y),
        Offset(c.dx + rad * 0.65, y),
        stand,
      );
    }
  }

  bool _isPadOnlySurface(KitSurfaceSpec s) {
    // In pad mode we pass a single snare surface with id 'pad' (from PracticeScreen).
    // That's the one we want to render as an octagon.
    if (s.id == 'pad') return true;

    // Defensive: if someone passes ONLY snare and labels it as pad, still octagon.
    // But do NOT octagon snare in a full kit.
    if (surfaces.length == 1 && s.kind == KitSurfaceKind.snare) return true;

    return false;
  }

  Path _octagonPath(Rect bounds, {required double cutFactor}) {
    final double w = bounds.width;
    final double h = bounds.height;
    final double cut = (w < h ? w : h) * cutFactor;

    final double x1 = bounds.left;
    final double y1 = bounds.top;
    final double x2 = bounds.right;
    final double y2 = bounds.bottom;

    return Path()
      ..moveTo(x1 + cut, y1)
      ..lineTo(x2 - cut, y1)
      ..lineTo(x2, y1 + cut)
      ..lineTo(x2, y2 - cut)
      ..lineTo(x2 - cut, y2)
      ..lineTo(x1 + cut, y2)
      ..lineTo(x1, y2 - cut)
      ..lineTo(x1, y1 + cut)
      ..close();
  }

  Map<KitSurfaceKind, Offset> _positions(Size size) {
    final double w = size.width;
    final double h = size.height;

    final Offset hh = Offset(w * 0.22, h * 0.30);
    final Offset ride = Offset(w * 0.78, h * 0.30);
    final Offset tom1 = Offset(w * 0.42, h * 0.28);
    final Offset tom2 = Offset(w * 0.58, h * 0.28);

    final Offset snare = Offset(w * 0.38, h * 0.62);
    final Offset floor = Offset(w * 0.66, h * 0.62);

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
      if (a.kind != b.kind || a.label != b.label || a.emphasized != b.emphasized) {
        return true;
      }
      if (a.id != b.id) return true;
    }
    return false;
  }
}
