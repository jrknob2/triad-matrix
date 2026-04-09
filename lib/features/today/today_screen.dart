import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../state/app_controller.dart';
import '../app/drumcabulary_ui.dart';
import '../practice/widgets/pattern_display_text.dart';

typedef OpenMatrixCallback =
    void Function({LearningLaneV1? lane, Set<TriadMatrixFilterV1>? filters});

class TodayScreen extends StatelessWidget {
  final AppController controller;
  final OpenMatrixCallback onOpenMatrix;
  final VoidCallback onOpenFocus;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;
  final void Function(String, PracticeModeV1) onPracticeItemInMode;
  final ValueChanged<List<String>> onBuildComboFromItems;

  const TodayScreen({
    super.key,
    required this.controller,
    required this.onOpenMatrix,
    required this.onOpenFocus,
    required this.onOpenItem,
    required this.onPracticeItem,
    required this.onPracticeItemInMode,
    required this.onBuildComboFromItems,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final CoachBriefingV1 briefing = controller.buildCoachBriefing();
        final bool showGettingStarted =
            !controller.hasLoggedPractice && !controller.hasActiveWork;

        return DrumScreen(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: showGettingStarted
                ? <Widget>[
                    _GettingStartedCoachCard(
                      controller: controller,
                      onAddToWorkingOn: () {
                        controller.addRecommendedStartingTriadsToRoutine();
                        onOpenFocus();
                      },
                      onOpenMatrix: onOpenMatrix,
                    ),
                  ]
                : <Widget>[
                    ...briefing.blocks.map(
                      (CoachBlockV1 block) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _CoachBlockCard(
                          block: block,
                          controller: controller,
                          onOpenItem: onOpenItem,
                          onAction: () => _handleCoachBlockAction(block),
                          onOpenMatrix: _blockHasMatrixContext(block)
                              ? () => _openMatrixForBlock(block)
                              : null,
                        ),
                      ),
                    ),
                    if (briefing.blocks.isEmpty)
                      _EmptyCoachCard(onOpenMatrix: onOpenMatrix),
                  ],
          ),
        );
      },
    );
  }

  void _handleCoachBlockAction(CoachBlockV1 block) {
    switch (block.ctaAction) {
      case CoachActionV1.openMatrix:
        _openMatrixForBlock(block);
      case CoachActionV1.buildCombo:
        if (block.itemIds.isEmpty) {
          _openMatrixForBlock(block);
        } else {
          onBuildComboFromItems(block.itemIds);
        }
      case CoachActionV1.moveToFlow:
        final String? itemId = _blockPracticeItemId(
          block,
          createIfMissing: true,
        );
        if (itemId == null) {
          _openMatrixForBlock(block);
        } else {
          onPracticeItemInMode(itemId, PracticeModeV1.flow);
        }
      case CoachActionV1.startPractice:
      case CoachActionV1.resumePractice:
        final String? itemId = _blockPracticeItemId(
          block,
          createIfMissing: true,
        );
        if (itemId == null) {
          _openMatrixForBlock(block);
        } else {
          onPracticeItemInMode(itemId, block.practiceMode);
        }
    }
  }

  void _openMatrixForBlock(CoachBlockV1 block) {
    onOpenMatrix(filters: block.matrixFilters);
  }

  bool _blockHasMatrixContext(CoachBlockV1 block) {
    return block.matrixFilters.isNotEmpty;
  }

  String? _blockPracticeItemId(
    CoachBlockV1 block, {
    required bool createIfMissing,
  }) {
    if (block.itemIds.isEmpty) return null;
    if (block.itemIds.length == 1) return block.itemIds.first;
    final PracticeCombinationV1? existing = controller
        .combinationForItemIdsOrNull(block.itemIds);
    if (existing != null) return existing.id;
    if (!createIfMissing) return null;
    return controller.createCombination(itemIds: block.itemIds).id;
  }
}

class _EmptyCoachCard extends StatelessWidget {
  final OpenMatrixCallback onOpenMatrix;

