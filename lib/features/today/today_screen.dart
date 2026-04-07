import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../state/app_controller.dart';
import '../practice/widgets/pattern_display_text.dart';

class TodayScreen extends StatelessWidget {
  final AppController controller;
  final VoidCallback onOpenMatrix;
  final VoidCallback onOpenFocus;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;
  final void Function(String, PracticeModeV1) onPracticeItemInMode;

  const TodayScreen({
    super.key,
    required this.controller,
    required this.onOpenMatrix,
    required this.onOpenFocus,
    required this.onOpenItem,
    required this.onPracticeItem,
    required this.onPracticeItemInMode,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final TodayBriefingV1 briefing = controller.buildTodayBriefing();
        final bool hasPracticeData = controller.hasLoggedPractice;

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFFF7E8C7), Color(0xFFF3F1EA)],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: hasPracticeData
                ? <Widget>[
                    _TodayHero(
                      headline: briefing.headline,
                      summary: briefing.summary,
                      onOpenMatrix: onOpenMatrix,
                    ),
                    const SizedBox(height: 16),
                    _TodaySection(
                      title: 'Teaching Lanes',
                      child: Column(
                        children: briefing.laneRecommendations
                            .map(
                              (recommendation) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _LaneCard(
                                  recommendation: recommendation,
                                  controller: controller,
                                  onOpenItem: onOpenItem,
                                  onPracticeItem: onPracticeItem,
                                  onPracticeItemInMode: onPracticeItemInMode,
                                  onOpenMatrix: onOpenMatrix,
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _TodaySection(
                      title: 'Momentum',
                      child: Column(
                        children: briefing.momentumRecommendations
                            .map(
                              (recommendation) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _MomentumCard(
                                  recommendation: recommendation,
                                  controller: controller,
                                  onOpenItem: onOpenItem,
                                  onPracticeItem: onPracticeItem,
                                  onOpenMatrix: onOpenMatrix,
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _TodaySection(
                      title: 'At a Glance',
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: <Widget>[
                          _ContextTile(
                            title: 'Total Time',
                            value: formatDuration(controller.totalTime()),
                            note: 'All logged practice in the app',
                          ),
                          _ContextTile(
                            title: 'Working On',
                            value: '${controller.routine.entries.length}',
                            note: 'Items in active focus',
                          ),
                          _ContextTile(
                            title: 'Sessions',
                            value: '${controller.recentSessions.length}',
                            note: 'Logged sessions so far',
                          ),
                        ],
                      ),
                    ),
                  ]
                : <Widget>[
                    _GettingStartedCoachCard(
                      controller: controller,
                      onAddToWorkingOn: () {
                        controller.addRecommendedStartingTriadsToRoutine();
                        onOpenFocus();
                      },
                      onOpenMatrix: onOpenMatrix,
                    ),
                  ],
          ),
        );
      },
    );
  }
}

class _GettingStartedCoachCard extends StatelessWidget {
  final AppController controller;
  final VoidCallback onAddToWorkingOn;
  final VoidCallback onOpenMatrix;

  const _GettingStartedCoachCard({
    required this.controller,
    required this.onAddToWorkingOn,
    required this.onOpenMatrix,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> itemIds = controller.recommendedStartingTriadItemIds;
    final bool allAdded = itemIds.every(controller.isDirectRoutineEntry);
    final ButtonStyle coachButtonStyle =
        OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE8F2EF)),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return const Color(0x33FFFFFF);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return const Color(0x22FFFFFF);
            }
            return null;
          }),
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF133E62), Color(0xFF2C6A6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Today',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFFD8E8E4),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Getting Started',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your Triad Matrix journey is just starting. We recommend that you start working on these triads. Click the button below to add these triads to your Working On practice items. You can also open the Matrix and choose your own to get started.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFFE8F2EF),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: itemIds
                  .map(
                    (itemId) => _StartingTriadChip(
                      controller: controller,
                      itemId: itemId,
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                OutlinedButton(
                  onPressed: onAddToWorkingOn,
                  style: coachButtonStyle,
                  child: Text(
                    allAdded ? 'View Working On' : 'Add to Working On',
                  ),
                ),
                OutlinedButton(
                  onPressed: onOpenMatrix,
                  style: coachButtonStyle,
                  child: const Text('Open the Matrix'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StartingTriadChip extends StatelessWidget {
  final AppController controller;
  final String itemId;

  const _StartingTriadChip({required this.controller, required this.itemId});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          controller.itemById(itemId).name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF1F2528),
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

class _TodayHero extends StatelessWidget {
  final String headline;
  final String summary;
  final VoidCallback onOpenMatrix;

  const _TodayHero({
    required this.headline,
    required this.summary,
    required this.onOpenMatrix,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF133E62), Color(0xFF2C6A6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Today',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFFD8E8E4),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              headline,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              summary,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFFE8F2EF),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onOpenMatrix,
              icon: const Icon(Icons.grid_view_rounded),
              label: const Text('Open Matrix'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF4C95D),
                foregroundColor: const Color(0xFF24323A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LaneCard extends StatelessWidget {
  final TodayLaneRecommendationV1 recommendation;
  final AppController controller;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;
  final void Function(String, PracticeModeV1) onPracticeItemInMode;
  final VoidCallback onOpenMatrix;

  const _LaneCard({
    required this.recommendation,
    required this.controller,
    required this.onOpenItem,
    required this.onPracticeItem,
    required this.onPracticeItemInMode,
    required this.onOpenMatrix,
  });

  @override
  Widget build(BuildContext context) {
    final String? featuredItemId = recommendation.itemIds.isNotEmpty
        ? recommendation.itemIds.first
        : null;

    return Card(
      elevation: 1,
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    recommendation.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              recommendation.reason,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              recommendation.evidence,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B5D42)),
            ),
            if (featuredItemId != null) ...<Widget>[
              const SizedBox(height: 12),
              _PatternActionTile(
                itemId: featuredItemId,
                controller: controller,
                onTap: () => _handlePrimaryAction(featuredItemId),
              ),
              const SizedBox(height: 12),
            ] else ...<Widget>[const SizedBox(height: 12)],
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  ActionChip(
                    label: Text(recommendation.actionLabel),
                    onPressed: featuredItemId == null
                        ? onOpenMatrix
                        : () => _handlePrimaryAction(featuredItemId),
                  ),
                  if (featuredItemId != null) ...<Widget>[
                    const SizedBox(width: 8),
                    ActionChip(
                      label: const Text('Open Item'),
                      onPressed: () => onOpenItem(featuredItemId),
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

  void _handlePrimaryAction(String itemId) {
    if (recommendation.lane == LearningLaneV1.flow) {
      onPracticeItemInMode(itemId, PracticeModeV1.flow);
      return;
    }
    if (recommendation.actionLabel == 'Open in Matrix') {
      onOpenMatrix();
      return;
    }
    onPracticeItem(itemId);
  }
}

class _MomentumCard extends StatelessWidget {
  final TodayLaneRecommendationV1 recommendation;
  final AppController controller;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;
  final VoidCallback onOpenMatrix;

  const _MomentumCard({
    required this.recommendation,
    required this.controller,
    required this.onOpenItem,
    required this.onPracticeItem,
    required this.onOpenMatrix,
  });

  @override
  Widget build(BuildContext context) {
    final String? featuredItemId = recommendation.itemIds.isNotEmpty
        ? recommendation.itemIds.first
        : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22000000)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              recommendation.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(recommendation.reason),
            const SizedBox(height: 4),
            Text(
              recommendation.evidence,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B5D42)),
            ),
            if (featuredItemId != null) ...<Widget>[
              const SizedBox(height: 10),
              _PatternActionTile(
                itemId: featuredItemId,
                controller: controller,
                onTap: () => onPracticeItem(featuredItemId),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => onOpenItem(featuredItemId),
                child: const Text('Open Item'),
              ),
            ] else ...<Widget>[
              const SizedBox(height: 10),
              TextButton(
                onPressed: onOpenMatrix,
                child: const Text('Open Matrix'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PatternActionTile extends StatelessWidget {
  final String itemId;
  final AppController controller;
  final VoidCallback onTap;

  const _PatternActionTile({
    required this.itemId,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> tokens = controller.noteTokensFor(itemId);
    final List<PatternNoteMarkingV1> markings = controller.noteMarkingsFor(
      itemId,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F0E6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x22000000)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: PatternDisplayText(
                tokens: tokens,
                markings: markings,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.play_arrow_rounded),
          ],
        ),
      ),
    );
  }
}

class _TodaySection extends StatelessWidget {
  final String title;
  final Widget child;

  const _TodaySection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ContextTile extends StatelessWidget {
  final String title;
  final String value;
  final String note;

  const _ContextTile({
    required this.title,
    required this.value,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F0E6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x22000000)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(note, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
