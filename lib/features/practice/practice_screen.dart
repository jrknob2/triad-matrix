import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../state/app_controller.dart';
import '../app/app_formatters.dart';
import '../app/drumcabulary_theme.dart';
import '../app/app_viewport.dart';
import '../app/drumcabulary_ui.dart';
import 'widgets/practice_item_summary_block.dart';

class PracticeScreen extends StatefulWidget {
  final AppController controller;
  final ValueChanged<PracticeSessionLogV1> onRepeatPreviousSession;
  final VoidCallback onPracticeWarmup;
  final void Function(List<String>, PracticeModeV1) onStartWorkingOnSession;
  final VoidCallback onOpenMatrix;

  const PracticeScreen({
    super.key,
    required this.controller,
    required this.onRepeatPreviousSession,
    required this.onPracticeWarmup,
    required this.onStartWorkingOnSession,
    required this.onOpenMatrix,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

enum _PracticeSource { workingOn, previousSessions }

class _PracticeScreenState extends State<PracticeScreen> {
  _PracticeSource _selectedSource = _PracticeSource.workingOn;
  DrumSubdivision _practiceSubdivision = DrumSubdivision.eight;
  bool _loopEnabled = false;
  int _tempoStart = 70;
  int _tempoStep = 10;
  int _tempoMax = 110;
  int _visiblePreviousSessionCount = 5;
  int _visibleWorkingOnItemCount = 5;
  String _previousSessionQuery = '';
  late final TextEditingController _previousSessionSearchController;
  List<String> _selectedItemIds = <String>[];
  Set<WorkingOnSessionFilterV1> _filters = <WorkingOnSessionFilterV1>{};

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
        final List<String> selectedItemIds = _selectedItemIds
            .where(workingOnIds.contains)
            .toList(growable: false);
        final List<PracticeItemV1> visibleItems = widget.controller
            .activeWorkItemsForSessionFilters(_filters);
        final PracticeModeV1 effectivePracticeMode = widget.controller
            .displayPracticeModeForItemIds(selectedItemIds);
        final bool canStart = selectedItemIds.isNotEmpty;
        final bool broadRotation = workingOn.length > 8;

        void selectSource(_PracticeSource source) {
          setState(() {
            _selectedSource = source;
            if (source == _PracticeSource.workingOn) {
              _visibleWorkingOnItemCount = 5;
            } else {
              _visiblePreviousSessionCount = 5;
            }
          });
        }

        final Widget sourcePane = _PracticeSourcePane(
          selectedSource: _selectedSource,
          onSelectWorkingOn: () => selectSource(_PracticeSource.workingOn),
          onSelectPreviousSessions: () =>
              selectSource(_PracticeSource.previousSessions),
          onWarmup: widget.onPracticeWarmup,
        );

        Widget workingOnPane() {
          if (workingOn.isEmpty) {
            return _PracticeSourceEmptyPane(
              title: 'From Working On',
              message: 'Nothing is in Working On yet. Add a few items first.',
              actionLabel: 'Open Matrix',
              onAction: widget.onOpenMatrix,
            );
          }
          return _WorkingOnSessionSetup(
            controller: widget.controller,
            visibleItems: visibleItems,
            selectedItemIds: selectedItemIds,
            filters: _filters,
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
                  _selectedItemIds = <String>[..._selectedItemIds]
                    ..remove(itemId);
                } else {
                  _selectedItemIds = <String>[..._selectedItemIds, itemId];
                }
              });
            },
            onSelectVisible: visibleItems.isEmpty
                ? null
                : () => setState(() {
                    _selectedItemIds = <String>[
                      ..._selectedItemIds,
                      for (final PracticeItemV1 item in visibleItems)
                        if (!_selectedItemIds.contains(item.id)) item.id,
                    ];
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
                    _selectedItemIds = <String>[];
                  }),
            onStart: canStart
                ? () => widget.onStartWorkingOnSession(
                    selectedItemIds,
                    effectivePracticeMode,
                  )
                : null,
          );
        }

        Widget previousSessionsPane() {
          if (recentSessions.isEmpty) {
            return _PracticeSourceEmptyPane(
              title: 'From Practice Sessions',
              message:
                  'No tracked session yet. Start from Working On first, then previous sessions will appear here.',
              actionLabel: workingOn.isEmpty
                  ? 'Open Matrix'
                  : 'From Working On',
              onAction: workingOn.isEmpty
                  ? widget.onOpenMatrix
                  : () => selectSource(_PracticeSource.workingOn),
            );
          }
          return _PreviousSessionBrowser(
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
          );
        }

        final Widget activePane =
            _selectedSource == _PracticeSource.previousSessions
            ? previousSessionsPane()
            : workingOnPane();
        final Widget practiceContextPane = _PracticeContextPane(
          subdivision: _practiceSubdivision,
          loopEnabled: _loopEnabled,
          tempoStart: _tempoStart,
          tempoStep: _tempoStep,
          tempoMax: _tempoMax,
          onSubdivisionChanged: (DrumSubdivision value) {
            setState(() => _practiceSubdivision = value);
          },
          onLoopChanged: (bool value) {
            setState(() => _loopEnabled = value);
          },
          onTempoStartChanged: (int value) {
            setState(() => _tempoStart = value.clamp(1, 320));
          },
          onTempoStepChanged: (int value) {
            setState(() => _tempoStep = value.clamp(1, 80));
          },
          onTempoMaxChanged: (int value) {
            setState(() => _tempoMax = value.clamp(_tempoStart, 360));
          },
        );
        const Widget grooveAndFlowPane = _GrooveAndFlowPane();

        if (isTablet) {
          return DrumScreen(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 360,
                    child: ListView(children: <Widget>[sourcePane]),
                  ),
                  const SizedBox(width: AppViewport.splitPaneGap),
                  Expanded(
                    child: ListView(
                      children: <Widget>[
                        activePane,
                        const SizedBox(height: 14),
                        practiceContextPane,
                        const SizedBox(height: 14),
                        grooveAndFlowPane,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return DrumScreen(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: <Widget>[
              sourcePane,
              const SizedBox(height: 14),
              activePane,
              const SizedBox(height: 14),
              practiceContextPane,
              const SizedBox(height: 14),
              grooveAndFlowPane,
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

class _PracticeContextPane extends StatelessWidget {
  final DrumSubdivision subdivision;
  final bool loopEnabled;
  final int tempoStart;
  final int tempoStep;
  final int tempoMax;
  final ValueChanged<DrumSubdivision> onSubdivisionChanged;
  final ValueChanged<bool> onLoopChanged;
  final ValueChanged<int> onTempoStartChanged;
  final ValueChanged<int> onTempoStepChanged;
  final ValueChanged<int> onTempoMaxChanged;

  const _PracticeContextPane({
    required this.subdivision,
    required this.loopEnabled,
    required this.tempoStart,
    required this.tempoStep,
    required this.tempoMax,
    required this.onSubdivisionChanged,
    required this.onLoopChanged,
    required this.onTempoStartChanged,
    required this.onTempoStepChanged,
    required this.onTempoMaxChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const DrumSectionTitle(text: 'Practice Context'),
          const SizedBox(height: 8),
          Text(
            'These settings describe how to work the selected patterns. They do not edit the saved pattern text.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: DrumcabularyTheme.mutedInk,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<DrumSubdivision>(
            initialValue: subdivision,
            decoration: const InputDecoration(
              labelText: 'Subdivision',
              border: OutlineInputBorder(),
            ),
            items: const <DropdownMenuItem<DrumSubdivision>>[
              DropdownMenuItem<DrumSubdivision>(
                value: DrumSubdivision.eight,
                child: Text('8'),
              ),
              DropdownMenuItem<DrumSubdivision>(
                value: DrumSubdivision.triplet,
                child: Text('Triplet'),
              ),
              DropdownMenuItem<DrumSubdivision>(
                value: DrumSubdivision.sixteen,
                child: Text('16'),
              ),
            ],
            onChanged: (DrumSubdivision? value) {
              if (value != null) onSubdivisionChanged(value);
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Loop selected practice setup'),
            value: loopEnabled,
            onChanged: onLoopChanged,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _TempoNumberField(
                label: 'Start',
                value: tempoStart,
                onChanged: onTempoStartChanged,
              ),
              _TempoNumberField(
                label: 'Step',
                value: tempoStep,
                onChanged: onTempoStepChanged,
              ),
              _TempoNumberField(
                label: 'Max',
                value: tempoMax,
                onChanged: onTempoMaxChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TempoNumberField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _TempoNumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: TextFormField(
        initialValue: '$value',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        onChanged: (String text) {
          final int? parsed = int.tryParse(text);
          if (parsed != null) onChanged(parsed);
        },
      ),
    );
  }
}

class _GrooveAndFlowPane extends StatelessWidget {
  const _GrooveAndFlowPane();

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const DrumSectionTitle(text: 'Groove and Flow'),
          const SizedBox(height: 8),
          Text(
            'Groove context and flow steps belong here on the Practice screen. The next pass can wire this panel to saved pattern roles and ordered flow steps without mutating library patterns.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: DrumcabularyTheme.mutedInk,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeSourcePane extends StatelessWidget {
  final _PracticeSource selectedSource;
  final VoidCallback onSelectWorkingOn;
  final VoidCallback onSelectPreviousSessions;
  final VoidCallback onWarmup;

  const _PracticeSourcePane({
    required this.selectedSource,
    required this.onSelectWorkingOn,
    required this.onSelectPreviousSessions,
    required this.onWarmup,
  });

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      tone: DrumPanelTone.warm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const DrumSectionTitle(text: 'Practice'),
          const SizedBox(height: 8),
          Text(
            'Choose where today\'s material comes from.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: DrumcabularyTheme.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          DrumHorizontalControlStrip(
            child: Row(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: DrumSelectablePill(
                    label: const Text('From Working On'),
                    selected: selectedSource == _PracticeSource.workingOn,
                    onPressed: onSelectWorkingOn,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: DrumSelectablePill(
                    label: const Text('From Practice Sessions'),
                    selected:
                        selectedSource == _PracticeSource.previousSessions,
                    onPressed: onSelectPreviousSessions,
                  ),
                ),
                DrumSelectablePill(
                  label: const Text('Warmup'),
                  selected: false,
                  onPressed: onWarmup,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeSourceEmptyPane extends StatelessWidget {
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _PracticeSourceEmptyPane({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DrumSectionTitle(text: title),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: DrumcabularyTheme.mutedInk,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
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
                color: DrumcabularyTheme.mutedInk,
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
                color: DrumcabularyTheme.mutedInk,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (sessions.isEmpty)
              Text(
                'No recent sessions match that search.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DrumcabularyTheme.mutedInk,
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
                        '${formatShortDate(session.endedAt)} - ${formatDuration(session.duration)}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        controller.sessionPatternSummary(session),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: DrumcabularyTheme.ink,
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
  final bool broadRotation;
  final ValueChanged<WorkingOnSessionFilterV1> onToggleFilter;
  final ValueChanged<String> onToggleItem;
  final VoidCallback? onSelectVisible;
  final VoidCallback? onShowMore;
  final VoidCallback? onClearSelection;
  final VoidCallback? onStart;

  const _WorkingOnSessionSetup({
    required this.controller,
    required this.visibleItems,
    required this.visibleItemCount,
    required this.selectedItemIds,
    required this.filters,
    required this.broadRotation,
    required this.onToggleFilter,
    required this.onToggleItem,
    required this.onSelectVisible,
    required this.onShowMore,
    required this.onClearSelection,
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
                color: DrumcabularyTheme.mutedInk,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            const DrumEyebrow(text: 'Filters'),
            const SizedBox(height: 8),
            DrumHorizontalControlStrip(
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
            const DrumEyebrow(text: 'Actions'),
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
                if (selectedCount > 0)
                  DrumActionPill(
                    prominent: true,
                    onPressed: onStart,
                    label: Text(
                      selectedCount == 1
                          ? 'Practice 1 Item'
                          : 'Practice $selectedCount Items',
                    ),
                  ),
              ],
            ),
            if (sessionIsLarge) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                'This is a big session. Pick 3 or 4 if you want cleaner reps.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DrumcabularyTheme.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (broadRotation) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Working On is broad right now. Keep today\'s slice small.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DrumcabularyTheme.mutedInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 14),
            const DrumEyebrow(text: 'Items'),
            const SizedBox(height: 8),
            if (visibleItems.isEmpty)
              Text(
                'Nothing in Working On matches this slice.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DrumcabularyTheme.mutedInk,
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
              color: selected ? DrumcabularyTheme.ink : const Color(0xFFE2D8C6),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? DrumcabularyTheme.ink : null,
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
  return parts.join(' - ');
}
