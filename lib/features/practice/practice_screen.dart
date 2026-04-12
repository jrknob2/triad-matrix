import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../state/app_controller.dart';
import '../app/app_formatters.dart';
import '../app/app_viewport.dart';
import '../app/drumcabulary_ui.dart';
import 'widgets/practice_item_summary_block.dart';

class PracticeScreen extends StatefulWidget {
  final AppController controller;
  final ValueChanged<PracticeSessionLogV1> onRepeatPreviousSession;
  final VoidCallback onPracticeWarmup;
  final void Function(List<String>, PracticeModeV1) onStartWorkingOnSession;
  final VoidCallback onOpenMatrix;
  final VoidCallback onOpenFocus;

  const PracticeScreen({
    super.key,
    required this.controller,
    required this.onRepeatPreviousSession,
    required this.onPracticeWarmup,
    required this.onStartWorkingOnSession,
    required this.onOpenMatrix,
    required this.onOpenFocus,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  bool _showWorkingOnSetup = false;
  bool _showPreviousSessionBrowser = false;
  int _visiblePreviousSessionCount = 5;
  int _visibleWorkingOnItemCount = 5;
  String _previousSessionQuery = '';
  late final TextEditingController _previousSessionSearchController;
  Set<String> _selectedItemIds = <String>{};
  Set<WorkingOnSessionFilterV1> _filters = <WorkingOnSessionFilterV1>{};
  PracticeModeV1 _practiceMode = PracticeModeV1.singleSurface;

  @override
  void initState() {
    super.initState();
    _previousSessionSearchController = TextEditingController();
  }

  @override
  void dispose() {
    _previousSessionSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        final bool isTablet = AppViewport.isTablet(context);
        final List<PracticeSessionLogV1> recentSessions =
            widget.controller.trackedRecentSessions;
        final List<PracticeSessionLogV1> filteredRecentSessions =
            _previousSessionQuery.trim().isEmpty
            ? recentSessions
            : recentSessions
                  .where((PracticeSessionLogV1 session) {
                    return widget.controller
                        .sessionSearchText(session)
                        .contains(_previousSessionQuery.trim().toLowerCase());
                  })
                  .toList(growable: false);
        final List<PracticeItemV1> workingOn =
            widget.controller.activeWorkItems;
        final List<String> workingOnIds = workingOn
            .map((PracticeItemV1 item) => item.id)
            .toList(growable: false);
        final List<String> selectedItemIds = workingOnIds
            .where(_selectedItemIds.contains)
            .toList(growable: false);
        final List<PracticeItemV1> visibleItems = widget.controller
            .activeWorkItemsForSessionFilters(_filters);
        final Set<String> visibleIds = visibleItems
            .map((PracticeItemV1 item) => item.id)
            .toSet();
        final bool canFlowSelection =
            selectedItemIds.isNotEmpty &&
            selectedItemIds.every(widget.controller.hasNonSnareVoice);
        final PracticeModeV1 effectivePracticeMode =
            _practiceMode == PracticeModeV1.flow && !canFlowSelection
            ? PracticeModeV1.singleSurface
            : _practiceMode;
        final bool canStart = selectedItemIds.isNotEmpty;
        final bool broadRotation = workingOn.length > 8;

        final Widget launchPane = DrumPanel(
          tone: DrumPanelTone.warm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const DrumSectionTitle(text: 'Practice'),
              const SizedBox(height: 8),
              Text(
                'Choose your material, then start.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5B5345),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              _PracticeLaunchTile(
                title: 'Repeat a Previous Session',
                subtitle: recentSessions.isEmpty
                    ? 'No tracked session yet.'
                    : 'Pick from your recent tracked sessions.',
                icon: Icons.replay_rounded,
                enabled: recentSessions.isNotEmpty,
                onTap: recentSessions.isEmpty
                    ? null
                    : () => setState(() {
                        _showPreviousSessionBrowser =
                            !_showPreviousSessionBrowser;
                        if (_showPreviousSessionBrowser) {
                          _showWorkingOnSetup = false;
                        }
                      }),
                trailing: Icon(
                  _showPreviousSessionBrowser
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
              ),
              const SizedBox(height: 10),
              _PracticeLaunchTile(
                title: 'Choose Patterns to Practice',
                subtitle: workingOn.isEmpty
                    ? 'Put a few items in Working On first.'
                    : _showWorkingOnSetup
                    ? 'Pick today\'s slice from Working On.'
                    : 'Choose what you want to work on from Working On.',
                icon: Icons.play_circle_outline_rounded,
                enabled: workingOn.isNotEmpty,
                onTap: workingOn.isEmpty
                    ? null
                    : () => setState(() {
                        _showWorkingOnSetup = !_showWorkingOnSetup;
                        if (_showWorkingOnSetup) {
                          _showPreviousSessionBrowser = false;
                          _visibleWorkingOnItemCount = 5;
                        }
                      }),
                trailing: Icon(
                  _showWorkingOnSetup
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
              ),
              const SizedBox(height: 10),
              _PracticeLaunchTile(
                title: 'Warm Up',
                subtitle:
                    'Singles, doubles, paradiddles, and paradiddle-diddles. Not logged.',
                icon: Icons.local_fire_department_outlined,
                enabled: true,
                onTap: widget.onPracticeWarmup,
              ),
              if (workingOn.isEmpty) ...<Widget>[
                const SizedBox(height: 14),
                DrumActionRow(
                  children: <Widget>[
                    OutlinedButton(
                      onPressed: widget.onOpenMatrix,
                      child: const Text('Open Matrix'),
                    ),
                    OutlinedButton(
                      onPressed: widget.onOpenFocus,
                      child: const Text('Open Working On'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );

        final Widget activePane =
            _showPreviousSessionBrowser && recentSessions.isNotEmpty
            ? _PreviousSessionBrowser(
                controller: widget.controller,
                searchController: _previousSessionSearchController,
                onQueryChanged: (String value) => setState(() {
                  _previousSessionQuery = value;
                  _visiblePreviousSessionCount = 5;
                }),
                totalCount: filteredRecentSessions.length,
                sessions: filteredRecentSessions
                    .take(_visiblePreviousSessionCount)
                    .toList(growable: false),
                onLoadMore: () => setState(() {
                  _visiblePreviousSessionCount += 5;
                }),
                onRepeatSession: widget.onRepeatPreviousSession,
              )
            : _showWorkingOnSetup && workingOn.isNotEmpty
            ? _WorkingOnSessionSetup(
                controller: widget.controller,
                visibleItems: visibleItems,
                selectedItemIds: selectedItemIds,
                filters: _filters,
                practiceMode: effectivePracticeMode,
                canFlowSelection: canFlowSelection,
                broadRotation: broadRotation,
                onToggleFilter: (WorkingOnSessionFilterV1 filter) {
                  setState(() {
                    _filters = _toggleFilter(_filters, filter);
                    _visibleWorkingOnItemCount = 5;
                  });
                },
                onToggleItem: (String itemId) {
                  setState(() {
                    if (_selectedItemIds.contains(itemId)) {
                      _selectedItemIds = <String>{..._selectedItemIds}
                        ..remove(itemId);
                    } else {
                      _selectedItemIds = <String>{..._selectedItemIds, itemId};
                    }
                  });
                },
                onSelectVisible: visibleItems.isEmpty
                    ? null
                    : () => setState(() {
                        _selectedItemIds = <String>{
                          ..._selectedItemIds,
                          ...visibleIds,
                        };
                      }),
                visibleItemCount: _visibleWorkingOnItemCount,
                onShowMore: visibleItems.length > _visibleWorkingOnItemCount
                    ? () => setState(() {
                        _visibleWorkingOnItemCount += 5;
                      })
                    : null,
                onClearSelection: _selectedItemIds.isEmpty
                    ? null
                    : () => setState(() {
                        _selectedItemIds = <String>{};
                      }),
                onSetPracticeMode: (PracticeModeV1 mode) {
                  if (mode == PracticeModeV1.flow && !canFlowSelection) {
                    return;
                  }
                  setState(() => _practiceMode = mode);
                },
                onStart: canStart
                    ? () => widget.onStartWorkingOnSession(
                        selectedItemIds,
                        effectivePracticeMode,
                      )
                    : null,
              )
            : DrumPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const DrumSectionTitle(text: 'Session Setup'),
                    const SizedBox(height: 8),
                    Text(
                      workingOn.isEmpty
                          ? 'Add items to Working On, then choose a practice source.'
                          : 'Choose a source on the left. On iPad the browser or setup stays here so you can keep both in view.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5E584D),
                        height: 1.35,
                      ),
                    ),
                    if (workingOn.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      Text(
                        '${workingOn.length} items in Working On',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ],
                ),
              );

        if (isTablet) {
          return DrumScreen(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 360,
                    child: ListView(children: <Widget>[launchPane]),
                  ),
                  const SizedBox(width: AppViewport.splitPaneGap),
                  Expanded(child: ListView(children: <Widget>[activePane])),
                ],
              ),
            ),
          );
        }

        return DrumScreen(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: <Widget>[
              DrumPanel(
                tone: DrumPanelTone.warm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const DrumSectionTitle(text: 'Practice'),
                    const SizedBox(height: 8),
                    Text(
                      'Choose your material, then start.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5B5345),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PracticeLaunchTile(
                      title: 'Repeat a Previous Session',
                      subtitle: recentSessions.isEmpty
                          ? 'No tracked session yet.'
                          : 'Pick from your recent tracked sessions.',
                      icon: Icons.replay_rounded,
                      enabled: recentSessions.isNotEmpty,
                      onTap: recentSessions.isEmpty
                          ? null
                          : () => setState(() {
                              _showPreviousSessionBrowser =
                                  !_showPreviousSessionBrowser;
                              if (_showPreviousSessionBrowser) {
                                _showWorkingOnSetup = false;
                              }
                            }),
                      trailing: Icon(
                        _showPreviousSessionBrowser
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                      ),
                    ),
                    if (_showPreviousSessionBrowser &&
                        recentSessions.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      _PreviousSessionBrowser(
                        controller: widget.controller,
                        searchController: _previousSessionSearchController,
                        onQueryChanged: (String value) => setState(() {
                          _previousSessionQuery = value;
                          _visiblePreviousSessionCount = 5;
                        }),
                        totalCount: filteredRecentSessions.length,
                        sessions: filteredRecentSessions
                            .take(_visiblePreviousSessionCount)
                            .toList(growable: false),
                        onLoadMore: () => setState(() {
                          _visiblePreviousSessionCount += 5;
                        }),
                        onRepeatSession: widget.onRepeatPreviousSession,
                      ),
                    ],
                    const SizedBox(height: 10),
                    _PracticeLaunchTile(
                      title: 'Choose Patterns to Practice',
                      subtitle: workingOn.isEmpty
                          ? 'Put a few items in Working On first.'
                          : _showWorkingOnSetup
                          ? 'Pick today\'s slice from Working On.'
                          : 'Choose what you want to work on from Working On.',
                      icon: Icons.play_circle_outline_rounded,
                      enabled: workingOn.isNotEmpty,
                      onTap: workingOn.isEmpty
                          ? null
                          : () => setState(() {
                              _showWorkingOnSetup = !_showWorkingOnSetup;
                              if (_showWorkingOnSetup) {
                                _showPreviousSessionBrowser = false;
                                _visibleWorkingOnItemCount = 5;
                              }
                            }),
                      trailing: Icon(
                        _showWorkingOnSetup
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                      ),
                    ),
                    if (_showWorkingOnSetup &&
                        workingOn.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      _WorkingOnSessionSetup(
                        controller: widget.controller,
                        visibleItems: visibleItems,
                        selectedItemIds: selectedItemIds,
                        filters: _filters,
                        practiceMode: effectivePracticeMode,
                        canFlowSelection: canFlowSelection,
                        broadRotation: broadRotation,
                        onToggleFilter: (WorkingOnSessionFilterV1 filter) {
                          setState(() {
                            _filters = _toggleFilter(_filters, filter);
                            _visibleWorkingOnItemCount = 5;
                          });
                        },
                        onToggleItem: (String itemId) {
                          setState(() {
                            if (_selectedItemIds.contains(itemId)) {
                              _selectedItemIds = <String>{..._selectedItemIds}
                                ..remove(itemId);
                            } else {
                              _selectedItemIds = <String>{
                                ..._selectedItemIds,
                                itemId,
                              };
                            }
                          });
                        },
                        onSelectVisible: visibleItems.isEmpty
                            ? null
                            : () => setState(() {
                                _selectedItemIds = <String>{
                                  ..._selectedItemIds,
                                  ...visibleIds,
                                };
                              }),
                        visibleItemCount: _visibleWorkingOnItemCount,
                        onShowMore:
                            visibleItems.length > _visibleWorkingOnItemCount
                            ? () => setState(() {
                                _visibleWorkingOnItemCount += 5;
                              })
                            : null,
                        onClearSelection: _selectedItemIds.isEmpty
                            ? null
                            : () => setState(() {
                                _selectedItemIds = <String>{};
                              }),
                        onSetPracticeMode: (PracticeModeV1 mode) {
                          if (mode == PracticeModeV1.flow &&
                              !canFlowSelection) {
                            return;
                          }
                          setState(() => _practiceMode = mode);
                        },
                        onStart: canStart
                            ? () => widget.onStartWorkingOnSession(
                                selectedItemIds,
                                effectivePracticeMode,
                              )
                            : null,
                      ),
                    ],
                    const SizedBox(height: 10),
                    _PracticeLaunchTile(
                      title: 'Warm Up',
                      subtitle:
                          'Singles, doubles, paradiddles, and paradiddle-diddles. Not logged.',
                      icon: Icons.local_fire_department_outlined,
                      enabled: true,
                      onTap: widget.onPracticeWarmup,
                    ),
                    if (workingOn.isEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      DrumActionRow(
                        children: <Widget>[
                          OutlinedButton(
                            onPressed: widget.onOpenMatrix,
                            child: const Text('Open Matrix'),
                          ),
                          OutlinedButton(
                            onPressed: widget.onOpenFocus,
                            child: const Text('Open Working On'),
                          ),
                        ],
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

  Set<WorkingOnSessionFilterV1> _toggleFilter(
    Set<WorkingOnSessionFilterV1> current,
    WorkingOnSessionFilterV1 filter,
  ) {
    final Set<WorkingOnSessionFilterV1> next = <WorkingOnSessionFilterV1>{
      ...current,
    };
    if (next.contains(filter)) {
      next.remove(filter);
      return next;
    }

    if (filter == WorkingOnSessionFilterV1.handsOnly) {
      next.remove(WorkingOnSessionFilterV1.hasKick);
    }
    if (filter == WorkingOnSessionFilterV1.hasKick) {
      next.remove(WorkingOnSessionFilterV1.handsOnly);
    }
    if (filter == WorkingOnSessionFilterV1.needsWork ||
        filter == WorkingOnSessionFilterV1.active ||
        filter == WorkingOnSessionFilterV1.strongReview) {
      next.remove(WorkingOnSessionFilterV1.needsWork);
      next.remove(WorkingOnSessionFilterV1.active);
      next.remove(WorkingOnSessionFilterV1.strongReview);
    }

    next.add(filter);
    return next;
  }
}

class _PracticeLaunchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _PracticeLaunchTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.trailing,
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
              trailing ??
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: enabled ? null : muted,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviousSessionBrowser extends StatelessWidget {
  final AppController controller;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final int totalCount;
  final List<PracticeSessionLogV1> sessions;
  final VoidCallback onLoadMore;
  final ValueChanged<PracticeSessionLogV1> onRepeatSession;

  const _PreviousSessionBrowser({
    required this.controller,
    required this.searchController,
    required this.onQueryChanged,
    required this.totalCount,
    required this.sessions,
    required this.onLoadMore,
    required this.onRepeatSession,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3D9C8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const DrumSectionTitle(text: 'Recent Sessions'),
            const SizedBox(height: 8),
            Text(
              'Pick a session you want to repeat.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5E584D),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: searchController,
              onChanged: onQueryChanged,
              decoration: const InputDecoration(
                hintText: 'Search by pattern',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Showing ${sessions.length} of $totalCount',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF6A5E4C),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (sessions.isEmpty)
              Text(
                'No recent sessions match that search.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6A5E4C),
                ),
              ),
            ...sessions.map(
              (PracticeSessionLogV1 session) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PreviousSessionRow(
                  controller: controller,
                  session: session,
                  onTap: () => onRepeatSession(session),
                ),
              ),
            ),
            if (sessions.length < totalCount)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: onLoadMore,
                  child: const Text('Show More'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviousSessionRow extends StatelessWidget {
  final AppController controller;
  final PracticeSessionLogV1 session;
  final VoidCallback onTap;

  const _PreviousSessionRow({
    required this.controller,
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFFCF7),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2D8C6)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.history_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${formatShortDate(session.endedAt)} • ${formatDuration(session.duration)}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.practiceMode.label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6A5E4C),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        controller.sessionPatternSummary(session),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF2E2921),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.play_arrow_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkingOnSessionSetup extends StatelessWidget {
  final AppController controller;
  final List<PracticeItemV1> visibleItems;
  final int visibleItemCount;
  final List<String> selectedItemIds;
  final Set<WorkingOnSessionFilterV1> filters;
  final PracticeModeV1 practiceMode;
  final bool canFlowSelection;
  final bool broadRotation;
  final ValueChanged<WorkingOnSessionFilterV1> onToggleFilter;
  final ValueChanged<String> onToggleItem;
  final VoidCallback? onSelectVisible;
  final VoidCallback? onShowMore;
  final VoidCallback? onClearSelection;
  final ValueChanged<PracticeModeV1> onSetPracticeMode;
  final VoidCallback? onStart;

  const _WorkingOnSessionSetup({
    required this.controller,
    required this.visibleItems,
    required this.visibleItemCount,
    required this.selectedItemIds,
    required this.filters,
    required this.practiceMode,
    required this.canFlowSelection,
    required this.broadRotation,
    required this.onToggleFilter,
    required this.onToggleItem,
    required this.onSelectVisible,
    required this.onShowMore,
    required this.onClearSelection,
    required this.onSetPracticeMode,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final int selectedCount = selectedItemIds.length;
    final bool sessionIsLarge = selectedCount > 4;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3D9C8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const DrumSectionTitle(text: 'From Working On'),
            const SizedBox(height: 8),
            Text(
              'Pick today\'s slice. Keep it tight and get clean reps.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5E584D),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            const DrumEyebrow(text: 'Filters'),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: WorkingOnSessionFilterV1.values
                    .map(
                      (WorkingOnSessionFilterV1 filter) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: DrumSelectablePill(
                          label: Text(filter.label),
                          selected: filters.contains(filter),
                          onPressed: () => onToggleFilter(filter),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: 14),
            const DrumEyebrow(text: 'Selection'),
            const SizedBox(height: 8),
            DrumActionRow(
              spacing: 8,
              children: <Widget>[
                DrumActionPill(
                  label: const Text('Select All'),
                  onPressed: onSelectVisible,
                ),
                DrumActionPill(
                  label: const Text('Clear'),
                  onPressed: onClearSelection,
                ),
              ],
            ),
            if (sessionIsLarge) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                'This is a big session. Pick 3 or 4 if you want cleaner reps.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF855E18),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (broadRotation) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Working On is broad right now. Keep today\'s slice small.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6B6150),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 14),
            const DrumEyebrow(text: 'Mode'),
            const SizedBox(height: 8),
            DrumActionRow(
              children: <Widget>[
                DrumSelectablePill(
                  label: const Text('One Surface'),
                  selected: practiceMode == PracticeModeV1.singleSurface,
                  onPressed: () =>
                      onSetPracticeMode(PracticeModeV1.singleSurface),
                ),
                DrumSelectablePill(
                  label: const Text('Flow'),
                  selected: practiceMode == PracticeModeV1.flow,
                  onPressed: canFlowSelection
                      ? () => onSetPracticeMode(PracticeModeV1.flow)
                      : null,
                ),
              ],
            ),
            if (!canFlowSelection) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Flow needs voice-assigned items.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6A5E4C)),
              ),
            ],
            const SizedBox(height: 14),
            const DrumEyebrow(text: 'Items'),
            const SizedBox(height: 8),
            if (visibleItems.isEmpty)
              Text(
                'Nothing in Working On matches this slice.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6A5E4C),
                ),
              )
            else
              ...visibleItems
                  .take(visibleItemCount)
                  .map(
                    (PracticeItemV1 item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SelectableWorkingOnRow(
                        controller: controller,
                        item: item,
                        selected: selectedItemIds.contains(item.id),
                        onTap: () => onToggleItem(item.id),
                      ),
                    ),
                  ),
            if (onShowMore != null)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: onShowMore,
                  child: const Text('Show More'),
                ),
              ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onStart,
                child: Text(
                  selectedCount == 1
                      ? 'Practice 1 Item'
                      : 'Practice $selectedCount Items',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectableWorkingOnRow extends StatelessWidget {
  final AppController controller;
  final PracticeItemV1 item;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableWorkingOnRow({
    required this.controller,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final MatrixProgressStateV1 status = controller.matrixProgressStateFor(
      item.id,
    );
    return Material(
      color: selected ? const Color(0xFFF4E8D0) : const Color(0xFFFFFCF7),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? const Color(0xFF2E2921)
                  : const Color(0xFFE2D8C6),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? const Color(0xFF2E2921) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PracticeItemSummaryBlock(
                    controller: controller,
                    item: item,
                    metadataLines: <String>[
                      _workingOnMetadata(controller, item, status),
                    ],
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

String _workingOnMetadata(
  AppController controller,
  PracticeItemV1 item,
  MatrixProgressStateV1 status,
) {
  final List<String> parts = <String>[status.label];
  if (controller.hasKick(item.id)) parts.add('Kick');
  if (controller.hasNonSnareVoice(item.id)) parts.add('Flow');
  if (controller.hasDoubles(item.id)) parts.add('Doubles');
  return parts.join(' • ');
}
