import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/drumcabulary_theme.dart';
import '../app/drumcabulary_ui.dart';
import '../coach/lesson_plan_loader.dart';
import '../coach/lesson_progress.dart';
import 'curriculum_progress_lens_aggregator.dart';

const double _radarFullTurn = math.pi * 2;
const double _radarTopAngle = -math.pi / 2;
const Duration _radarRotationDuration = Duration(milliseconds: 320);
const Duration _summaryTransitionDuration = Duration(milliseconds: 220);
const Duration _metricTransitionDuration = Duration(milliseconds: 260);

double radarTargetRotationForIndex(int index, int count) {
  if (count <= 0) return 0;
  return -_radarFullTurn * index / count;
}

double shortestRadarRotationDelta(double current, double target) {
  final double rawDelta = target - current;
  return _normalizeRadarAngle(rawDelta);
}

double _normalizeRadarAngle(double angle) {
  double normalized = angle % _radarFullTurn;
  if (normalized <= -math.pi) normalized += _radarFullTurn;
  if (normalized > math.pi) normalized -= _radarFullTurn;
  return normalized;
}

class PracticeInsightsScreen extends StatefulWidget {
  final ValueChanged<String>? onOpenSkill;
  final Future<CurriculumProgressLensSnapshot> Function(
    PracticeInsightsLens lens,
    List<String> nodePath,
  )?
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
  PracticeInsightsLens _lens = PracticeInsightsLens.practiceTime;
  List<String> _nodePath = const <String>[];
  late Future<CurriculumProgressLensSnapshot> _snapshotFuture = _loadSnapshot(
    _lens,
    _nodePath,
  );
  String? _selectedNodeId;

  Future<CurriculumProgressLensSnapshot> _loadSnapshot(
    PracticeInsightsLens lens,
    List<String> nodePath,
  ) async {
    final Future<CurriculumProgressLensSnapshot> Function(
      PracticeInsightsLens lens,
      List<String> nodePath,
    )?
    loader = widget.snapshotLoader;
    if (loader != null) return loader(lens, nodePath);

    final library = await LessonPlanLoader.loadContent();
    final progressService = LessonProgressService(
      const FileLessonProgressStore(),
    );
    await progressService.load();
    final CurriculumNode root = const CurriculumRadarTreeBuilder().build(
      library,
    );
    return const CurriculumProgressLensAggregator().build(
      lens: lens,
      root: root,
      nodePath: nodePath,
      progressService: progressService,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DrumScreen(
      child: FutureBuilder<CurriculumProgressLensSnapshot>(
        future: _snapshotFuture,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<CurriculumProgressLensSnapshot> snapshot,
            ) {
              if (snapshot.hasError) {
                return _PracticePortraitError(
                  error: snapshot.error,
                  onRetry: () {
                    setState(() {
                      _snapshotFuture = _loadSnapshot(_lens, _nodePath);
                    });
                  },
                );
              }
              final CurriculumProgressLensSnapshot? data = snapshot.data;
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
                onLensChanged: _setLens,
                onOpenSkill: widget.onOpenSkill,
              );
            },
      ),
    );
  }

  void _setLens(PracticeInsightsLens lens) {
    if (lens == _lens) return;
    setState(() {
      _lens = lens;
      _snapshotFuture = _loadSnapshot(lens, _nodePath);
    });
  }

  void _drillIntoNode(String nodeId) {
    if (_nodePath.isNotEmpty) return;
    setState(() {
      _nodePath = <String>[..._nodePath, nodeId];
      _selectedNodeId = null;
      _snapshotFuture = _loadSnapshot(_lens, _nodePath);
    });
  }

  void _openBreadcrumb(int index) {
    final List<String> nextPath = _nodePath.take(index).toList(growable: false);
    setState(() {
      _nodePath = nextPath;
      _selectedNodeId = null;
      _snapshotFuture = _loadSnapshot(_lens, _nodePath);
    });
  }

  String? _resolveSelectedNodeId(CurriculumProgressLensSnapshot snapshot) {
    if (snapshot.values.isEmpty) return null;
    final String? selectedNodeId = _selectedNodeId;
    if (selectedNodeId != null &&
        snapshot.values.any(
          (CurriculumProgressLensValue value) => value.nodeId == selectedNodeId,
        )) {
      return selectedNodeId;
    }
    return snapshot.values.first.nodeId;
  }
}

