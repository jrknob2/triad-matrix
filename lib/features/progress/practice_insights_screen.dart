import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/drumcabulary_theme.dart';
import '../app/drumcabulary_ui.dart';
import '../coach/lesson_plan_loader.dart';
import '../coach/lesson_progress.dart';
import 'skill_practice_time_aggregator.dart';

class PracticeInsightsScreen extends StatefulWidget {
  final ValueChanged<String>? onOpenSkill;
  final Future<SkillPracticeTimeSnapshot> Function()? snapshotLoader;

  const PracticeInsightsScreen({
    super.key,
    this.onOpenSkill,
    this.snapshotLoader,
  });

  @override
  State<PracticeInsightsScreen> createState() => _PracticeInsightsScreenState();
}

class _PracticeInsightsScreenState extends State<PracticeInsightsScreen> {
  late Future<SkillPracticeTimeSnapshot> _snapshotFuture = _loadSnapshot();
  String? _selectedSkillId;

  Future<SkillPracticeTimeSnapshot> _loadSnapshot() async {
    final Future<SkillPracticeTimeSnapshot> Function()? loader =
        widget.snapshotLoader;
    if (loader != null) return loader();

    final library = await LessonPlanLoader.loadContent();
    final progressService = LessonProgressService(
      const FileLessonProgressStore(),
    );
    await progressService.load();
    return const SkillPracticeTimeAggregator().build(
      library: library,
      progressService: progressService,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DrumScreen(
      child: FutureBuilder<SkillPracticeTimeSnapshot>(
        future: _snapshotFuture,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<SkillPracticeTimeSnapshot> snapshot,
            ) {
              if (snapshot.hasError) {
                return _PracticePortraitError(
                  error: snapshot.error,
                  onRetry: () {
                    setState(() {
                      _snapshotFuture = _loadSnapshot();
                    });
                  },
                );
              }
              final SkillPracticeTimeSnapshot? data = snapshot.data;
              if (data == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return _PracticePortraitView(
                snapshot: data,
                selectedSkillId: _resolveSelectedSkillId(data),
                onSelected: (String skillId) {
                  setState(() => _selectedSkillId = skillId);
                },
                onOpenSkill: widget.onOpenSkill,
              );
            },
      ),
    );
  }

  String? _resolveSelectedSkillId(SkillPracticeTimeSnapshot snapshot) {
    if (snapshot.values.isEmpty) return null;
    final String? selectedSkillId = _selectedSkillId;
    if (selectedSkillId != null &&
        snapshot.values.any(
          (SkillPracticeTimeValue value) => value.skillId == selectedSkillId,
        )) {
      return selectedSkillId;
    }
    return snapshot.values.first.skillId;
  }
}

class _PracticePortraitView extends StatelessWidget {
  final SkillPracticeTimeSnapshot snapshot;
  final String? selectedSkillId;
  final ValueChanged<String> onSelected;
  final ValueChanged<String>? onOpenSkill;

  const _PracticePortraitView({
    required this.snapshot,
    required this.selectedSkillId,
    required this.onSelected,
    required this.onOpenSkill,
  });

