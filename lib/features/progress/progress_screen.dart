import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../features/app/drumcabulary_ui.dart';
import '../../state/app_controller.dart';
import '../practice/widgets/pattern_display_text.dart';

enum _ProgressSection { retention, balance, coverage, toolbox }

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
  _ProgressSection _section = _ProgressSection.retention;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<_ProgressSection>(
                  segments: const <ButtonSegment<_ProgressSection>>[
                    ButtonSegment(
                      value: _ProgressSection.retention,
                      label: Text('Retention'),
                    ),
                    ButtonSegment(
                      value: _ProgressSection.balance,
                      label: Text('Balance'),
                    ),
                    ButtonSegment(
                      value: _ProgressSection.coverage,
                      label: Text('Coverage'),
                    ),
                    ButtonSegment(
                      value: _ProgressSection.toolbox,
                      label: Text('Toolbox'),
                    ),
                  ],
                  selected: <_ProgressSection>{_section},
                  onSelectionChanged: (Set<_ProgressSection> next) {
                    setState(() => _section = next.first);
                  },
                ),
              ),
            ),
            Expanded(child: _buildSection()),
          ],
        );
      },
    );
  }

  Widget _buildSection() {
    return switch (_section) {
      _ProgressSection.retention => _RetentionView(
        controller: widget.controller,
        onOpenItem: widget.onOpenItem,
      ),
      _ProgressSection.balance => _BalanceView(
        controller: widget.controller,
        onOpenItem: widget.onOpenItem,
      ),
      _ProgressSection.coverage => _CoverageView(
        controller: widget.controller,
        onOpenItem: widget.onOpenItem,
      ),
      _ProgressSection.toolbox => _ToolboxView(
        controller: widget.controller,
        onOpenItem: widget.onOpenItem,
      ),
    };
  }
}

class _RetentionView extends StatelessWidget {
  final AppController controller;
  final ValueChanged<String> onOpenItem;

  const _RetentionView({required this.controller, required this.onOpenItem});

  @override
  Widget build(BuildContext context) {
    if (controller.isFirstLight) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: const <Widget>[
          _FirstLightCard(
            title: 'Retention',
            detail:
                'Progress starts once there is work to retain. Log a few sessions and this view will begin surfacing what is cold, what needs review, and what is holding.',
          ),
        ],
      );
    }

    final List<PracticeItemV1> neglected = controller.neglectedTrackedItems
        .take(4)
        .toList(growable: false);
    final List<PracticeItemV1> review = controller.reliableItemsNeedingReview
        .take(4)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        _MetricStrip(
          metrics: <_MetricData>[
            _MetricData(
              title: 'Tracked Time',
              value: formatDuration(
                controller.totalTime() -
                    controller.totalTime(family: MaterialFamilyV1.custom),
              ),
              note: 'Core material only',
            ),
            _MetricData(
              title: 'Tracked Items',
              value: '${controller.trackedItems.length}',
              note: 'Excludes customs',
            ),
            _MetricData(
              title: 'Sessions',
              value: '${controller.recentSessions.length}',
              note: 'All logged work',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _AssessmentStatusCard(controller: controller),
        const SizedBox(height: 12),
        _ItemListCard(
          title: 'Neglected',
          description:
              'Material that has fallen out of rotation and needs a revisit before it disappears.',
          items: neglected,
          controller: controller,
          onOpenItem: onOpenItem,
          emptyText: 'Nothing is sitting cold right now.',
        ),
        const SizedBox(height: 12),
        _ItemListCard(
          title: 'Needs Review',
          description:
              'Reliable material that still needs revisits so it stays available on demand.',
          items: review,
          controller: controller,
          onOpenItem: onOpenItem,
          emptyText: 'Nothing reliable is waiting on review yet.',
        ),
      ],
    );
  }
}

class _BalanceView extends StatelessWidget {
  final AppController controller;
  final ValueChanged<String> onOpenItem;

  const _BalanceView({required this.controller, required this.onOpenItem});

