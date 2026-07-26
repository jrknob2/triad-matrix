import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/drumcabulary_theme.dart';
import '../app/drumcabulary_ui.dart';
import '../coach/lesson_plan_loader.dart';
import '../coach/lesson_progress.dart';
import 'curriculum_compass_aggregator.dart';

const double _compassFullTurn = math.pi * 2;
const double _compassTopAngle = -math.pi / 2;
const Duration _compassRotationDuration = Duration(milliseconds: 320);
const Duration _summaryTransitionDuration = Duration(milliseconds: 220);
const Duration _metricTransitionDuration = Duration(milliseconds: 260);

double curriculumCompassTargetRotationForIndex(int index, int count) {
  if (count <= 0) return 0;
  return -_compassFullTurn * index / count;
}

double shortestCompassRotationDelta(double current, double target) {
  final double rawDelta = target - current;
  return _normalizeCompassAngle(rawDelta);
}

double _normalizeCompassAngle(double angle) {
  double normalized = angle % _compassFullTurn;
  if (normalized <= -math.pi) normalized += _compassFullTurn;
  if (normalized > math.pi) normalized -= _compassFullTurn;
  return normalized;
}

class PracticeInsightsScreen extends StatefulWidget {
  final ValueChanged<String>? onOpenSkill;
  final Future<CurriculumCompassSnapshot> Function(List<String> nodePath)?
  snapshotLoader;

  const PracticeInsightsScreen({
    super.key,
    this.onOpenSkill,
    this.snapshotLoader,
  });

  @override
  State<PracticeInsightsScreen> createState() => _PracticeInsightsScreenState();
}

class _PracticeInsightsScreenState extends State<PracticeInsightsScreen> {
  List<String> _nodePath = const <String>[];
  late Future<CurriculumCompassSnapshot> _snapshotFuture = _loadSnapshot(
    _nodePath,
  );
  String? _selectedNodeId;

  Future<CurriculumCompassSnapshot> _loadSnapshot(List<String> nodePath) async {
    final Future<CurriculumCompassSnapshot> Function(List<String> nodePath)?
    loader = widget.snapshotLoader;
    if (loader != null) return loader(nodePath);

    final library = await LessonPlanLoader.loadContent();
    final progressService = LessonProgressService(
      const FileLessonProgressStore(),
    );
    await progressService.load();
    final CurriculumNode root = const CurriculumCompassTreeBuilder().build(
      library,
    );
    return const CurriculumCompassAggregator().build(
      root: root,
      nodePath: nodePath,
      progressService: progressService,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DrumScreen(
      child: FutureBuilder<CurriculumCompassSnapshot>(
        future: _snapshotFuture,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<CurriculumCompassSnapshot> snapshot,
            ) {
              if (snapshot.hasError) {
                return _PracticePortraitError(
                  error: snapshot.error,
                  onRetry: () {
                    setState(() {
                      _snapshotFuture = _loadSnapshot(_nodePath);
                    });
                  },
                );
              }
              final CurriculumCompassSnapshot? data = snapshot.data;
              if (data == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return _PracticePortraitView(
                snapshot: data,
                selectedNodeId: _resolveSelectedNodeId(data),
                onSelected: (String nodeId) {
                  setState(() => _selectedNodeId = nodeId);
                },
                onBreadcrumbSelected: _openBreadcrumb,
                onDrillIn: _drillIntoNode,
                onOpenSkill: widget.onOpenSkill,
              );
            },
      ),
    );
  }

  void _drillIntoNode(String nodeId) {
    if (_nodePath.isNotEmpty) return;
    setState(() {
      _nodePath = <String>[..._nodePath, nodeId];
      _selectedNodeId = null;
      _snapshotFuture = _loadSnapshot(_nodePath);
    });
  }

  void _openBreadcrumb(int index) {
    final List<String> nextPath = _nodePath.take(index).toList(growable: false);
    setState(() {
      _nodePath = nextPath;
      _selectedNodeId = null;
      _snapshotFuture = _loadSnapshot(_nodePath);
    });
  }

  String? _resolveSelectedNodeId(CurriculumCompassSnapshot snapshot) {
    if (snapshot.values.isEmpty) return null;
    final String? selectedNodeId = _selectedNodeId;
    if (selectedNodeId != null &&
        snapshot.values.any(
          (CurriculumCompassPoint value) => value.nodeId == selectedNodeId,
        )) {
      return selectedNodeId;
    }
    return snapshot.values.first.nodeId;
  }
}

class _PracticePortraitView extends StatelessWidget {
  final CurriculumCompassSnapshot snapshot;
  final String? selectedNodeId;
  final ValueChanged<String> onSelected;
  final ValueChanged<int> onBreadcrumbSelected;
  final ValueChanged<String> onDrillIn;
  final ValueChanged<String>? onOpenSkill;

