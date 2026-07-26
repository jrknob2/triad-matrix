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
const double curriculumCompassInnerZeroRadiusFactor = 0.26;
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

double curriculumCompassDisplayRadiusForProgress({
  required double outerRadius,
  required double progressRatio,
}) {
  final double innerRadius =
      outerRadius * curriculumCompassInnerZeroRadiusFactor;
  return innerRadius + progressRatio.clamp(0, 1) * (outerRadius - innerRadius);
}

class PracticeInsightsScreen extends StatefulWidget {
  final ValueChanged<String>? onOpenSkill;
  final ValueChanged<String>? onOpenLesson;
  final CompassExerciseCallback? onOpenExercise;
  final Future<CurriculumCompassSnapshot> Function(
    List<String> nodePath,
    int pageIndex,
  )?
  snapshotLoader;

  const PracticeInsightsScreen({
    super.key,
    this.onOpenSkill,
    this.onOpenLesson,
    this.onOpenExercise,
    this.snapshotLoader,
  });

  @override
  State<PracticeInsightsScreen> createState() => _PracticeInsightsScreenState();
}

class _PracticeInsightsScreenState extends State<PracticeInsightsScreen> {
  List<String> _nodePath = const <String>[];
  int _pageIndex = 0;
  late Future<CurriculumCompassSnapshot> _snapshotFuture = _loadSnapshot(
    _nodePath,
    _pageIndex,
  );
  String? _selectedNodeId;

