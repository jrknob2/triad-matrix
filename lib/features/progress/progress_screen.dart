import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../features/app/app_viewport.dart';
import '../../features/app/drumcabulary_ui.dart';
import '../../state/app_controller.dart';
import '../practice/widgets/pattern_display_text.dart';

enum _ProgressView { overview, byItem, byGroup, trend }

enum _ItemScope { workingOn, catalog }

const BorderRadius _verticalBarBorderRadius = BorderRadius.only(
  topLeft: Radius.circular(10),
  topRight: Radius.circular(10),
);

class ProgressScreen extends StatefulWidget {
  final AppController controller;
  final ValueChanged<String> onOpenItem;

  const ProgressScreen({
    super.key,
    required this.controller,
    required this.onOpenItem,
  });

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  _ProgressView _view = _ProgressView.overview;
  _ItemScope _itemScope = _ItemScope.workingOn;
  String? _selectedItemId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        final List<PracticeItemV1> scopeItems = _itemsForScope(_itemScope);
        final String? selectedItemId = _resolveSelectedItemId(scopeItems);

        return DrumScreen(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: <Widget>[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _ProgressView.values
                      .map(
                        (_ProgressView view) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: DrumSelectablePill(
                            label: Text(
                              _labelForView(view),
                              style: TextStyle(
                                color: _view == view ? Colors.white : null,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            selected: _view == view,
                            onPressed: () => setState(() => _view = view),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              const SizedBox(height: 14),
              switch (_view) {
                _ProgressView.overview => _OverviewView(
                  controller: widget.controller,
                ),
                _ProgressView.byItem => _ByItemView(
                  controller: widget.controller,
                  onOpenItem: widget.onOpenItem,
                  scope: _itemScope,
                  onChangeScope: (_ItemScope scope) {
                    setState(() {
                      _itemScope = scope;
                      _selectedItemId = null;
                    });
                  },
                  selectedItemId: selectedItemId,
                  onSelectItem: (String itemId) {
                    setState(() => _selectedItemId = itemId);
                  },
                ),
                _ProgressView.byGroup => _ByGroupView(
                  controller: widget.controller,
                ),
                _ProgressView.trend => _TrendView(
                  controller: widget.controller,
                ),
              },
            ],
          ),
        );
      },
    );
  }

  List<PracticeItemV1> _itemsForScope(_ItemScope scope) {
    return switch (scope) {
      _ItemScope.workingOn => widget.controller.activeWorkItems,
      _ItemScope.catalog =>
        widget.controller.trackedItems.toList(growable: false)..sort(
          (PracticeItemV1 a, PracticeItemV1 b) =>
              widget.controller
                  .lastSessionForItem(b.id)
                  ?.endedAt
                  .compareTo(
                    widget.controller.lastSessionForItem(a.id)?.endedAt ??
                        DateTime.fromMillisecondsSinceEpoch(0),
                  ) ??
              -1,
        ),
    };
  }

  String? _resolveSelectedItemId(List<PracticeItemV1> items) {
    if (items.isEmpty) return null;
    if (_selectedItemId != null &&
        items.any((item) => item.id == _selectedItemId)) {
      return _selectedItemId;
    }
    return items.first.id;
  }

  String _labelForView(_ProgressView view) {
    return switch (view) {
      _ProgressView.overview => 'Overview',
      _ProgressView.byItem => 'By Item',
      _ProgressView.byGroup => 'By Group',
      _ProgressView.trend => 'Trend',
    };
  }
}

class _OverviewView extends StatelessWidget {
  final AppController controller;

  const _OverviewView({required this.controller});