class _PracticePortraitView extends StatelessWidget {
  final CurriculumProgressLensSnapshot snapshot;
  final String? selectedNodeId;
  final ValueChanged<String> onSelected;
  final ValueChanged<int> onBreadcrumbSelected;
  final ValueChanged<String> onDrillIn;
  final ValueChanged<PracticeInsightsLens> onLensChanged;
  final ValueChanged<String>? onOpenSkill;

  const _PracticePortraitView({
    required this.snapshot,
    required this.selectedNodeId,
    required this.onSelected,
    required this.onBreadcrumbSelected,
    required this.onDrillIn,
    required this.onLensChanged,
    required this.onOpenSkill,
  });

  @override
  Widget build(BuildContext context) {
    final CurriculumProgressLensValue? selectedValue = _selectedValue;
    final _LensCopy copy = _copyFor(snapshot.lens);

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
              _LensHeader(
                copy: copy,
                lens: snapshot.lens,
                onLensChanged: onLensChanged,
              ),
              const SizedBox(height: 16),
              if (!snapshot.hasNodes)
                const _PracticePortraitEmptyState(
                  title: 'No curriculum nodes yet',
                  message:
                      'Add curriculum child nodes to build a radar navigation view.',
                )
              else ...<Widget>[
                if (!snapshot.hasMetricData) ...<Widget>[
                  _PracticePortraitEmptyState(
                    title: copy.emptyTitle,
                    message: copy.emptyMessage,
                  ),
                  const SizedBox(height: 16),
                ],
                PracticeRadarChart(
                  values: snapshot.values,
                  lens: snapshot.lens,
                  semanticLabel: copy.radarSemanticLabel,
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
                        '${snapshot.lens.name}-${selectedValue.nodeId}',
                      ),
                      value: selectedValue,
                      lens: snapshot.lens,
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

  CurriculumProgressLensValue? get _selectedValue {
    final String? id = selectedNodeId;
    if (id == null) return null;
    for (final CurriculumProgressLensValue value in snapshot.values) {
      if (value.nodeId == id) return value;
    }
    return null;
  }

  void _activateNode(String nodeId) {
    final CurriculumProgressLensValue? value = _valueFor(nodeId);
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

  CurriculumProgressLensValue? _valueFor(String nodeId) {
    for (final CurriculumProgressLensValue value in snapshot.values) {
      if (value.nodeId == nodeId) return value;
    }
    return null;
  }
}

class PracticeRadarChart extends StatefulWidget {
  final List<CurriculumProgressLensValue> values;
  final PracticeInsightsLens lens;
  final String semanticLabel;
  final String? selectedNodeId;
  final ValueChanged<String> onNodeSelected;
  final ValueChanged<String>? onNodeActivated;

  const PracticeRadarChart({
    super.key,
    required this.values,
    this.lens = PracticeInsightsLens.practiceTime,
    this.semanticLabel = 'Practice distribution by curriculum node',
    required this.selectedNodeId,
    required this.onNodeSelected,
    this.onNodeActivated,
  });

  @override
  State<PracticeRadarChart> createState() => _PracticeRadarChartState();
}

class _PracticeRadarChartState extends State<PracticeRadarChart>
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
        AnimationController(vsync: this, duration: _radarRotationDuration)
          ..addListener(() {
            final Animation<double>? animation = _rotationAnimation;
            if (animation == null) return;
            setState(() {
              _rotation = animation.value;
            });
          });
  }

  @override
  void didUpdateWidget(covariant PracticeRadarChart oldWidget) {
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
      return _PracticeRadarFallback(
        values: widget.values,
        lens: widget.lens,
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
              painter: _PracticeRadarPainter(
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
      angle += _radarFullTurn;
    }
    final double spoke = (angle / _radarFullTurn) * widget.values.length;
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
      (CurriculumProgressLensValue value) =>
          value.nodeId == widget.selectedNodeId,
    );
    if (selectedIndex < 0) return from;
    final double target = radarTargetRotationForIndex(
      selectedIndex,
      widget.values.length,
    );
    return from + shortestRadarRotationDelta(from, target);
  }

  bool _sameNodeOrder(
    List<CurriculumProgressLensValue> previous,
    List<CurriculumProgressLensValue> next,
  ) {
    if (previous.length != next.length) return false;
    for (int index = 0; index < previous.length; index += 1) {
      if (previous[index].nodeId != next[index].nodeId) return false;
    }
    return true;
  }
}

class _PracticeRadarPainter extends CustomPainter {
  final List<CurriculumProgressLensValue> values;
  final String? selectedNodeId;
  final double rotation;
  final TextDirection textDirection;

