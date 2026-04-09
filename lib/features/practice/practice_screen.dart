import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../state/app_controller.dart';
import '../app/app_formatters.dart';
import '../app/drumcabulary_ui.dart';
import 'widgets/pattern_display_text.dart';

class PracticeScreen extends StatelessWidget {
  final AppController controller;
  final VoidCallback onRepeatLastSession;
  final ValueChanged<PracticeModeV1> onPracticeWorkingOn;
  final VoidCallback onPracticeWarmup;
  final void Function(String, PracticeModeV1) onPracticeItemInMode;
  final VoidCallback onOpenMatrix;
  final VoidCallback onOpenFocus;

  const PracticeScreen({
    super.key,
    required this.controller,
    required this.onRepeatLastSession,
    required this.onPracticeWorkingOn,
    required this.onPracticeWarmup,
    required this.onPracticeItemInMode,
    required this.onOpenMatrix,
    required this.onOpenFocus,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final PracticeSessionLogV1? lastSession = controller.lastTrackedSession;
        final List<PracticeItemV1> workingOn = controller.activeWorkItems;
        final bool hasFlowWorkingOn = workingOn.any(
          (PracticeItemV1 item) => controller.hasNonSnareVoice(item.id),
        );

        return DrumScreen(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: <Widget>[
              DrumPanel(
                tone: DrumPanelTone.warm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const DrumSectionTitle(text: 'Start Practice'),
                    const SizedBox(height: 8),
                    Text(
                      'Use this screen to jump straight into playing. Choose a source and start.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5B5345),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PracticeLaunchTile(
                      title: 'Repeat Last Session',
                      subtitle: lastSession == null
                          ? 'No tracked session yet.'
                          : '${lastSession.practiceMode.label} • ${formatShortDate(lastSession.endedAt)} • ${formatDuration(lastSession.duration)}',
                      icon: Icons.replay_rounded,
                      enabled: lastSession != null,
                      onTap: lastSession == null ? null : onRepeatLastSession,
                    ),
                    const SizedBox(height: 10),
                    _PracticeLaunchTile(
                      title: 'Practice Working On',
                      subtitle: workingOn.isEmpty
                          ? 'Add a few items to Working On first.'
                          : '${workingOn.length} active item${workingOn.length == 1 ? '' : 's'} ready to go.',
                      icon: Icons.play_circle_outline_rounded,
                      enabled: workingOn.isNotEmpty,
                      onTap: workingOn.isEmpty
                          ? null
                          : () => onPracticeWorkingOn(
                              PracticeModeV1.singleSurface,
                            ),
                    ),
                    if (hasFlowWorkingOn) ...<Widget>[
                      const SizedBox(height: 10),
                      _PracticeLaunchTile(
                        title: 'Practice Working On in Flow',
                        subtitle:
                            'Start the flow-ready items in your current working set.',
                        icon: Icons.alt_route_rounded,
                        enabled: true,
                        onTap: () => onPracticeWorkingOn(PracticeModeV1.flow),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _PracticeLaunchTile(
                      title: 'Warm Up',
                      subtitle:
                          'Run the built-in rudiment deck without logging it.',
                      icon: Icons.local_fire_department_outlined,
                      enabled: true,
                      onTap: onPracticeWarmup,
                    ),
                    if (workingOn.isEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      DrumActionRow(
                        children: <Widget>[
                          OutlinedButton(
                            onPressed: onOpenMatrix,
                            child: const Text('Open Matrix'),
                          ),
                          OutlinedButton(
                            onPressed: onOpenFocus,
                            child: const Text('Open Focus'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DrumPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const DrumSectionTitle(text: 'Choose From Working On'),
                    const SizedBox(height: 8),
                    Text(
                      workingOn.isEmpty
                          ? 'There is nothing in Working On yet. Add a few items from Coach or Matrix, then start here.'
                          : 'Pick one item directly when you know exactly what you want to work on.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5E584D),
                        height: 1.35,
                      ),
                    ),
                    if (workingOn.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      ...workingOn.map(
                        (PracticeItemV1 item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _WorkingOnPracticeRow(
                            controller: controller,
                            item: item,
                            onPracticeItemInMode: onPracticeItemInMode,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PracticeLaunchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _PracticeLaunchTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color muted = enabled
        ? const Color(0xFF61584A)
        : const Color(0xFF9C9284);
    return Material(
      color: enabled ? const Color(0xFFFFFCF5) : const Color(0xFFF3EDE1),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Icon(icon, color: enabled ? null : muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: enabled ? null : muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: muted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.arrow_forward_rounded, color: enabled ? null : muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkingOnPracticeRow extends StatelessWidget {
  final AppController controller;
  final PracticeItemV1 item;
  final void Function(String, PracticeModeV1) onPracticeItemInMode;

  const _WorkingOnPracticeRow({
    required this.controller,
    required this.item,
    required this.onPracticeItemInMode,
  });

  @override
  Widget build(BuildContext context) {
    final bool flowReady = controller.hasNonSnareVoice(item.id);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2D8C6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  PatternDisplayText(
                    tokens: controller.noteTokensFor(item.id),
                    markings: controller.noteMarkingsFor(item.id),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                    grouping: controller.displayGroupingFor(item.id),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.family.label} • ${controller.matrixProgressStateFor(item.id).label}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6A5E4C),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              onPressed: () =>
                  onPracticeItemInMode(item.id, PracticeModeV1.singleSurface),
              icon: const Icon(Icons.play_arrow_rounded),
              tooltip: 'Practice ${item.name}',
            ),
            if (flowReady) ...<Widget>[
              const SizedBox(width: 6),
              IconButton(
                onPressed: () =>
                    onPracticeItemInMode(item.id, PracticeModeV1.flow),
                icon: const Icon(Icons.alt_route_rounded),
                tooltip: 'Practice ${item.name} in Flow',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
