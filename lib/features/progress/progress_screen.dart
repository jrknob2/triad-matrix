import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../features/app/drumcabulary_ui.dart';
import '../../state/app_controller.dart';
import '../practice/widgets/pattern_display_text.dart';

enum _ProgressView { overview, byItem, byGroup, trend }

enum _ItemScope { workingOn, catalog }

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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
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
              _buildView(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildView(BuildContext context) {
    return switch (_view) {
      _ProgressView.overview => _OverviewView(controller: widget.controller),
      _ProgressView.byItem => _ByItemView(
        controller: widget.controller,
        onOpenItem: widget.onOpenItem,
        scope: _itemScope,
        onChangeScope: (_ItemScope scope) => setState(() => _itemScope = scope),
      ),
      _ProgressView.byGroup => _ByGroupView(controller: widget.controller),
      _ProgressView.trend => _TrendView(controller: widget.controller),
    };
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
    final Duration trackedTime =
        controller.totalTime() -
        controller.totalTime(family: MaterialFamilyV1.custom) -
        controller.totalTime(family: MaterialFamilyV1.warmup);
    final List<_StatusCount> statusCounts = <_StatusCount>[
      _StatusCount(
        label: 'Not Trained',
        count: controller.trackedItems
            .where(
              (PracticeItemV1 item) =>
                  controller.matrixProgressStateFor(item.id) ==
                  MatrixProgressStateV1.notTrained,
            )
            .length,
        color: const Color(0xFFE6E1D7),
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
        DrumPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const DrumSectionTitle(text: 'Assessment Status'),
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
        ),
        const SizedBox(height: 12),
        DrumPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const DrumSectionTitle(text: 'Coverage Snapshot'),
              const SizedBox(height: 10),
              _CoverageRow(
                label: 'Triads Seen',
                value:
                    '${controller.practicedTriadCount}/${controller.triadMatrixItems.length}',
              ),
              const SizedBox(height: 8),
              _CoverageRow(
                label: 'Hands Only',
                value:
                    '${controller.practicedHandsOnlyTriadCount}/${controller.totalHandsOnlyTriadCount}',
              ),
              const SizedBox(height: 8),
              _CoverageRow(
                label: 'Has Kick',
                value:
                    '${controller.practicedKickTriadCount}/${controller.totalKickTriadCount}',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ByItemView extends StatelessWidget {
  final AppController controller;
  final ValueChanged<String> onOpenItem;
  final _ItemScope scope;
  final ValueChanged<_ItemScope> onChangeScope;

  const _ByItemView({
    required this.controller,
    required this.onOpenItem,
    required this.scope,
    required this.onChangeScope,
  });

  @override
  Widget build(BuildContext context) {
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
                          _ItemScope.catalog => 'Tracked Catalog',
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
        DrumPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DrumSectionTitle(
                text: scope == _ItemScope.workingOn
                    ? 'Working On Items'
                    : 'Tracked Catalog',
              ),
              const SizedBox(height: 8),
              Text(
                scope == _ItemScope.workingOn
                    ? 'Current work only.'
                    : 'All tracked built-in and saved phrase material.',
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
                    onOpenItem: onOpenItem,
                  ),
                ),
            ],
          ),
        ),
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
              title: 'Triads Seen',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DrumPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const DrumSectionTitle(text: 'Last 7 Days'),
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
        ),
        const SizedBox(height: 12),
        DrumPanel(
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
        ),
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

class _MetricStrip extends StatelessWidget {
  final List<_MetricData> metrics;

  const _MetricStrip({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: metrics
            .map(
              (_MetricData metric) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SizedBox(
                  width: 155,
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
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
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
  final ValueChanged<String> onOpenItem;

  const _ProgressItemRow({
    required this.item,
    required this.controller,
    required this.onOpenItem,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onOpenItem(item.id),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
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
            const Icon(Icons.chevron_right),
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
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 14,
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: (leftFraction * 1000).round(),
                  child: const ColoredBox(color: Color(0xFF83A9D6)),
                ),
                Expanded(
                  flex: (rightFraction * 1000).round(),
                  child: const ColoredBox(color: Color(0xFFE29A90)),
                ),
              ],
            ),
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
          value.inSeconds == 0 ? '0' : '${value.inMinutes}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 110,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              height: 18 + (92 * heightFactor),
              decoration: BoxDecoration(
                color: const Color(0xFF26211C),
                borderRadius: BorderRadius.circular(999),
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