  const _PracticeRadarPainter({
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
      final CurriculumProgressLensValue value = values[index];
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
      final CurriculumProgressLensValue value = values[index];
      final bool selected = value.nodeId == selectedNodeId;
      final Offset unit = _unitFor(index, count);
      final Offset point = center + unit * radius * value.normalizedValue;
      canvas.drawCircle(point, 4, pointPaint);

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
        _radarTopAngle + (_radarFullTurn * index / count) + rotation;
    return Offset(math.cos(angle), math.sin(angle));
  }

  void _drawLabel(
    Canvas canvas,
    Size size,
    Offset center,
    CurriculumProgressLensValue value, {
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
  bool shouldRepaint(covariant _PracticeRadarPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.rotation != rotation ||
        oldDelegate.textDirection != textDirection;
  }
}

class _PracticeRadarFallback extends StatelessWidget {
  final List<CurriculumProgressLensValue> values;
  final PracticeInsightsLens lens;
  final String? selectedNodeId;
  final ValueChanged<String> onNodeSelected;
  final ValueChanged<String>? onNodeActivated;

  const _PracticeRadarFallback({
    required this.values,
    required this.lens,
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
        for (final CurriculumProgressLensValue value in values) ...<Widget>[
          _NodeMetricBar(
            value: value,
            lens: lens,
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

class _NodeMetricBar extends StatelessWidget {
  final CurriculumProgressLensValue value;
  final PracticeInsightsLens lens;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  const _NodeMetricBar({
    required this.value,
    required this.lens,
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
                    Text(
                      _metricValueFor(value, lens),
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

class _SelectedNodeSummary extends StatelessWidget {
  final CurriculumProgressLensValue value;
  final PracticeInsightsLens lens;
  final bool canDrillIn;
  final VoidCallback? onDrillIn;
  final VoidCallback? onOpenSkill;

  const _SelectedNodeSummary({
    super.key,
    required this.value,
    required this.lens,
    required this.canDrillIn,
    required this.onDrillIn,
    required this.onOpenSkill,
  });

  @override
  Widget build(BuildContext context) {
    final String? status = _summaryStatusFor(value, lens);
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
                      if (status != null) ...<Widget>[
                        const SizedBox(height: 8),
                        _SummaryStatusPill(text: status),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (canDrillIn && onDrillIn != null)
                  _SummaryActionButton(
                    onPressed: onDrillIn,
                    icon: Icons.radar_rounded,
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
              children: _selectedMetricsFor(value, lens),
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

class _LensHeader extends StatelessWidget {
  final _LensCopy copy;
  final PracticeInsightsLens lens;
  final ValueChanged<PracticeInsightsLens> onLensChanged;

  const _LensHeader({
    required this.copy,
    required this.lens,
    required this.onLensChanged,
  });

  @override
  Widget build(BuildContext context) {
    final Widget text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DrumSectionTitle(text: copy.title),
        const SizedBox(height: 6),
        Text(
          copy.description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: DrumcabularyTheme.edgeTextSecondary,
            height: 1.35,
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final _LensSelector selector = _LensSelector(
          lens: lens,
          onChanged: onLensChanged,
        );
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              text,
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: selector,
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: text),
            const SizedBox(width: 12),
            selector,
          ],
        );
      },
    );
  }
}

class _LensSelector extends StatelessWidget {
  final PracticeInsightsLens lens;
  final ValueChanged<PracticeInsightsLens> onChanged;

  const _LensSelector({required this.lens, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PracticeInsightsLens>(
      showSelectedIcon: false,
      selected: <PracticeInsightsLens>{lens},
      onSelectionChanged: (Set<PracticeInsightsLens> selected) {
        if (selected.isEmpty) return;
        onChanged(selected.first);
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        backgroundColor: WidgetStateProperty.resolveWith((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return DrumcabularyTheme.edgeOrange.withValues(alpha: 0.14);
          }
          return DrumcabularyTheme.edgeSurfaceSecondary;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return DrumcabularyTheme.edgeOrange;
          }
          return DrumcabularyTheme.edgeTextSecondary;
        }),
        side: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return BorderSide(
            color: states.contains(WidgetState.selected)
                ? DrumcabularyTheme.edgeOrange.withValues(alpha: 0.68)
                : DrumcabularyTheme.edgeBorder,
          );
        }),
      ),
      segments: const <ButtonSegment<PracticeInsightsLens>>[
        ButtonSegment<PracticeInsightsLens>(
          value: PracticeInsightsLens.practiceTime,
          label: Text('Practice Time'),
        ),
        ButtonSegment<PracticeInsightsLens>(
          value: PracticeInsightsLens.exercisesCompleted,
          label: Text('Exercises Completed'),
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
  if (seconds < 60) return '< 1 min';
  final int totalMinutes = (seconds / 60).round();
  if (totalMinutes < 60) return '$totalMinutes min';
  final int hours = totalMinutes ~/ 60;
  final int minutes = totalMinutes.remainder(60);
  if (minutes == 0) return '$hours hr';
  return '$hours hr $minutes min';
}

String _metricValueFor(
  CurriculumProgressLensValue value,
  PracticeInsightsLens lens,
) {
  return switch (lens) {
    PracticeInsightsLens.practiceTime => _formatPracticeTime(
      value.practicedSeconds,
    ),
    PracticeInsightsLens.exercisesCompleted =>
      '${value.completedExerciseCount} of ${value.totalExerciseCount}',
  };
}

List<Widget> _selectedMetricsFor(
  CurriculumProgressLensValue value,
  PracticeInsightsLens lens,
) {
  return switch (lens) {
    PracticeInsightsLens.practiceTime => <Widget>[
      _SelectedMetric(
        label: 'Practice time',
        value: value.practicedSeconds.toDouble(),
        formatter: (double seconds) => _formatPracticeTime(seconds.round()),
      ),
      _SelectedMetric(
        label: 'Practiced exercises',
        value: value.practicedExerciseCount.toDouble(),
        formatter: _formatWholeNumber,
      ),
      _SelectedMetric(
        label: 'Lessons touched',
        value: value.practicedLessonCount.toDouble(),
        formatter: _formatWholeNumber,
      ),
    ],
    PracticeInsightsLens.exercisesCompleted => <Widget>[
      _SelectedMetric(
        label: 'Exercises completed',
        value: value.completedExerciseCount.toDouble(),
        formatter: (double completed) =>
            '${completed.round()} of ${value.totalExerciseCount}',
      ),
      _SelectedMetric(
        label: 'Total exercises',
        value: value.totalExerciseCount.toDouble(),
        formatter: _formatWholeNumber,
      ),
      _SelectedMetric(
        label: 'Lessons with completions',
        value: value.completedLessonCount.toDouble(),
        formatter: _formatWholeNumber,
      ),
    ],
  };
}

String _formatWholeNumber(double value) => '${value.round()}';

String? _summaryStatusFor(
  CurriculumProgressLensValue value,
  PracticeInsightsLens lens,
) {
  return switch (lens) {
    PracticeInsightsLens.practiceTime =>
      value.practicedSeconds == 0 ? 'Ready to begin' : null,
    PracticeInsightsLens.exercisesCompleted =>
      value.completedExerciseCount == 0 ? 'No completions yet' : null,
  };
}

_LensCopy _copyFor(PracticeInsightsLens lens) {
  return switch (lens) {
    PracticeInsightsLens.practiceTime => const _LensCopy(
      title: 'Practice Portrait',
      description: 'Shows where your recorded practice time has been invested.',
      emptyTitle: 'No practice time recorded',
      emptyMessage: 'Practice an exercise to begin building your portrait.',
      radarSemanticLabel: 'Practice time distribution by curriculum node',
    ),
    PracticeInsightsLens.exercisesCompleted => const _LensCopy(
      title: 'Completion Portrait',
      description:
          'Shows how completed exercises are distributed across the curriculum.',
      emptyTitle: 'No completed exercises yet',
      emptyMessage:
          'Complete an exercise to begin building your completion portrait.',
      radarSemanticLabel: 'Exercise completion distribution by curriculum node',
    ),
  };
}

class _LensCopy {
  final String title;
  final String description;
  final String emptyTitle;
  final String emptyMessage;
  final String radarSemanticLabel;

  const _LensCopy({
    required this.title,
    required this.description,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.radarSemanticLabel,
  });
}