  @override
  Widget build(BuildContext context) {
    final bool isTablet = AppViewport.isTablet(context);
    final Duration trackedTime =
        controller.totalTime() -
        controller.totalTime(family: MaterialFamilyV1.custom) -
        controller.totalTime(family: MaterialFamilyV1.warmup);
    final List<_StatusCount> statusCounts = <_StatusCount>[
      _StatusCount(
        label: 'Not Practiced',
        count: controller.trackedItems
            .where(
              (PracticeItemV1 item) =>
                  controller.matrixProgressStateFor(item.id) ==
                  MatrixProgressStateV1.notTrained,
            )
            .length,
        color: const Color(0xFFFFFFFF),
      ),
      _StatusCount(
        label: 'Active',
        count: controller.trackedItems
            .where(
              (PracticeItemV1 item) =>
                  controller.matrixProgressStateFor(item.id) ==
                  MatrixProgressStateV1.active,
            )
            .length,
        color: const Color(0xFFD9E9F7),
      ),
      _StatusCount(
        label: 'Needs Work',
        count: controller.trackedItems
            .where(
              (PracticeItemV1 item) =>
                  controller.matrixProgressStateFor(item.id) ==
                  MatrixProgressStateV1.needsWork,
            )
            .length,
        color: const Color(0xFFF0B2AA),
      ),
      _StatusCount(
        label: 'Strong',
        count: controller.trackedItems
            .where(
              (PracticeItemV1 item) =>
                  controller.matrixProgressStateFor(item.id) ==
                  MatrixProgressStateV1.strong,
            )
            .length,
        color: const Color(0xFFDDEDDD),
      ),
    ];
    final List<_WeeklyAssessmentBucket> buckets = _buildWeeklyAssessmentBuckets(
      controller,
    );

    final Widget statusPanel = DrumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: DrumSectionTitle(text: 'Assessment Status'),
              ),
              _PassiveScopeLabel(text: 'Catalog'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: statusCounts
                .map(
                  (_StatusCount status) => DecoratedBox(
                    decoration: BoxDecoration(
                      color: status.color,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x22000000)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${status.count}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(status.label),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );

    final Widget trendPanel = DrumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: DrumSectionTitle(text: 'Assessment Mix, Last 6 Weeks'),
              ),
              _PassiveScopeLabel(text: 'Catalog'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Weekly assessment status across the catalog.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5E584D)),
          ),
          const SizedBox(height: 10),
          const _ChartLegend(
            entries: <_LegendEntry>[
              _LegendEntry('Not Practiced', Color(0xFFFFFFFF)),
              _LegendEntry('Active', Color(0xFF86B4E1)),
              _LegendEntry('Needs Work', Color(0xFFE38E80)),
              _LegendEntry('Strong', Color(0xFF84B884)),
            ],
          ),
          const SizedBox(height: 12),
          if (controller.assessmentResults.length < 3)
            const Text(
              'Not enough assessed sessions yet to draw a useful trend.',
            )
          else
            _WeeklyStatusMixChart(buckets: buckets),
        ],
      ),
    );

    final Widget coveragePanel = DrumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: DrumSectionTitle(text: 'Coverage Snapshot'),
              ),
              _PassiveScopeLabel(text: 'Catalog'),
            ],
          ),
          const SizedBox(height: 10),
          _CoverageSnapshotRow(
            label: 'Triads Covered',
            count: controller.practicedTriadCount,
            total: controller.triadMatrixItems.length,
          ),
          const SizedBox(height: 8),
          _CoverageSnapshotRow(
            label: 'Hands Only',
            count: controller.practicedHandsOnlyTriadCount,
            total: controller.totalHandsOnlyTriadCount,
          ),
          const SizedBox(height: 8),
          _CoverageSnapshotRow(
            label: 'Has Kick',
            count: controller.practicedKickTriadCount,
            total: controller.totalKickTriadCount,
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _MetricStrip(
          metrics: <_MetricData>[
            _MetricData(
              title: 'Logged Time',
              value: formatDuration(trackedTime),
              note: 'Tracked material only',
            ),
            _MetricData(
              title: 'Sessions',
              value: '${controller.sessionCount()}',
              note: 'Tracked sessions',
            ),
            _MetricData(
              title: 'Working On',
              value: '${controller.activeWorkItems.length}',
              note: 'Current active items',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isTablet)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: statusPanel),
              const SizedBox(width: AppViewport.splitPaneGap),
              Expanded(flex: 2, child: trendPanel),
            ],
          )
        else ...<Widget>[statusPanel, const SizedBox(height: 12), trendPanel],
        const SizedBox(height: 12),
        coveragePanel,
      ],
    );
  }
}