  @override
  Widget build(BuildContext context) {
    if (controller.isFirstLight) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: const <Widget>[
          _FirstLightCard(
            title: 'Balance',
            detail:
                'Lead-side balance appears after the first sessions are logged. Start with both leads early so this view has something meaningful to compare.',
          ),
        ],
      );
    }

    final Duration rightLeadTime = controller.leadTime(HandednessV1.right);
    final Duration leftLeadTime = controller.leadTime(HandednessV1.left);
    final HandednessV1 weakLead =
        controller.profile.handedness == HandednessV1.right
        ? HandednessV1.left
        : HandednessV1.right;
    final List<PracticeItemV1> weakLeadItems =
        controller.triadMatrixItems
            .where(
              (item) => weakLead == HandednessV1.right
                  ? controller.startsWithRight(item.id)
                  : controller.startsWithLeft(item.id),
            )
            .toList(growable: false)
          ..sort(controller.compareItemsByNeed);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        _MetricStrip(
          metrics: <_MetricData>[
            _MetricData(
              title: 'Right Lead',
              value: formatDuration(rightLeadTime),
              note: 'Time on right-leading triads',
            ),
            _MetricData(
              title: 'Left Lead',
              value: formatDuration(leftLeadTime),
              note: 'Time on left-leading triads',
            ),
            _MetricData(
              title: 'Weak Lead',
              value: weakLead.label,
              note: 'Current rebalance side',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ItemListCard(
          title: 'Weak-Side Work',
          description:
              'These phrases start on the weaker side and should be used to rebalance the vocabulary.',
          items: weakLeadItems.take(4).toList(growable: false),
          controller: controller,
          onOpenItem: onOpenItem,
          emptyText: 'No weak-side material is being surfaced yet.',
        ),
      ],
    );
  }
}

class _CoverageView extends StatelessWidget {
  final AppController controller;
  final ValueChanged<String> onOpenItem;

  const _CoverageView({required this.controller, required this.onOpenItem});

  @override
  Widget build(BuildContext context) {
    if (controller.isFirstLight) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          _MetricStrip(
            metrics: <_MetricData>[
              _MetricData(
                title: 'Triads Ready',
                value: '${controller.triadMatrixItems.length}',
                note: 'Built-in matrix cells',
              ),
              _MetricData(
                title: 'Hands Only',
                value: '${controller.totalHandsOnlyTriadCount}',
                note: 'Surface-first material',
              ),
              _MetricData(
                title: 'Has Kick',
                value: '${controller.totalKickTriadCount}',
                note: 'Integration material',
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _FirstLightCard(
            title: 'Coverage',
            detail:
                'Coverage becomes meaningful after practice begins. At the start, do not try to touch everything. Pick a few clear cells and revisit them enough for them to settle in.',
          ),
        ],
      );
    }

    final List<PracticeItemV1> triads = controller
        .itemsNeedingPractice(MaterialFamilyV1.triad)
        .take(3)
        .toList(growable: false);
    final List<PracticeItemV1> phrases = controller.phraseWorkItems
        .take(3)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        _MetricStrip(
          metrics: <_MetricData>[
            _MetricData(
              title: 'Triads Seen',
              value:
                  '${controller.practicedTriadCount}/${controller.triadMatrixItems.length}',
              note: 'Matrix exposure so far',
            ),
            _MetricData(
              title: 'Hands Only',
              value:
                  '${controller.practicedHandsOnlyTriadCount}/${controller.totalHandsOnlyTriadCount}',
              note: 'Controlled surface work',
            ),
            _MetricData(
              title: 'Has Kick',
              value:
                  '${controller.practicedKickTriadCount}/${controller.totalKickTriadCount}',
              note: 'Integration coverage',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ItemListCard(
          title: 'Triads Needing Attention',
          description:
              'Coverage is not just touching cells once. These are the triads still light on time, confidence, or recency.',
          items: triads,
          controller: controller,
          onOpenItem: onOpenItem,
          emptyText: 'Core triad coverage is in a decent place.',
        ),
        const SizedBox(height: 12),
        _ItemListCard(
          title: 'Phrase Work In Rotation',
          description:
              'Saved phrase work shows whether practice is moving beyond single cells.',
          items: phrases,
          controller: controller,
          onOpenItem: onOpenItem,
          emptyText: 'No saved phrase work yet.',
        ),
      ],
    );
  }
}

class _ToolboxView extends StatelessWidget {
  final AppController controller;
  final ValueChanged<String> onOpenItem;

  const _ToolboxView({required this.controller, required this.onOpenItem});

  @override
  Widget build(BuildContext context) {
    if (controller.isFirstLight) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: const <Widget>[
          _FirstLightCard(
            title: 'Toolbox',
            detail:
                'Toolbox-ready material is earned. Once a phrase has enough time, reliability, and revisits behind it, it begins to appear here.',
          ),
        ],
      );
    }