  @override
  Widget build(BuildContext context) {
    final SkillPracticeTimeValue? selectedValue = _selectedValue;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: <Widget>[
        DrumPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const DrumSectionTitle(text: 'Practice Portrait'),
                        const SizedBox(height: 6),
                        Text(
                          'Shows where your recorded practice time has been invested.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: DrumcabularyTheme.edgeTextSecondary,
                                height: 1.35,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _LensPill(text: 'Practice Time'),
                ],
              ),
              const SizedBox(height: 16),
              if (!snapshot.hasSkills)
                const _PracticePortraitEmptyState(
                  title: 'No curriculum skills yet',
                  message:
                      'Add lessons with skill metadata to build a practice portrait.',
                )
              else ...<Widget>[
                if (!snapshot.hasPractice) ...<Widget>[
                  const _PracticePortraitEmptyState(
                    title: 'No practice time recorded',
                    message:
                        'Practice an exercise to begin building your portrait.',
                  ),
                  const SizedBox(height: 16),
                ],
                PracticeRadarChart(
                  values: snapshot.values,
                  selectedSkillId: selectedSkillId,
                  onSkillSelected: onSelected,
                ),
                const SizedBox(height: 16),
                if (selectedValue != null)
                  _SelectedSkillSummary(
                    value: selectedValue,
                    onOpenSkill: onOpenSkill == null
                        ? null
                        : () => onOpenSkill!(selectedValue.skillId),
                  ),
                const SizedBox(height: 16),
                _SkillTimeList(
                  values: snapshot.values,
                  selectedSkillId: selectedSkillId,
                  onSelected: onSelected,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  SkillPracticeTimeValue? get _selectedValue {
    final String? id = selectedSkillId;
    if (id == null) return null;
    for (final SkillPracticeTimeValue value in snapshot.values) {
      if (value.skillId == id) return value;
    }
    return null;
  }
}

class PracticeRadarChart extends StatelessWidget {
  final List<SkillPracticeTimeValue> values;
  final String? selectedSkillId;
  final ValueChanged<String> onSkillSelected;

  const PracticeRadarChart({
    super.key,
    required this.values,
    required this.selectedSkillId,
    required this.onSkillSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 3) {
      return _PracticeRadarFallback(
        values: values,
        selectedSkillId: selectedSkillId,
        onSkillSelected: onSkillSelected,
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 340;
        final double height = width < 420 ? width : 420;
        return Semantics(
          label: 'Practice time distribution by skill',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (TapDownDetails details) {
              final String? skillId = _nearestSkillForTap(
                details.localPosition,
                Size(width, height),
              );
              if (skillId != null) onSkillSelected(skillId);
            },
            child: CustomPaint(
              size: Size(width, height),
              painter: _PracticeRadarPainter(
                values: values,
                selectedSkillId: selectedSkillId,
                textDirection: Directionality.of(context),
              ),
            ),
          ),
        );
      },
    );
  }

  String? _nearestSkillForTap(Offset position, Size size) {
    if (values.isEmpty) return null;
    final Offset center = size.center(Offset.zero);
    final Offset delta = position - center;
    if (delta.distance == 0) return selectedSkillId ?? values.first.skillId;
    double angle = math.atan2(delta.dy, delta.dx) + math.pi / 2;
    while (angle < 0) {
      angle += math.pi * 2;
    }
    final double spoke = (angle / (math.pi * 2)) * values.length;
    final int index = spoke.round() % values.length;
    return values[index].skillId;
  }
}

class _PracticeRadarPainter extends CustomPainter {
  final List<SkillPracticeTimeValue> values;
  final String? selectedSkillId;
  final TextDirection textDirection;

  const _PracticeRadarPainter({
    required this.values,
    required this.selectedSkillId,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final int count = values.length;
    if (count < 3) return;

    final Offset center = size.center(Offset.zero);
    final double radius = math.min(size.width, size.height) * 0.30;
    final Paint gridPaint = Paint()
      ..color = DrumcabularyTheme.edgeBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Paint spokePaint = Paint()
      ..color = DrumcabularyTheme.edgeBorder.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Paint fillPaint = Paint()
      ..color = DrumcabularyTheme.edgeOrange.withValues(alpha: 0.24)
      ..style = PaintingStyle.fill;
    final Paint outlinePaint = Paint()
      ..color = DrumcabularyTheme.edgeOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final Paint pointPaint = Paint()
      ..color = DrumcabularyTheme.edgeOrange
      ..style = PaintingStyle.fill;
    final Paint selectedPointPaint = Paint()
      ..color = const Color(0xFF52D273)
      ..style = PaintingStyle.fill;

    for (int ring = 1; ring <= 4; ring += 1) {
      canvas.drawPath(
        _polygonPath(center, radius * ring / 4, count),
        gridPaint,
      );
    }

    for (int index = 0; index < count; index += 1) {
      final Offset unit = _unitFor(index, count);
      canvas.drawLine(center, center + unit * radius, spokePaint);
    }

    final Path valuePath = Path();
    for (int index = 0; index < count; index += 1) {
      final SkillPracticeTimeValue value = values[index];
      final Offset point =
          center + _unitFor(index, count) * radius * value.normalizedValue;
      if (index == 0) {
        valuePath.moveTo(point.dx, point.dy);
      } else {
        valuePath.lineTo(point.dx, point.dy);
      }
    }
    valuePath.close();
    canvas.drawPath(valuePath, fillPaint);
    canvas.drawPath(valuePath, outlinePaint);

    for (int index = 0; index < count; index += 1) {
      final SkillPracticeTimeValue value = values[index];
      final Offset unit = _unitFor(index, count);
      final Offset point = center + unit * radius * value.normalizedValue;
      canvas.drawCircle(
        point,
        value.skillId == selectedSkillId ? 5 : 4,
        value.skillId == selectedSkillId ? selectedPointPaint : pointPaint,
      );

      final Offset labelCenter = center + unit * (radius + 42);
      _drawLabel(
        canvas,
        labelCenter,
        value,
        selected: value.skillId == selectedSkillId,
      );
    }
  }

  Path _polygonPath(Offset center, double radius, int count) {
    final Path path = Path();
    for (int index = 0; index < count; index += 1) {
      final Offset point = center + _unitFor(index, count) * radius;
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  Offset _unitFor(int index, int count) {
    final double angle = -math.pi / 2 + (math.pi * 2 * index / count);
    return Offset(math.cos(angle), math.sin(angle));
  }

  void _drawLabel(
    Canvas canvas,
    Offset center,
    SkillPracticeTimeValue value, {
    required bool selected,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: value.label,
        style: TextStyle(
          color: selected
              ? DrumcabularyTheme.edgeTextPrimary
              : DrumcabularyTheme.edgeTextSecondary,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          height: 1.15,
        ),
      ),
      maxLines: 2,
      ellipsis: '...',
      textAlign: TextAlign.center,
      textDirection: textDirection,
    )..layout(maxWidth: 92);
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _PracticeRadarPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.selectedSkillId != selectedSkillId ||
        oldDelegate.textDirection != textDirection;
  }
}

class _PracticeRadarFallback extends StatelessWidget {
  final List<SkillPracticeTimeValue> values;
  final String? selectedSkillId;
  final ValueChanged<String> onSkillSelected;

  const _PracticeRadarFallback({
    required this.values,
    required this.selectedSkillId,
    required this.onSkillSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          values.length == 1 ? 'One skill tracked' : 'Two skills tracked',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: DrumcabularyTheme.edgeTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        for (final SkillPracticeTimeValue value in values) ...<Widget>[
          _SkillTimeBar(
            value: value,
            selected: value.skillId == selectedSkillId,
            onTap: () => onSkillSelected(value.skillId),
          ),
          if (value != values.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SkillTimeList extends StatelessWidget {
  final List<SkillPracticeTimeValue> values;
  final String? selectedSkillId;
  final ValueChanged<String> onSelected;

  const _SkillTimeList({
    required this.values,
    required this.selectedSkillId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Time invested',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: DrumcabularyTheme.edgeTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        for (final SkillPracticeTimeValue value in values) ...<Widget>[
          _SkillTimeBar(
            value: value,
            selected: value.skillId == selectedSkillId,
            onTap: () => onSelected(value.skillId),
          ),
          if (value != values.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SkillTimeBar extends StatelessWidget {
  final SkillPracticeTimeValue value;
  final bool selected;
  final VoidCallback onTap;

  const _SkillTimeBar({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? DrumcabularyTheme.edgeOrange.withValues(alpha: 0.10)
                : DrumcabularyTheme.edgeSurfaceSecondary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? DrumcabularyTheme.edgeOrange
                  : DrumcabularyTheme.edgeBorder,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        value.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: DrumcabularyTheme.edgeTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatPracticeTime(value.practicedSeconds),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: DrumcabularyTheme.edgeOrange,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: value.normalizedValue,
                    color: DrumcabularyTheme.edgeOrange,
                    backgroundColor: DrumcabularyTheme.edgeBorder,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedSkillSummary extends StatelessWidget {
  final SkillPracticeTimeValue value;
  final VoidCallback? onOpenSkill;

  const _SelectedSkillSummary({required this.value, required this.onOpenSkill});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DrumcabularyTheme.edgeSurfaceSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DrumcabularyTheme.edgeBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _SelectedMetric(
              label: value.label,
              value: _formatPracticeTime(value.practicedSeconds),
            ),
            _SelectedMetric(
              label: 'Practiced exercises',
              value: '${value.practicedExerciseCount}',
            ),
            _SelectedMetric(
              label: 'Lessons touched',
              value: '${value.practicedLessonCount}',
            ),
            if (onOpenSkill != null)
              OutlinedButton.icon(
                onPressed: onOpenSkill,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('View Lessons'),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectedMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SelectedMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: DrumcabularyTheme.edgeTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: DrumcabularyTheme.edgeTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LensPill extends StatelessWidget {
  final String text;

  const _LensPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DrumcabularyTheme.edgeOrange.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: DrumcabularyTheme.edgeOrange.withValues(alpha: 0.48),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: DrumcabularyTheme.edgeOrange,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PracticePortraitEmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _PracticePortraitEmptyState({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DrumcabularyTheme.edgeSurfaceSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DrumcabularyTheme.edgeBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Icon(Icons.radar_rounded, color: DrumcabularyTheme.edgeOrange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: DrumcabularyTheme.edgeTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: DrumcabularyTheme.edgeTextSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticePortraitError extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _PracticePortraitError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return DrumScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: <Widget>[
          DrumPanel(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const DrumSectionTitle(text: 'Practice Portrait unavailable'),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DrumcabularyTheme.edgeTextSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatPracticeTime(int seconds) {
  if (seconds <= 0) return '0 min';
  final int totalMinutes = (seconds / 60).round();
  if (totalMinutes < 60) return '$totalMinutes min';
  final int hours = totalMinutes ~/ 60;
  final int minutes = totalMinutes.remainder(60);
  if (minutes == 0) return '$hours hr';
  return '$hours hr $minutes min';
}