class _ByItemView extends StatelessWidget {
  final AppController controller;
  final ValueChanged<String> onOpenItem;
  final _ItemScope scope;
  final ValueChanged<_ItemScope> onChangeScope;
  final String? selectedItemId;
  final ValueChanged<String> onSelectItem;

  const _ByItemView({
    required this.controller,
    required this.onOpenItem,
    required this.scope,
    required this.onChangeScope,
    required this.selectedItemId,
    required this.onSelectItem,
  });

  @override
  Widget build(BuildContext context) {
    final bool isTablet = AppViewport.isTablet(context);
    final List<PracticeItemV1> items = switch (scope) {
      _ItemScope.workingOn => controller.activeWorkItems,
      _ItemScope.catalog =>
        controller.trackedItems.toList(growable: false)..sort(
          (PracticeItemV1 a, PracticeItemV1 b) =>
              controller
                  .lastSessionForItem(b.id)
                  ?.endedAt
                  .compareTo(
                    controller.lastSessionForItem(a.id)?.endedAt ??
                        DateTime.fromMillisecondsSinceEpoch(0),
                  ) ??
              -1,
        ),
    };

    PracticeItemV1? selectedItem;
    if (selectedItemId != null) {
      for (final PracticeItemV1 item in items) {
        if (item.id == selectedItemId) {
          selectedItem = item;
          break;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _ItemScope.values
                .map(
                  (_ItemScope nextScope) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: DrumSelectablePill(
                      label: Text(
                        switch (nextScope) {
                          _ItemScope.workingOn => 'Working On',
                          _ItemScope.catalog => 'Catalog',
                        },
                        style: TextStyle(
                          color: scope == nextScope ? Colors.white : null,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      selected: scope == nextScope,
                      onPressed: () => onChangeScope(nextScope),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 12),
        if (isTablet)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 360,
                child: DrumPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      DrumSectionTitle(
                        text: scope == _ItemScope.workingOn
                            ? 'Working On Items'
                            : 'Catalog',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        scope == _ItemScope.workingOn
                            ? 'Select an item to inspect its assessment history.'
                            : 'Select tracked material to inspect its assessment history.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5E584D),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (items.isEmpty)
                        Text(
                          scope == _ItemScope.workingOn
                              ? 'Nothing is in Working On yet.'
                              : 'No tracked material yet.',
                        )
                      else
                        ...items.map(
                          (PracticeItemV1 item) => _ProgressItemRow(
                            item: item,
                            controller: controller,
                            selected: item.id == selectedItemId,
                            onSelectItem: () => onSelectItem(item.id),
                            onOpenItem: onOpenItem,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppViewport.splitPaneGap),
              Expanded(
                child: selectedItem == null
                    ? DrumPanel(
                        child: Text(
                          'Select an item to inspect its assessment history.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFF5E584D)),
                        ),
                      )
                    : _ItemAssessmentPanel(
                        controller: controller,
                        item: selectedItem,
                        onOpenItem: onOpenItem,
                      ),
              ),
            ],
          )
        else ...<Widget>[
          DrumPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DrumSectionTitle(
                  text: scope == _ItemScope.workingOn
                      ? 'Working On Items'
                      : 'Catalog',
                ),
                const SizedBox(height: 8),
                Text(
                  scope == _ItemScope.workingOn
                      ? 'Select an item to inspect its assessment history.'
                      : 'Select tracked material to inspect its assessment history.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5E584D),
                  ),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  Text(
                    scope == _ItemScope.workingOn
                        ? 'Nothing is in Working On yet.'
                        : 'No tracked material yet.',
                  )
                else
                  ...items.map(
                    (PracticeItemV1 item) => _ProgressItemRow(
                      item: item,
                      controller: controller,
                      selected: item.id == selectedItemId,
                      onSelectItem: () => onSelectItem(item.id),
                      onOpenItem: onOpenItem,
                    ),
                  ),
              ],
            ),
          ),
          if (selectedItem != null) ...<Widget>[
            const SizedBox(height: 12),
            _ItemAssessmentPanel(
              controller: controller,
              item: selectedItem,
              onOpenItem: onOpenItem,
            ),
          ],
        ],
      ],
    );
  }
}

class _ByGroupView extends StatelessWidget {
  final AppController controller;