  const _EmptyCoachCard({required this.onOpenMatrix});

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const DrumSectionTitle(text: 'Coach'),
            const SizedBox(height: 8),
            const Text(
              'Start from Matrix or Practice. After a few tracked sessions, Coach will have something more specific to point to.',
            ),
            const SizedBox(height: 14),
            DrumActionRow(
              children: <Widget>[
                FilledButton(
                  onPressed: () => onOpenMatrix(),
                  child: const Text('Open Matrix'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachBlockCard extends StatelessWidget {
  final CoachBlockV1 block;
  final AppController controller;
  final ValueChanged<String> onOpenItem;
  final VoidCallback onAction;
  final VoidCallback? onOpenMatrix;

  const _CoachBlockCard({
    required this.block,
    required this.controller,
    required this.onOpenItem,
    required this.onAction,
    required this.onOpenMatrix,
  });

  @override
  Widget build(BuildContext context) {
    final bool prominent = block.type == CoachBlockTypeV1.focus;
    final ButtonStyle? primaryButtonStyle = prominent
        ? FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFFF4DE),
            foregroundColor: const Color(0xFF17130F),
            side: const BorderSide(color: Color(0xFFFFC08D), width: 1.5),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) {
                return const Color(0x2217130F);
              }
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)) {
                return const Color(0x14F05A28);
              }
              return null;
            }),
          )
        : null;

    return DrumPanel(
      tone: prominent ? DrumPanelTone.dark : DrumPanelTone.surface,
      padding: const EdgeInsets.all(18),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (block.subtitle != null) ...<Widget>[
              DrumEyebrow(
                text: block.subtitle!,
                color: prominent ? const Color(0xFFF0C35B) : null,
              ),
              const SizedBox(height: 10),
            ],
            Text(
              block.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: prominent ? const Color(0xFFFFF4DE) : null,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            if (block.body != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                block.body!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: prominent ? const Color(0xFFD3C6AD) : null,
                  height: 1.35,
                ),
              ),
            ],
            if (block.itemIds.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              _CoachPatternStrip(
                itemIds: block.itemIds,
                controller: controller,
                prominent: prominent,
                onOpenItem: onOpenItem,
              ),
            ],
            const SizedBox(height: 16),
            DrumActionRow(
              children: <Widget>[
                FilledButton(
                  style: primaryButtonStyle,
                  onPressed: onAction,
                  child: Text(block.ctaLabel),
                ),
                if (onOpenMatrix != null)
                  OutlinedButton(
                    onPressed: onOpenMatrix,
                    child: const Text('See in Matrix'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachPatternStrip extends StatelessWidget {
  final List<String> itemIds;
  final AppController controller;
  final bool prominent;
  final ValueChanged<String> onOpenItem;

  const _CoachPatternStrip({
    required this.itemIds,
    required this.controller,
    required this.prominent,
    required this.onOpenItem,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: itemIds
          .map(
            (String itemId) => InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onOpenItem(itemId),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: prominent
                      ? const Color(0xFFFBF4E7)
                      : const Color(0xFFF5F0E6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD8C8B0)),
                ),
                child: PatternDisplayText(
                  tokens: controller.noteTokensFor(itemId),
                  markings: controller.noteMarkingsFor(itemId),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _GettingStartedCoachCard extends StatelessWidget {
  final AppController controller;
  final VoidCallback onAddToWorkingOn;
  final OpenMatrixCallback onOpenMatrix;

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
              'Coach',
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
              'Start with these four triads. Put them in Working On, then repeat them smoothly with no gap back to the beginning. Or open the Matrix and choose your own.',
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
                    allAdded ? 'Open Working On' : 'Add to Working On',
                  ),
                ),
                OutlinedButton(
                  onPressed: () => onOpenMatrix(),
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
    return DrumTag(
      backgroundColor: const Color(0xFFF5F0E6),
      borderColor: const Color(0xFFD8C8B0),
      child: Text(
        controller.itemById(itemId).name,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: const Color(0xFF1F2528),
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