  Future<CurriculumCompassSnapshot> _loadSnapshot(
    List<String> nodePath,
    int pageIndex,
  ) async {
    final Future<CurriculumCompassSnapshot> Function(
      List<String> nodePath,
      int pageIndex,
    )?
    loader = widget.snapshotLoader;
    if (loader != null) return loader(nodePath, pageIndex);

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
      pageIndex: pageIndex,
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
                      _snapshotFuture = _loadSnapshot(_nodePath, _pageIndex);
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
                onPageSelected: _openPage,
                onOpenSkill: widget.onOpenSkill,
                onOpenLesson: widget.onOpenLesson,
                onOpenExercise: widget.onOpenExercise,
              );
            },
      ),
    );
  }

  void _drillIntoNode(String nodeId) {
    setState(() {
      _nodePath = <String>[..._nodePath, nodeId];
      _pageIndex = 0;
      _selectedNodeId = null;
      _snapshotFuture = _loadSnapshot(_nodePath, _pageIndex);
    });
  }

  void _openBreadcrumb(int index) {
    final List<String> nextPath = _nodePath.take(index).toList(growable: false);
    setState(() {
      _nodePath = nextPath;
      _pageIndex = 0;
      _selectedNodeId = null;
      _snapshotFuture = _loadSnapshot(_nodePath, _pageIndex);
    });
  }

  void _openPage(int pageIndex) {
    setState(() {
      _pageIndex = pageIndex;
      _selectedNodeId = null;
      _snapshotFuture = _loadSnapshot(_nodePath, _pageIndex);
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
  final ValueChanged<int> onPageSelected;
  final ValueChanged<String>? onOpenSkill;
  final ValueChanged<String>? onOpenLesson;
  final CompassExerciseCallback? onOpenExercise;

  const _PracticePortraitView({
    required this.snapshot,
    required this.selectedNodeId,
    required this.onSelected,
    required this.onBreadcrumbSelected,
    required this.onDrillIn,
    required this.onPageSelected,
    required this.onOpenSkill,
    required this.onOpenLesson,
    required this.onOpenExercise,
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
                _PracticePortraitEmptyState(
                  title: _emptyStateTitle(snapshot),
                  message: _emptyStateMessage(snapshot),
                  actionLabel: _emptyStateActionLabel(snapshot),
                  onAction: _emptyStateAction,
                )
              else ...<Widget>[
                if (!snapshot.hasMetricData) ...<Widget>[
                  const _PracticePortraitEmptyState(
                    title: 'No practice recorded yet',
                    message:
                        'The compass is ready. Complete an exercise to move progress outward.',
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
                if (snapshot.pageCount > 1) ...<Widget>[
                  const SizedBox(height: 12),
                  _CompassPaginationControls(
                    pageIndex: snapshot.pageIndex,
                    pageCount: snapshot.pageCount,
                    onPrevious: snapshot.hasPreviousPage
                        ? () => onPageSelected(snapshot.pageIndex - 1)
                        : null,
                    onNext: snapshot.hasNextPage
                        ? () => onPageSelected(snapshot.pageIndex + 1)
                        : null,
                  ),
                ],
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
                      onDrillIn: selectedValue.hasChildren
                          ? () => onDrillIn(selectedValue.nodeId)
                          : null,
                      onOpenSkill: _openSkillActionFor(selectedValue),
                      onOpenExercise: _openExerciseActionFor(selectedValue),
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
    if (value.hasChildren) {
      onDrillIn(value.nodeId);
      return;
    }
    final VoidCallback? action =
        _openExerciseActionFor(value) ?? _openSkillActionFor(value);
    action?.call();
  }

  VoidCallback? _openSkillActionFor(CurriculumCompassPoint value) {
    final ValueChanged<String>? openSkill = onOpenSkill;
    if (openSkill == null) return null;
    if (value.kind == CompassNodeKind.lesson ||
        value.kind == CompassNodeKind.exercise) {
      return null;
    }
    if (value.hasChildren) return null;
    return () => openSkill(value.lessonFilterId);
  }

  VoidCallback? _openExerciseActionFor(CurriculumCompassPoint value) {
    final CompassExerciseCallback? openExercise = onOpenExercise;
    if (openExercise == null || value.kind != CompassNodeKind.exercise) {
      return null;
    }
    final String? lessonId = value.lessonId;
    final String? exerciseId = value.exerciseId;
    if (lessonId == null || exerciseId == null) return null;
    return () => openExercise(lessonId, exerciseId);
  }

  VoidCallback? get _emptyStateAction {
    final ValueChanged<String>? openSkill = onOpenSkill;
    if (openSkill != null && snapshot.childKind == CompassNodeKind.lesson) {
      return () => openSkill(snapshot.currentNode.lessonFilterId);
    }
    final ValueChanged<String>? openLesson = onOpenLesson;
    final String? lessonId = snapshot.currentNode.lesson?.id;
    if (openLesson != null &&
        lessonId != null &&
        snapshot.childKind == CompassNodeKind.exercise) {
      return () => openLesson(lessonId);
    }
    return null;
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
    if (count == 0) return;

    final Offset center = size.center(Offset.zero);
    final double radius = math.min(size.width, size.height) * 0.30;
    final double innerRadius = radius * curriculumCompassInnerZeroRadiusFactor;
    final Paint gridPaint = Paint()
      ..color = DrumcabularyTheme.edgeBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Paint spokePaint = Paint()
      ..color = DrumcabularyTheme.edgeBorder.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Paint polygonFillPaint = Paint()
      ..color = DrumcabularyTheme.edgeOrange.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final Paint polygonStrokePaint = Paint()
      ..color = DrumcabularyTheme.edgeOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    final Paint innerRingPaint = Paint()
      ..color = DrumcabularyTheme.edgeBorder.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    for (int ring = 0; ring <= 4; ring += 1) {
      final double ringRadius = innerRadius + (radius - innerRadius) * ring / 4;
      if (count < 3) {
        canvas.drawCircle(
          center,
          ringRadius,
          ring == 0 ? innerRingPaint : gridPaint,
        );
      } else {
        canvas.drawPath(
          _polygonPath(center, ringRadius, count),
          ring == 0 ? innerRingPaint : gridPaint,
        );
      }
    }

    for (int index = 0; index < count; index += 1) {
      final Offset unit = _unitFor(index, count);
      canvas.drawLine(
        center + unit * innerRadius,
        center + unit * radius,
        spokePaint,
      );
    }

    final Path progressPath = Path();
    final List<Offset> progressPoints = <Offset>[];
    for (int index = 0; index < count; index += 1) {
      final CurriculumCompassPoint value = values[index];
      final bool selected = value.nodeId == selectedNodeId;
      final Offset unit = _unitFor(index, count);
      final double displayRadius = curriculumCompassDisplayRadiusForProgress(
        outerRadius: radius,
        progressRatio: value.progressRatio,
      );
      final Offset point = center + unit * displayRadius;
      progressPoints.add(point);
      if (index == 0) {
        progressPath.moveTo(point.dx, point.dy);
      } else {
        progressPath.lineTo(point.dx, point.dy);
      }

      final Offset labelCenter = center + unit * (radius + 42);
      _drawLabel(canvas, size, labelCenter, value, selected: selected);
    }

    if (count == 1) {
      final Offset unit = _unitFor(0, count);
      canvas.drawLine(
        center + unit * innerRadius,
        progressPoints.single,
        polygonStrokePaint,
      );
      canvas.drawCircle(progressPoints.single, 5, polygonFillPaint);
      canvas.drawCircle(progressPoints.single, 5, polygonStrokePaint);
    } else if (count == 2) {
      canvas.drawLine(
        progressPoints.first,
        progressPoints.last,
        polygonStrokePaint,
      );
      for (final Offset point in progressPoints) {
        canvas.drawCircle(point, 4.5, polygonFillPaint);
        canvas.drawCircle(point, 4.5, polygonStrokePaint);
      }
    } else {
      progressPath.close();
      canvas.drawPath(progressPath, polygonFillPaint);
      canvas.drawPath(progressPath, polygonStrokePaint);
    }

    _drawCenterHub(canvas, center);
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

  void _drawCenterHub(Canvas canvas, Offset center) {
    final Paint hubPaint = Paint()
      ..color = DrumcabularyTheme.edgeSurfaceSecondary.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;
    final Paint hubBorderPaint = Paint()
      ..color = DrumcabularyTheme.edgeBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, 28, hubPaint);
    canvas.drawCircle(center, 28, hubBorderPaint);
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: 'Progress',
        style: TextStyle(
          color: DrumcabularyTheme.edgeTextMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: textDirection,
    )..layout(maxWidth: 56);
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
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

class _SelectedNodeSummary extends StatelessWidget {
  final CurriculumCompassPoint value;
  final VoidCallback? onDrillIn;
  final VoidCallback? onOpenSkill;
  final VoidCallback? onOpenExercise;

  const _SelectedNodeSummary({
    super.key,
    required this.value,
    required this.onDrillIn,
    required this.onOpenSkill,
    required this.onOpenExercise,
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
                if (onDrillIn != null)
                  _SummaryActionButton(
                    onPressed: onDrillIn,
                    icon: Icons.explore_rounded,
                    label: 'Explore ${value.label}',
                  ),
                if (onOpenSkill != null)
                  _SummaryActionButton(
                    onPressed: onOpenSkill,
                    icon: Icons.arrow_forward_rounded,
                    label: 'Browse All Lessons',
                  ),
                if (onOpenExercise != null)
                  _SummaryActionButton(
                    onPressed: onOpenExercise,
                    icon: Icons.play_arrow_rounded,
                    label: 'Practice Exercise',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const DrumSectionTitle(text: 'Curriculum Compass'),
        const SizedBox(height: 6),
        Text(
          'Maps curriculum progress while keeping practice time in context.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: DrumcabularyTheme.edgeTextSecondary,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _PracticePortraitEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _PracticePortraitEmptyState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
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
                  if (actionLabel != null && onAction != null) ...<Widget>[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: onAction,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompassPaginationControls extends StatelessWidget {
  final int pageIndex;
  final int pageCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _CompassPaginationControls({
    required this.pageIndex,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Compass page ${pageIndex + 1} of $pageCount',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          OutlinedButton.icon(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Previous set'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              '${pageIndex + 1} of $pageCount',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: DrumcabularyTheme.edgeTextSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            label: const Text('Next set'),
          ),
        ],
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

String _formatProgressPercent(double value) {
  return '${(value.clamp(0, 1) * 100).round()}%';
}

List<Widget> _selectedMetricsFor(CurriculumCompassPoint value) {
  return <Widget>[
    _SelectedMetric(
      label: 'Progress',
      value: value.progressRatio,
      formatter: _formatProgressPercent,
    ),
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
  if (value.kind == CompassNodeKind.exercise) {
    return <String>[value.isCompleted ? 'Completed' : 'Not completed'];
  }
  return <String>[
    if (value.practicedSeconds == 0) 'Not practiced yet',
    if (value.completedExerciseCount == 0) 'No completions yet',
  ];
}

String _compassSemanticLabel(List<CurriculumCompassPoint> values) {
  final StringBuffer buffer = StringBuffer('Curriculum Compass.');
  for (final CurriculumCompassPoint value in values) {
    buffer.write(' ${value.label}. ');
    buffer.write('${_formatProgressPercent(value.progressRatio)} progress. ');
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

String _emptyStateTitle(CurriculumCompassSnapshot snapshot) {
  final CompassNodeKind? contentKind = _emptyContentKind(snapshot);
  if (snapshot.hasNoInteraction) {
    return switch (contentKind) {
      CompassNodeKind.lesson => 'No lesson activity yet',
      CompassNodeKind.exercise => 'No exercises practiced yet',
      _ => 'No activity yet',
    };
  }
  return switch (contentKind) {
    CompassNodeKind.lesson => 'No lessons are available yet',
    CompassNodeKind.exercise => 'No exercises are available yet',
    _ => 'No curriculum nodes yet',
  };
}

String _emptyStateMessage(CurriculumCompassSnapshot snapshot) {
  final CompassNodeKind? contentKind = _emptyContentKind(snapshot);
  if (snapshot.hasNoInteraction) {
    return switch (contentKind) {
      CompassNodeKind.lesson =>
        'You have not practiced any lessons in this topic yet.',
      CompassNodeKind.exercise =>
        'You have not practiced any exercises in this lesson yet.',
      _ => 'Practice or complete content here to fill in the compass.',
    };
  }
  return switch (contentKind) {
    CompassNodeKind.lesson => 'No lessons are attached to this topic yet.',
    CompassNodeKind.exercise =>
      'No exercises are available in this lesson yet.',
    _ => 'Add curriculum child nodes to build the compass.',
  };
}

String? _emptyStateActionLabel(CurriculumCompassSnapshot snapshot) {
  final CompassNodeKind? contentKind = _emptyContentKind(snapshot);
  if (snapshot.hasNoInteraction && contentKind == CompassNodeKind.lesson) {
    return 'Browse All Lessons';
  }
  if (snapshot.hasNoInteraction && contentKind == CompassNodeKind.exercise) {
    return 'View All Exercises';
  }
  return null;
}

CompassNodeKind? _emptyContentKind(CurriculumCompassSnapshot snapshot) {
  final CompassNodeKind? childKind = snapshot.childKind;
  if (childKind != null) return childKind;
  return switch (snapshot.currentNode.kind) {
    CompassNodeKind.topic => CompassNodeKind.lesson,
    CompassNodeKind.lesson => CompassNodeKind.exercise,
    _ => null,
  };
}