  const _ByGroupView({required this.controller});

  @override
  Widget build(BuildContext context) {
    final Duration rightLeadTime = controller.leadTime(HandednessV1.right);
    final Duration leftLeadTime = controller.leadTime(HandednessV1.left);
    final int totalLeadSeconds =
        rightLeadTime.inSeconds + leftLeadTime.inSeconds;
    final double rightFraction = totalLeadSeconds == 0
        ? 0.5
        : rightLeadTime.inSeconds / totalLeadSeconds;
    final double leftFraction = totalLeadSeconds == 0
        ? 0.5
        : leftLeadTime.inSeconds / totalLeadSeconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _MetricStrip(
          metrics: <_MetricData>[
            _MetricData(
              title: 'Triads Covered',
              value:
                  '${controller.practicedTriadCount}/${controller.triadMatrixItems.length}',
              note: 'Across the matrix',
            ),
            _MetricData(
              title: 'Hands Only',
              value:
                  '${controller.practicedHandsOnlyTriadCount}/${controller.totalHandsOnlyTriadCount}',
              note: 'Surface-first coverage',
            ),
            _MetricData(
              title: 'Has Kick',
              value:
                  '${controller.practicedKickTriadCount}/${controller.totalKickTriadCount}',
              note: 'Kick-integration coverage',
            ),
          ],
        ),
        const SizedBox(height: 12),
        DrumPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const DrumSectionTitle(text: 'Lead Balance'),
              const SizedBox(height: 10),
              _BalanceBar(
                leftLabel: 'Right Lead',
                rightLabel: 'Left Lead',
                leftFraction: rightFraction,
                rightFraction: leftFraction,
              ),
              const SizedBox(height: 10),
              _CoverageRow(
                label: 'Right Lead Time',
                value: formatDuration(rightLeadTime),
              ),
              const SizedBox(height: 8),
              _CoverageRow(
                label: 'Left Lead Time',
                value: formatDuration(leftLeadTime),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrendView extends StatelessWidget {
  final AppController controller;

  const _TrendView({required this.controller});

  @override
  Widget build(BuildContext context) {
    final bool isTablet = AppViewport.isTablet(context);
    final DateTime today = DateTime.now();
    final List<_DayBucket> buckets = List<_DayBucket>.generate(7, (int index) {
      final DateTime day = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: 6 - index));
      final Duration total = controller.recentSessions.fold<Duration>(
        Duration.zero,
        (Duration sum, PracticeSessionLogV1 session) {
          final DateTime ended = DateTime(
            session.endedAt.year,
            session.endedAt.month,
            session.endedAt.day,
          );
          if (ended != day) return sum;
          return sum + session.duration;
        },
      );
      return _DayBucket(day: day, total: total);
    });
    final int maxSeconds = buckets.fold<int>(
      0,
      (int maxValue, _DayBucket bucket) =>
          bucket.total.inSeconds > maxValue ? bucket.total.inSeconds : maxValue,
    );

    final Widget practiceTimePanel = DrumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const DrumSectionTitle(text: 'Practice Minutes, Last 7 Days'),
          const SizedBox(height: 8),
          Text(
            'Minutes practiced each day.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5E584D)),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: buckets
                .map(
                  (_DayBucket bucket) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _TrendBar(
                        label: _dayLabel(bucket.day),
                        value: bucket.total,
                        maxSeconds: maxSeconds == 0 ? 1 : maxSeconds,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );

    final Widget recentSessionsPanel = DrumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const DrumSectionTitle(text: 'Recent Sessions'),
          const SizedBox(height: 10),
          if (controller.recentSessions.isEmpty)
            const Text('No tracked sessions yet.')
          else
            ...controller.recentSessions
                .take(5)
                .map(
                  (PracticeSessionLogV1 session) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${formatShortDate(session.endedAt)} • ${formatDuration(session.duration)} • ${session.practiceMode.label}',
                    ),
                  ),
                ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (isTablet)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(flex: 2, child: practiceTimePanel),
              const SizedBox(width: AppViewport.splitPaneGap),
              Expanded(child: recentSessionsPanel),
            ],
          )
        else ...<Widget>[
          practiceTimePanel,
          const SizedBox(height: 12),
          recentSessionsPanel,
        ],
      ],
    );
  }

  String _dayLabel(DateTime value) {
    return switch (value.weekday) {
      DateTime.monday => 'M',
      DateTime.tuesday => 'T',
      DateTime.wednesday => 'W',
      DateTime.thursday => 'T',
      DateTime.friday => 'F',
      DateTime.saturday => 'S',
      DateTime.sunday => 'S',
      _ => '',
    };
  }
}