    final List<PracticeItemV1> toolboxReady = controller.toolboxReadyItems
        .take(8)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        _MetricStrip(
          metrics: <_MetricData>[
            _MetricData(
              title: 'Ready Now',
              value: '${controller.toolboxReadyItems.length}',
              note: 'Near-toolbox items',
            ),
            _MetricData(
              title: 'Strong',
              value:
                  '${controller.trackedItems.where((item) => controller.matrixProgressStateFor(item.id) == MatrixProgressStateV1.strong).length}',
              note: 'Assessment status',
            ),
            _MetricData(
              title: 'Needs Work',
              value:
                  '${controller.trackedItems.where((item) => controller.matrixProgressStateFor(item.id) == MatrixProgressStateV1.needsWork).length}',
              note: 'Assessment status',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ItemListCard(
          title: 'Close To Toolbox',
          description:
              'These phrases have enough time and competency behind them that they are close to dependable use.',
          items: toolboxReady,
          controller: controller,
          onOpenItem: onOpenItem,
          emptyText: 'Nothing is close to your toolbox yet.',
        ),
      ],
    );
  }
}

class _AssessmentStatusCard extends StatelessWidget {
  final AppController controller;

  const _AssessmentStatusCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final List<_StatusData> statuses = <_StatusData>[
      _StatusData(
        status: MatrixProgressStateV1.notTrained,
        count: _count(MatrixProgressStateV1.notTrained),
        color: const Color(0xFFF1ECE3),
      ),
      _StatusData(
        status: MatrixProgressStateV1.active,
        count: _count(MatrixProgressStateV1.active),
        color: const Color(0xFFD9E9F7),
      ),
      _StatusData(
        status: MatrixProgressStateV1.needsWork,
        count: _count(MatrixProgressStateV1.needsWork),
        color: const Color(0xFFF0B2AA),
      ),
      _StatusData(
        status: MatrixProgressStateV1.strong,
        count: _count(MatrixProgressStateV1.strong),
        color: const Color(0xFFDDEDDD),
      ),
    ];

    return DrumPanel(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const DrumSectionTitle(text: 'Assessment Status'),
            const SizedBox(height: 6),
            Text(
              'This is the same status language used by Coach and Matrix.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: statuses
                  .map(
                    (_StatusData data) => DecoratedBox(
                      decoration: BoxDecoration(
                        color: data.color,
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
                              '${data.count}',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 2),
                            Text(data.status.label),
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
    );
  }

  int _count(MatrixProgressStateV1 status) {
    return controller.trackedItems
        .where(
          (PracticeItemV1 item) =>
              controller.matrixProgressStateFor(item.id) == status,
        )
        .length;
  }
}

class _StatusData {
  final MatrixProgressStateV1 status;
  final int count;
  final Color color;

  const _StatusData({
    required this.status,
    required this.count,
    required this.color,
  });
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
              (metric) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SizedBox(
                  width: 155,
                  child: DrumPanel(
                    tone: DrumPanelTone.warm,
                    padding: const EdgeInsets.all(14),
                    child: Padding(
                      padding: EdgeInsets.zero,
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
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _ItemListCard extends StatelessWidget {
  final String title;
  final String description;
  final List<PracticeItemV1> items;
  final AppController controller;
  final ValueChanged<String> onOpenItem;
  final String emptyText;

  const _ItemListCard({
    required this.title,
    required this.description,
    required this.items,
    required this.controller,
    required this.onOpenItem,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DrumSectionTitle(text: title),
            const SizedBox(height: 6),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text(emptyText)
            else
              ...items.map(
                (item) => _ProgressItemTile(
                  item: item,
                  controller: controller,
                  onOpenItem: onOpenItem,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProgressItemTile extends StatelessWidget {
  final PracticeItemV1 item;
  final AppController controller;
  final ValueChanged<String> onOpenItem;

  const _ProgressItemTile({
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.family.label} • ${controller.matrixProgressStateFor(item.id).label} • ${formatDuration(controller.totalTime(itemId: item.id))}',
                    style: Theme.of(context).textTheme.bodySmall,
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

class _FirstLightCard extends StatelessWidget {
  final String title;
  final String detail;

  const _FirstLightCard({required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DrumSectionTitle(text: title),
            const SizedBox(height: 8),
            Text(detail, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