  const _PracticePortraitView({
    required this.snapshot,
    required this.selectedNodeId,
    required this.onSelected,
    required this.onBreadcrumbSelected,
    required this.onDrillIn,
    required this.onOpenSkill,
  });

  @override
  Widget build(BuildContext context) {
    final CurriculumCompassPoint? selectedValue = _selectedValue;

    return ListView(
      key: ValueKey<String>('practice-insights-${snapshot.currentNode.id}'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: <Widget>[
        DrumPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _CurriculumBreadcrumbs(
                breadcrumbs: snapshot.breadcrumbs,
                onSelected: onBreadcrumbSelected,
              ),
              const SizedBox(height: 12),
              const _CompassHeader(),
              const SizedBox(height: 16),
              if (!snapshot.hasNodes)
                const _PracticePortraitEmptyState(
                  title: 'No curriculum nodes yet',
                  message: 'Add curriculum child nodes to build the compass.',
                )
              else ...<Widget>[
                if (!snapshot.hasMetricData) ...<Widget>[
                  const _PracticePortraitEmptyState(
                    title: 'No practice recorded yet',
                    message:
                        'The compass is ready. Practice or complete an exercise to fill it in.',
                  ),
                  const SizedBox(height: 16),
                ],
                CurriculumCompassChart(
                  values: snapshot.values,
                  semanticLabel: _compassSemanticLabel(snapshot.values),
                  selectedNodeId: selectedNodeId,
                  onNodeSelected: onSelected,
                  onNodeActivated: _activateNode,
                ),
                const SizedBox(height: 16),
                if (selectedValue != null)
                  AnimatedSwitcher(
                    duration: _summaryTransitionDuration,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          final Animation<Offset> offset = Tween<Offset>(
                            begin: const Offset(0, 0.02),
                            end: Offset.zero,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: offset,
                              child: child,
                            ),
                          );
                        },
                    child: _SelectedNodeSummary(
                      key: ValueKey<String>(
                        'compass-summary-${selectedValue.nodeId}',
                      ),
                      value: selectedValue,
                      canDrillIn: snapshot.isRoot && selectedValue.hasChildren,
                      onDrillIn: snapshot.isRoot && selectedValue.hasChildren
                          ? () => onDrillIn(selectedValue.nodeId)
                          : null,
                      onOpenSkill: onOpenSkill == null
                          ? null
                          : snapshot.isRoot
                          ? null
                          : () => onOpenSkill!(selectedValue.lessonFilterId),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  CurriculumCompassPoint? get _selectedValue {
    final String? id = selectedNodeId;
    if (id == null) return null;
    for (final CurriculumCompassPoint value in snapshot.values) {
      if (value.nodeId == id) return value;
    }
    return null;
  }

  void _activateNode(String nodeId) {
    final CurriculumCompassPoint? value = _valueFor(nodeId);
    if (value == null) return;
    if (snapshot.isRoot && value.hasChildren) {
      onDrillIn(value.nodeId);
      return;
    }
    final ValueChanged<String>? openSkill = onOpenSkill;
    if (!snapshot.isRoot && openSkill != null) {
      openSkill(value.lessonFilterId);
    }
  }

  CurriculumCompassPoint? _valueFor(String nodeId) {
    for (final CurriculumCompassPoint value in snapshot.values) {
      if (value.nodeId == nodeId) return value;
    }
    return null;
  }
}

class CurriculumCompassChart extends StatefulWidget {
  final List<CurriculumCompassPoint> values;
  final String semanticLabel;
  final String? selectedNodeId;
  final ValueChanged<String> onNodeSelected;
  final ValueChanged<String>? onNodeActivated;

  const CurriculumCompassChart({
    super.key,
    required this.values,
    this.semanticLabel = 'Curriculum Compass',
    required this.selectedNodeId,
    required this.onNodeSelected,
    this.onNodeActivated,
  });

  @override
  State<CurriculumCompassChart> createState() => _CurriculumCompassChartState();
}

class _CurriculumCompassChartState extends State<CurriculumCompassChart>
    with SingleTickerProviderStateMixin {
  static const Duration _doubleClickWindow = Duration(milliseconds: 360);

  late final AnimationController _rotationController;
  Animation<double>? _rotationAnimation;
  double _rotation = 0;
  Timer? _pendingRotationTimer;
  bool _deferNextSelectionRotation = false;
  String? _lastPointerNodeId;
  Duration? _lastPointerTime;

  @override
  void initState() {
    super.initState();
    _rotation = _rotationForSelected(from: 0);
    _rotationController =
        AnimationController(vsync: this, duration: _compassRotationDuration)
          ..addListener(() {
            final Animation<double>? animation = _rotationAnimation;
            if (animation == null) return;
            setState(() {
              _rotation = animation.value;
            });
          });
  }

  @override
  void didUpdateWidget(covariant CurriculumCompassChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool selectionChanged =
        oldWidget.selectedNodeId != widget.selectedNodeId;
    final bool nodeOrderChanged =
        oldWidget.values.length != widget.values.length ||
        !_sameNodeOrder(oldWidget.values, widget.values);
    if (selectionChanged || nodeOrderChanged) {
      if (_deferNextSelectionRotation &&
          selectionChanged &&
          !nodeOrderChanged) {
        _deferNextSelectionRotation = false;
        _scheduleRotationAfterDoubleClickWindow();
        return;
      }
      _cancelPendingRotation();
      _animateRotationToSelection();
    }
  }

  @override
  void dispose() {
    _cancelPendingRotation();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.values.length < 3) {
      return _CurriculumCompassFallback(
        values: widget.values,
        selectedNodeId: widget.selectedNodeId,
        onNodeSelected: widget.onNodeSelected,
        onNodeActivated: widget.onNodeActivated,
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 340;
        final double height = width < 420 ? width : 420;
        return Semantics(
          label: widget.semanticLabel,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (PointerDownEvent event) {
              _handlePointerDown(event, Size(width, height));
            },
            child: CustomPaint(
              size: Size(width, height),
              painter: _CurriculumCompassPainter(
                values: widget.values,
                selectedNodeId: widget.selectedNodeId,
                rotation: _rotation,
                textDirection: Directionality.of(context),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handlePointerDown(PointerDownEvent event, Size size) {
    final String? nodeId = _nearestNodeForTap(event.localPosition, size);
    if (nodeId == null) return;

    final Duration? lastTime = _lastPointerTime;
    final bool isDoubleClick =
        _lastPointerNodeId == nodeId &&
        lastTime != null &&
        event.timeStamp - lastTime <= _doubleClickWindow;
    if (isDoubleClick) {
      _cancelPendingRotation();
      _lastPointerNodeId = null;
      _lastPointerTime = null;
      widget.onNodeActivated?.call(nodeId);
      return;
    }

    _cancelPendingRotation();
    _deferNextSelectionRotation = true;
    _lastPointerNodeId = nodeId;
    _lastPointerTime = event.timeStamp;
    widget.onNodeSelected(nodeId);
  }

  String? _nearestNodeForTap(Offset position, Size size) {
    if (widget.values.isEmpty) return null;
    final Offset center = size.center(Offset.zero);
    final Offset delta = position - center;
    if (delta.distance == 0) {
      return widget.selectedNodeId ?? widget.values.first.nodeId;
    }
    double angle = math.atan2(delta.dy, delta.dx) + math.pi / 2 - _rotation;
    while (angle < 0) {
      angle += _compassFullTurn;
    }
    final double spoke = (angle / _compassFullTurn) * widget.values.length;
    final int index = spoke.round() % widget.values.length;
    return widget.values[index].nodeId;
  }

  void _animateRotationToSelection() {
    final double target = _rotationForSelected(from: _rotation);
    if ((target - _rotation).abs() < 0.0001) return;
    final bool disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      _rotationController.stop();
      setState(() => _rotation = target);
      return;
    }
    _rotationAnimation = Tween<double>(begin: _rotation, end: target).animate(
      CurvedAnimation(
        parent: _rotationController,
        curve: Curves.easeInOutCubic,
      ),
    );
    _rotationController.forward(from: 0);
  }

  void _scheduleRotationAfterDoubleClickWindow() {
    _cancelPendingRotation();
    _pendingRotationTimer = Timer(_doubleClickWindow, () {
      _pendingRotationTimer = null;
      if (!mounted) return;
      _animateRotationToSelection();
    });
  }

  void _cancelPendingRotation() {
    _pendingRotationTimer?.cancel();
    _pendingRotationTimer = null;
  }

  double _rotationForSelected({required double from}) {
    final int selectedIndex = widget.values.indexWhere(
      (CurriculumCompassPoint value) => value.nodeId == widget.selectedNodeId,
    );
    if (selectedIndex < 0) return from;
    final double target = curriculumCompassTargetRotationForIndex(
      selectedIndex,
      widget.values.length,
    );
    return from + shortestCompassRotationDelta(from, target);
  }

  bool _sameNodeOrder(
    List<CurriculumCompassPoint> previous,
    List<CurriculumCompassPoint> next,
  ) {
    if (previous.length != next.length) return false;
    for (int index = 0; index < previous.length; index += 1) {
      if (previous[index].nodeId != next[index].nodeId) return false;
    }
    return true;
  }
}

class _CurriculumCompassPainter extends CustomPainter {
  final List<CurriculumCompassPoint> values;
  final String? selectedNodeId;
  final double rotation;
  final TextDirection textDirection;

  const _CurriculumCompassPainter({
    required this.values,
    required this.selectedNodeId,
    required this.rotation,
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
    final Paint trackPaint = Paint()
      ..color = DrumcabularyTheme.edgeBorder.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;
    final Paint practicePaint = Paint()
      ..color = DrumcabularyTheme.edgeOrange
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5;
    final Paint completionPaint = Paint()
      ..color = const Color(0xFF52D273)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    final Paint practiceMarkerPaint = Paint()
      ..color = DrumcabularyTheme.edgeOrange
      ..style = PaintingStyle.fill;
    final Paint completionMarkerPaint = Paint()
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

    for (int index = 0; index < count; index += 1) {
      final CurriculumCompassPoint value = values[index];
      final bool selected = value.nodeId == selectedNodeId;
      final Offset unit = _unitFor(index, count);
      final Offset perpendicular = Offset(-unit.dy, unit.dx);
      final Offset practiceStart = center + perpendicular * -4;
      final Offset practiceEnd = center + unit * radius + perpendicular * -4;
      final Offset completionStart = center + perpendicular * 4;
      final Offset completionEnd = center + unit * radius + perpendicular * 4;
      canvas.drawLine(practiceStart, practiceEnd, trackPaint);
      canvas.drawLine(completionStart, completionEnd, trackPaint);

      final Offset practicePoint =
          practiceStart +
          unit * radius * value.practiceInvestmentRatio.clamp(0, 1);
      final Offset completionPoint =
          completionStart + unit * radius * value.completionRatio.clamp(0, 1);
      canvas.drawLine(practiceStart, practicePoint, practicePaint);
      canvas.drawLine(completionStart, completionPoint, completionPaint);
      canvas.drawCircle(practicePoint, 3.5, practiceMarkerPaint);
      canvas.drawCircle(completionPoint, 3, completionMarkerPaint);

      final Offset labelCenter = center + unit * (radius + 42);
      _drawLabel(canvas, size, labelCenter, value, selected: selected);
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
    final double angle =
        _compassTopAngle + (_compassFullTurn * index / count) + rotation;
    return Offset(math.cos(angle), math.sin(angle));
  }

  void _drawLabel(
    Canvas canvas,
    Size size,
    Offset center,
    CurriculumCompassPoint value, {
    required bool selected,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: value.label,
        style: TextStyle(
          color: selected
              ? DrumcabularyTheme.edgeOrange
              : DrumcabularyTheme.edgeTextSecondary,
          fontSize: selected ? 13 : 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          height: 1.15,
        ),
      ),
      maxLines: 2,
      ellipsis: '...',
      textAlign: TextAlign.center,
      textDirection: textDirection,
    )..layout(maxWidth: selected ? 104 : 92);
    final double left = (center.dx - painter.width / 2).clamp(
      0,
      math.max(0, size.width - painter.width),
    );
    final double top = (center.dy - painter.height / 2).clamp(
      0,
      math.max(0, size.height - painter.height),
    );
    painter.paint(canvas, Offset(left, top));
  }

  @override
  bool shouldRepaint(covariant _CurriculumCompassPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.rotation != rotation ||
        oldDelegate.textDirection != textDirection;
  }
}

class _CurriculumCompassFallback extends StatelessWidget {
  final List<CurriculumCompassPoint> values;
  final String? selectedNodeId;
  final ValueChanged<String> onNodeSelected;
  final ValueChanged<String>? onNodeActivated;

  const _CurriculumCompassFallback({
    required this.values,
    required this.selectedNodeId,
    required this.onNodeSelected,
    required this.onNodeActivated,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          values.length == 1 ? 'One node tracked' : 'Two nodes tracked',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: DrumcabularyTheme.edgeTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        for (final CurriculumCompassPoint value in values) ...<Widget>[
          _CompassMetricBars(
            value: value,
            selected: value.nodeId == selectedNodeId,
            onTap: () => onNodeSelected(value.nodeId),
            onDoubleTap: onNodeActivated == null
                ? null
                : () => onNodeActivated!(value.nodeId),
          ),
          if (value != values.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _CompassMetricBars extends StatelessWidget {
  final CurriculumCompassPoint value;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  const _CompassMetricBars({
    required this.value,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          _formatPracticeTime(value.practicedSeconds),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: DrumcabularyTheme.edgeOrange,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _completionTextFor(value),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: const Color(0xFF52D273),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _CompactMetricBar(
                  label: 'Practice Investment',
                  value: value.practiceInvestmentRatio,
                  color: DrumcabularyTheme.edgeOrange,
                ),
                const SizedBox(height: 6),
                _CompactMetricBar(
                  label: 'Curriculum Completion',
                  value: value.completionRatio,
                  color: const Color(0xFF52D273),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactMetricBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _CompactMetricBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 138,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: DrumcabularyTheme.edgeTextMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: value.clamp(0, 1),
              color: color,
              backgroundColor: DrumcabularyTheme.edgeBorder,
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedNodeSummary extends StatelessWidget {
  final CurriculumCompassPoint value;
  final bool canDrillIn;
  final VoidCallback? onDrillIn;
  final VoidCallback? onOpenSkill;

  const _SelectedNodeSummary({
    super.key,
    required this.value,
    required this.canDrillIn,
    required this.onDrillIn,
    required this.onOpenSkill,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> statuses = _summaryStatusesFor(value);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DrumcabularyTheme.edgeSurfaceSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DrumcabularyTheme.edgeBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                      Text(
                        value.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: DrumcabularyTheme.edgeTextPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (value.shortDescription != null) ...<Widget>[
                        const SizedBox(height: 5),
                        Text(
                          value.shortDescription!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: DrumcabularyTheme.edgeTextSecondary,
                                height: 1.3,
                              ),
                        ),
                      ],
                      if (statuses.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: <Widget>[
                            for (final String status in statuses)
                              _SummaryStatusPill(text: status),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (canDrillIn && onDrillIn != null)
                  _SummaryActionButton(
                    onPressed: onDrillIn,
                    icon: Icons.explore_rounded,
                    label: 'Explore ${value.label}',
                  ),
                if (onOpenSkill != null)
                  _SummaryActionButton(
                    onPressed: onOpenSkill,
                    icon: Icons.arrow_forward_rounded,
                    label: 'View Lessons',
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: _selectedMetricsFor(value),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  const _SummaryActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _SummaryStatusPill extends StatelessWidget {
  final String text;

  const _SummaryStatusPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DrumcabularyTheme.edgeOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: DrumcabularyTheme.edgeOrange.withValues(alpha: 0.38),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: DrumcabularyTheme.edgeOrange,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CurriculumBreadcrumbs extends StatelessWidget {
  final List<CurriculumBreadcrumb> breadcrumbs;
  final ValueChanged<int> onSelected;

  const _CurriculumBreadcrumbs({
    required this.breadcrumbs,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (breadcrumbs.isEmpty) return const SizedBox.shrink();
    final TextStyle? baseStyle = Theme.of(context).textTheme.labelLarge
        ?.copyWith(
          color: DrumcabularyTheme.edgeTextSecondary,
          fontWeight: FontWeight.w600,
        );
    final TextStyle? currentStyle = baseStyle?.copyWith(
      color: DrumcabularyTheme.edgeTextPrimary,
    );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (int index = 0; index < breadcrumbs.length; index += 1) ...<Widget>[
          if (index > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: DrumcabularyTheme.edgeTextMuted,
              ),
            ),
          if (index == breadcrumbs.length - 1)
            Text(breadcrumbs[index].title, style: currentStyle)
          else
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => onSelected(index),
              child: Text(breadcrumbs[index].title, style: baseStyle),
            ),
        ],
      ],
    );
  }
}

class _SelectedMetric extends StatelessWidget {
  final String label;
  final double value;
  final String Function(double value) formatter;

  const _SelectedMetric({
    required this.label,
    required this.value,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
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
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: value),
            duration: disableAnimations
                ? Duration.zero
                : _metricTransitionDuration,
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double animatedValue, Widget? _) {
              return Text(
                formatter(animatedValue),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: DrumcabularyTheme.edgeTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
            onEnd: () {},
          ),
        ],
      ),
    );
  }
}

class _CompassHeader extends StatelessWidget {
  const _CompassHeader();

  @override
  Widget build(BuildContext context) {
    final Widget text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const DrumSectionTitle(text: 'Curriculum Compass'),
        const SizedBox(height: 6),
        Text(
          'Maps where practice time is invested and how much curriculum work is complete.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: DrumcabularyTheme.edgeTextSecondary,
            height: 1.35,
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              text,
              const SizedBox(height: 12),
              const _CompassLegend(),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: text),
            const SizedBox(width: 12),
            const _CompassLegend(),
          ],
        );
      },
    );
  }
}

class _CompassLegend extends StatelessWidget {
  const _CompassLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _LegendItem(
          label: 'Practice Investment',
          color: DrumcabularyTheme.edgeOrange,
          strokeWidth: 5,
        ),
        const _LegendItem(
          label: 'Curriculum Completion',
          color: Color(0xFF52D273),
          strokeWidth: 3,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final double strokeWidth;

  const _LegendItem({
    required this.label,
    required this.color,
    required this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 26,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
              child: SizedBox(width: 24, height: strokeWidth),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: DrumcabularyTheme.edgeTextSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
            Icon(Icons.explore_rounded, color: DrumcabularyTheme.edgeOrange),
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
  if (seconds < 60) return '< 1 min';
  final int totalMinutes = (seconds / 60).round();
  if (totalMinutes < 60) return '$totalMinutes min';
  final int hours = totalMinutes ~/ 60;
  final int minutes = totalMinutes.remainder(60);
  if (minutes == 0) return '$hours hr';
  return '$hours hr $minutes min';
}

String _completionTextFor(CurriculumCompassPoint value) {
  if (value.totalExerciseCount == 0) return 'No exercises yet';
  return '${value.completedExerciseCount} of ${value.totalExerciseCount}';
}

List<Widget> _selectedMetricsFor(CurriculumCompassPoint value) {
  return <Widget>[
    _SelectedMetric(
      label: 'Practiced',
      value: value.practicedSeconds.toDouble(),
      formatter: (double seconds) => _formatPracticeTime(seconds.round()),
    ),
    _SelectedMetric(
      label: 'Exercises completed',
      value: value.completedExerciseCount.toDouble(),
      formatter: (double completed) => value.totalExerciseCount == 0
          ? 'No exercises yet'
          : '${completed.round()} of ${value.totalExerciseCount}',
    ),
    _SelectedMetric(
      label: 'Lessons touched',
      value: value.practicedLessonCount.toDouble(),
      formatter: _formatWholeNumber,
    ),
  ];
}

String _formatWholeNumber(double value) => '${value.round()}';

List<String> _summaryStatusesFor(CurriculumCompassPoint value) {
  if (value.totalExerciseCount == 0) return <String>['No exercises yet'];
  return <String>[
    if (value.practicedSeconds == 0) 'Not practiced yet',
    if (value.completedExerciseCount == 0) 'No completions yet',
  ];
}

String _compassSemanticLabel(List<CurriculumCompassPoint> values) {
  final StringBuffer buffer = StringBuffer('Curriculum Compass.');
  for (final CurriculumCompassPoint value in values) {
    buffer.write(' ${value.label}. ');
    buffer.write('${_formatPracticeTime(value.practicedSeconds)} practiced. ');
    if (value.totalExerciseCount == 0) {
      buffer.write('No exercises yet.');
    } else {
      buffer.write(
        '${value.completedExerciseCount} of ${value.totalExerciseCount} exercises completed.',
      );
    }
  }
  return buffer.toString();
}