class _ItemAssessmentPanel extends StatelessWidget {
  final AppController controller;
  final PracticeItemV1 item;
  final ValueChanged<String> onOpenItem;

  const _ItemAssessmentPanel({
    required this.controller,
    required this.item,
    required this.onOpenItem,
  });

  @override
  Widget build(BuildContext context) {
    final List<SessionAssessmentResultV1> assessments = controller
        .assessmentHistoryForItem(item.id);
    final List<PracticeSessionLogV1> sessions = controller
        .sessionHistoryForItem(item.id);
    final PracticeAssessmentAggregateV1? aggregate = controller
        .assessmentAggregateFor(item.id);

    return DrumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: PatternDisplayText(
                  tokens: controller.noteTokensFor(item.id),
                  markings: controller.noteMarkingsFor(item.id),
                  grouping: controller.displayGroupingFor(item.id),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => onOpenItem(item.id),
                child: const Text('Open'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            aggregate == null
                ? 'No assessment yet.'
                : '${aggregate.status.label} • ${assessments.length} assessed sessions',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5E584D)),
          ),
          const SizedBox(height: 12),
          if (assessments.length < 3)
            const Text(
              'Not enough assessed sessions yet to draw a useful item graph.',
            )
          else ...<Widget>[
            const _GraphTitle(text: 'Assessment'),
            const SizedBox(height: 10),
            _StatusTimelineChart(
              points: assessments
                  .map(
                    (SessionAssessmentResultV1 result) => _SeriesPoint(
                      label: _shortDateLabel(result.assessedAt),
                      value: _statusValue(
                        controller.statusForAssessmentResult(result),
                      ),
                      color: _statusColor(
                        controller.statusForAssessmentResult(result),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 16),
            const _GraphTitle(text: 'BPM'),
            const SizedBox(height: 10),
            _MiniLineChart(
              points: assessments
                  .map(
                    (SessionAssessmentResultV1 result) => _SeriesPoint(
                      label: _shortDateLabel(result.assessedAt),
                      value: result.attemptedBpm.toDouble(),
                      color: const Color(0xFF3A6F96),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 16),
            const _GraphTitle(text: 'Session Time'),
            const SizedBox(height: 10),
            _MiniBarChart(
              bars: sessions
                  .map(
                    (PracticeSessionLogV1 session) => _SeriesPoint(
                      label: _shortDateLabel(session.endedAt),
                      value: session.duration.inMinutes.toDouble(),
                      color: const Color(0xFF26211C),
                    ),
                  )
                  .toList(growable: false),
              valueSuffix: 'm',
            ),
          ],
        ],
      ),
    );
  }

  static String _shortDateLabel(DateTime value) {
    final String month = value.month.toString();
    final String day = value.day.toString();
    return '$month/$day';
  }

  static double _statusValue(MatrixProgressStateV1 status) {
    return switch (status) {
      MatrixProgressStateV1.notTrained => 1,
      MatrixProgressStateV1.needsWork => 2,
      MatrixProgressStateV1.active => 3,
      MatrixProgressStateV1.strong => 4,
    }.toDouble();
  }

  static Color _statusColor(MatrixProgressStateV1 status) {
    return switch (status) {
      MatrixProgressStateV1.notTrained => const Color(0xFFE0DDD8),
      MatrixProgressStateV1.active => const Color(0xFF6F9ECB),
      MatrixProgressStateV1.needsWork => const Color(0xFFD98D82),
      MatrixProgressStateV1.strong => const Color(0xFF80AC80),
    };
  }
}

class _MetricData {
  final String title;
  final String value;
  final String note;

  const _MetricData({
    required this.title,
    required this.value,
    required this.note,
  });
}

class _StatusCount {
  final String label;
  final int count;
  final Color color;

  const _StatusCount({
    required this.label,
    required this.count,
    required this.color,
  });
}

class _LegendEntry {
  final String label;
  final Color color;

  const _LegendEntry(this.label, this.color);
}

class _MetricStrip extends StatelessWidget {
  final List<_MetricData> metrics;

  const _MetricStrip({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final bool isTablet = AppViewport.isTablet(context);
    final List<Widget> metricCards = metrics
        .map(
          (_MetricData metric) => SizedBox(
            width: isTablet ? 220 : 155,
            child: DrumPanel(
              tone: DrumPanelTone.warm,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    metric.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    metric.value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    metric.note,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        )
        .toList(growable: false);

    if (isTablet) {
      return Wrap(spacing: 10, runSpacing: 10, children: metricCards);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: metricCards
            .map(
              (Widget child) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: child,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _ProgressItemRow extends StatelessWidget {
  final PracticeItemV1 item;
  final AppController controller;
  final bool selected;
  final VoidCallback onSelectItem;
  final ValueChanged<String> onOpenItem;

  const _ProgressItemRow({
    required this.item,
    required this.controller,
    required this.selected,
    required this.onSelectItem,
    required this.onOpenItem,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelectItem,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? const Color(0xFFF0E7D8) : Colors.transparent,
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  PatternDisplayText(
                    tokens: controller.noteTokensFor(item.id),
                    markings: controller.noteMarkingsFor(item.id),
                    grouping: controller.displayGroupingFor(item.id),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${controller.matrixProgressStateFor(item.id).label} • ${controller.recentSummaryForItem(item.id)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6A5E4C),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatDuration(controller.totalTime(itemId: item.id))} logged • ${controller.sessionCount(itemId: item.id)} sessions',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6A5E4C),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => onOpenItem(item.id),
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Open item',
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverageRow extends StatelessWidget {
  final String label;
  final String value;

  const _CoverageRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5E584D)),
          ),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final List<_LegendEntry> entries;

  const _ChartLegend({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: entries
          .map(
            (_LegendEntry entry) => Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: entry.color,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: const Color(0x22000000)),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  entry.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF5E584D),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          )
          .toList(growable: false),
    );
  }
}

class _CoverageSnapshotRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;

  const _CoverageSnapshotRow({
    required this.label,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5E584D)),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              '$count',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              'of $total total',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6A5E4C)),
            ),
          ],
        ),
      ],
    );
  }
}

class _BalanceBar extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final double leftFraction;
  final double rightFraction;

  const _BalanceBar({
    required this.leftLabel,
    required this.rightLabel,
    required this.leftFraction,
    required this.rightFraction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                leftLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: Text(
                rightLabel,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 14,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x22000000)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                flex: math.max(1, (leftFraction * 1000).round()),
                child: const ColoredBox(color: Color(0xFF83A9D6)),
              ),
              Expanded(
                flex: math.max(1, (rightFraction * 1000).round()),
                child: const ColoredBox(color: Color(0xFFE29A90)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayBucket {
  final DateTime day;
  final Duration total;

  const _DayBucket({required this.day, required this.total});
}

class _TrendBar extends StatelessWidget {
  final String label;
  final Duration value;
  final int maxSeconds;

  const _TrendBar({
    required this.label,
    required this.value,
    required this.maxSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final double heightFactor = value.inSeconds / maxSeconds;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value.inSeconds == 0 ? '0m' : '${value.inMinutes}m',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 110,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              widthFactor: 0.78,
              child: Container(
                height: 18 + (92 * heightFactor),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1ECE2),
                  border: Border.fromBorderSide(
                    BorderSide(color: Color(0xFF26211C), width: 1.5),
                  ),
                  borderRadius: _verticalBarBorderRadius,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _WeeklyAssessmentBucket {
  final DateTime weekStart;
  final int notPracticed;
  final int active;
  final int needsWork;
  final int strong;

  const _WeeklyAssessmentBucket({
    required this.weekStart,
    required this.notPracticed,
    required this.active,
    required this.needsWork,
    required this.strong,
  });

  int get total => notPracticed + active + needsWork + strong;
}

class _WeeklyStatusMixChart extends StatelessWidget {
  final List<_WeeklyAssessmentBucket> buckets;

  const _WeeklyStatusMixChart({required this.buckets});

  @override
  Widget build(BuildContext context) {
    final int maxTotal = buckets.fold<int>(
      0,
      (int maxValue, _WeeklyAssessmentBucket bucket) =>
          bucket.total > maxValue ? bucket.total : maxValue,
    );

    return SizedBox(
      height: 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: buckets
            .map(
              (_WeeklyAssessmentBucket bucket) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        '${bucket.total}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: _StackedStatusBar(
                            bucket: bucket,
                            maxTotal: maxTotal == 0 ? 1 : maxTotal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _weekLabel(bucket.weekStart),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  String _weekLabel(DateTime weekStart) {
    return '${weekStart.month}/${weekStart.day}';
  }
}

class _StackedStatusBar extends StatelessWidget {
  final _WeeklyAssessmentBucket bucket;
  final int maxTotal;

  const _StackedStatusBar({required this.bucket, required this.maxTotal});

  @override
  Widget build(BuildContext context) {
    final List<({int count, Color color})> segments =
        <({int count, Color color})>[
          (count: bucket.notPracticed, color: const Color(0xFFFFFFFF)),
          (count: bucket.active, color: const Color(0xFF86B4E1)),
          (count: bucket.needsWork, color: const Color(0xFFE38E80)),
          (count: bucket.strong, color: const Color(0xFF84B884)),
        ];
    final double heightFactor = bucket.total == 0 ? 0 : bucket.total / maxTotal;
    final double barHeight = 16 + (108 * heightFactor);

    return Container(
      width: 34,
      height: barHeight,
      decoration: const BoxDecoration(
        color: Color(0xFFF1ECE2),
        borderRadius: _verticalBarBorderRadius,
        border: Border.fromBorderSide(BorderSide(color: Color(0x26000000))),
      ),
      child: ClipRRect(
        borderRadius: _verticalBarBorderRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: segments
              .map(
                (segment) => segment.count == 0
                    ? const SizedBox.shrink()
                    : Expanded(
                        flex: segment.count,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: segment.color,
                            border: const Border(
                              top: BorderSide(color: Color(0x14000000)),
                            ),
                          ),
                        ),
                      ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _SeriesPoint {
  final String label;
  final double value;
  final Color color;

  const _SeriesPoint({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _GraphTitle extends StatelessWidget {
  final String text;

  const _GraphTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    );
  }
}

class _StatusTimelineChart extends StatelessWidget {
  final List<_SeriesPoint> points;

  const _StatusTimelineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    return _MiniLineChart(
      points: points,
      minValue: 1,
      maxValue: 4,
      yLabels: const <int, String>{
        1: 'Not Practiced',
        2: 'Needs Work',
        3: 'Active',
        4: 'Strong',
      },
    );
  }
}

class _MiniLineChart extends StatelessWidget {
  final List<_SeriesPoint> points;
  final double? minValue;
  final double? maxValue;
  final Map<int, String>? yLabels;

  const _MiniLineChart({
    required this.points,
    this.minValue,
    this.maxValue,
    this.yLabels,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final double minY =
        minValue ?? points.map((point) => point.value).reduce(math.min);
    final double maxY =
        maxValue ?? points.map((point) => point.value).reduce(math.max);

    return SizedBox(
      height: 190,
      child: Row(
        children: <Widget>[
          if (yLabels != null)
            SizedBox(
              width: 86,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: yLabels!.entries
                    .toList()
                    .reversed
                    .map(
                      (entry) => Text(
                        entry.value,
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: CustomPaint(
                    painter: _LineChartPainter(
                      points: points,
                      minY: minY,
                      maxY: maxY == minY ? minY + 1 : maxY,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: points
                      .map(
                        (_SeriesPoint point) => Expanded(
                          child: Text(
                            point.label,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<_SeriesPoint> points;
  final double minY;
  final double maxY;

  const _LineChartPainter({
    required this.points,
    required this.minY,
    required this.maxY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double topPad = 8;
    const double bottomPad = 10;
    final Paint gridPaint = Paint()
      ..color = const Color(0x1A000000)
      ..strokeWidth = 1;
    final Paint linePaint = Paint()
      ..color = const Color(0xFF26211C)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 4; i++) {
      final double dy = topPad + ((size.height - topPad - bottomPad) * i / 3);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    if (points.length == 1) {
      final Offset point = _offsetFor(0, points[0].value, size);
      canvas.drawCircle(point, 5, Paint()..color = points[0].color);
      return;
    }

    final Path path = Path();
    for (int index = 0; index < points.length; index++) {
      final Offset point = _offsetFor(index, points[index].value, size);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, linePaint);

    for (int index = 0; index < points.length; index++) {
      final Offset point = _offsetFor(index, points[index].value, size);
      canvas.drawCircle(point, 5, Paint()..color = points[index].color);
      canvas.drawCircle(
        point,
        5,
        Paint()
          ..color = const Color(0xFFF8F6F1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  Offset _offsetFor(int index, double value, Size size) {
    const double topPad = 8;
    const double bottomPad = 10;
    final double x = points.length == 1
        ? size.width / 2
        : size.width * index / (points.length - 1);
    final double normalized = (value - minY) / (maxY - minY);
    final double y =
        size.height -
        bottomPad -
        ((size.height - topPad - bottomPad) * normalized);
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY;
  }
}

class _MiniBarChart extends StatelessWidget {
  final List<_SeriesPoint> bars;
  final String valueSuffix;

  const _MiniBarChart({required this.bars, required this.valueSuffix});

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return const SizedBox.shrink();
    final double maxValue = bars.map((bar) => bar.value).reduce(math.max);

    return SizedBox(
      height: 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: bars
            .map(
              (_SeriesPoint bar) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        '${bar.value.round()}$valueSuffix',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            widthFactor: 0.74,
                            child: Container(
                              height:
                                  20 +
                                  (90 *
                                      (maxValue == 0
                                          ? 0
                                          : bar.value / maxValue)),
                              decoration: BoxDecoration(
                                color: bar.color,
                                border: const Border.fromBorderSide(
                                  BorderSide(
                                    color: Color(0xFF26211C),
                                    width: 1.5,
                                  ),
                                ),
                                borderRadius: _verticalBarBorderRadius,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        bar.label,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _PassiveScopeLabel extends StatelessWidget {
  final String text;

  const _PassiveScopeLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: const Color(0xFF6A5E4C),
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

List<_WeeklyAssessmentBucket> _buildWeeklyAssessmentBuckets(
  AppController controller,
) {
  final DateTime today = DateTime.now();
  final DateTime startOfThisWeek = DateTime(
    today.year,
    today.month,
    today.day,
  ).subtract(Duration(days: today.weekday - 1));

  return List<_WeeklyAssessmentBucket>.generate(6, (int index) {
    final DateTime weekStart = startOfThisWeek.subtract(
      Duration(days: (5 - index) * 7),
    );
    int notPracticed = 0;
    int active = 0;
    int needsWork = 0;
    int strong = 0;

    for (final SessionAssessmentResultV1 result
        in controller.assessmentResults) {
      final DateTime assessed = DateTime(
        result.assessedAt.year,
        result.assessedAt.month,
        result.assessedAt.day,
      );
      final DateTime assessedWeekStart = assessed.subtract(
        Duration(days: assessed.weekday - 1),
      );
      if (assessedWeekStart != weekStart) continue;
      switch (controller.statusForAssessmentResult(result)) {
        case MatrixProgressStateV1.notTrained:
          notPracticed += 1;
        case MatrixProgressStateV1.active:
          active += 1;
        case MatrixProgressStateV1.needsWork:
          needsWork += 1;
        case MatrixProgressStateV1.strong:
          strong += 1;
      }
    }

    return _WeeklyAssessmentBucket(
      weekStart: weekStart,
      notPracticed: notPracticed,
      active: active,
      needsWork: needsWork,
      strong: strong,
    );
  });
}
