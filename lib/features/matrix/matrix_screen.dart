import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../features/app/drumcabulary_ui.dart';
import '../app/app_viewport.dart';
import '../../state/app_controller.dart';
import '../practice/widgets/pattern_display_text.dart';
import '../practice/widgets/pattern_sequence_editor.dart';
import 'widgets/triad_matrix_grid.dart';

enum _MatrixPrimaryView { traits, progress }

class MatrixScreenRequest {
  final int version;
  final LearningLaneV1? lane;
  final Set<TriadMatrixFilterV1> filters;
  final List<String> selectedItemIds;
  final String? editingItemId;

  const MatrixScreenRequest({
    required this.version,
    required this.lane,
    required this.filters,
    this.selectedItemIds = const <String>[],
    this.editingItemId,
  });
}

class MatrixScreen extends StatefulWidget {
  final AppController controller;
  final MatrixScreenRequest? request;
  final ValueChanged<String> onOpenItem;
  final void Function(List<String>, PracticeModeV1) onPreviewSelection;
  final ValueChanged<List<String>>? onFinishEditing;

  const MatrixScreen({
    super.key,
    required this.controller,
    required this.request,
    required this.onOpenItem,
    required this.onPreviewSelection,
    this.onFinishEditing,
  });

  @override
  State<MatrixScreen> createState() => _MatrixScreenState();
}

class _MatrixScreenState extends State<MatrixScreen> {
  _MatrixPrimaryView _view = _MatrixPrimaryView.traits;
  final Set<TriadMatrixFilterV1> _filters = <TriadMatrixFilterV1>{};
  final Set<String> _selectedRows = <String>{};
  final Set<String> _selectedColumns = <String>{};
  final List<String> _selectedItemIds = <String>[];
  int? _appliedRequestVersion;

  @override
  void initState() {
    super.initState();
    final MatrixScreenRequest? request = widget.request;
    if (request != null) {
      _appliedRequestVersion = request.version;
      _applyRequest(request);
    }
  }

  @override
  void didUpdateWidget(covariant MatrixScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final MatrixScreenRequest? request = widget.request;
    if (request == null || request.version == _appliedRequestVersion) return;
    _appliedRequestVersion = request.version;
    _applyRequest(request);
  }

  @override
  Widget build(BuildContext context) {
    final bool isTablet = AppViewport.isTablet(context);
    final MatrixFiltersV1 matrixFilters = MatrixFiltersV1(
      lane: null,
      filters: _effectiveFilters,
      selectedRows: _selectedRows,
      selectedColumns: _selectedColumns,
    );
    final MatrixSelectionStateV1 matrixSelection = MatrixSelectionStateV1(
      orderedItemIds: _selectedItemIds,
    );
    final List<String> notReadyItemIds = _selectedItemIds
        .where((String itemId) => !widget.controller.isPhraseReady(itemId))
        .toList(growable: false);

    final Widget matrixGrid = TriadMatrixGrid(
      controller: widget.controller,
      filters: matrixFilters,
      selection: matrixSelection,
      onToggleRow: _toggleRow,
      onToggleColumn: _toggleColumn,
      onTapItem: _toggleItemSelection,
    );

    final Widget phrasePanel = _MatrixPhrasePanel(
      controller: widget.controller,
      selectedItemIds: _selectedItemIds,
      onRemoveAt: _removeSelectedAt,
      actionPills: _buildActionPills(),
      showProgressLegend: _view == _MatrixPrimaryView.progress,
      warningMessage: _selectedItemIds.length > 1 && notReadyItemIds.isNotEmpty
          ? 'Some of these triads are not ready yet. You can save the phrase now, but it may be better to work on them more first.'
          : null,
    );

    return DrumScreen(
      warm: false,
      child: isTablet
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    flex: 5,
                    child: ListView(
                      children: <Widget>[
                        const DrumEyebrow(text: 'Look At'),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _MatrixPrimaryView.values
                                .map(
                                  (_MatrixPrimaryView view) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: DrumSelectablePill(
                                      label: _chipText(
                                        _viewLabel(view),
                                        _view == view,
                                      ),
                                      selected: _view == view,
                                      onPressed: () => _selectView(view),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: _buildFilterPills()),
                        ),
                        const SizedBox(height: 12),
                        matrixGrid,
                      ],
                    ),
                  ),
                  const SizedBox(width: AppViewport.splitPaneGap),
                  SizedBox(
                    width: 340,
                    child: ListView(children: <Widget>[phrasePanel]),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: <Widget>[
                const DrumEyebrow(text: 'Look At'),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _MatrixPrimaryView.values
                        .map(
                          (_MatrixPrimaryView view) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: DrumSelectablePill(
                              label: _chipText(_viewLabel(view), _view == view),
                              selected: _view == view,
                              onPressed: () => _selectView(view),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: _buildFilterPills()),
                ),
                if (_view == _MatrixPrimaryView.progress) ...<Widget>[
                  const SizedBox(height: 10),
                  const _ProgressLegendCard(),
                ],
                if (_selectedItemIds.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  phrasePanel,
                ],
                const SizedBox(height: 12),
                matrixGrid,
              ],
            ),
    );
  }

  Set<TriadMatrixFilterV1> get _effectiveFilters {
    return _normalizedFiltersForView(_view, _filters);
  }

  bool get _isPhraseBuilding => _selectedItemIds.length > 1;

  bool get _isEditingFromPracticeItem =>
      widget.request?.editingItemId != null && widget.onFinishEditing != null;

  bool get _selectionIsInRoutine {
    final String? itemId = _selectionRoutineItemId;
    return itemId != null && widget.controller.isDirectRoutineEntry(itemId);
  }

  String? get _selectionRoutineItemId {
    if (_selectedItemIds.isEmpty) return null;
    if (_selectedItemIds.length == 1) return _selectedItemIds.first;
    return widget.controller.combinationForItemIdsOrNull(_selectedItemIds)?.id;
  }

  List<Widget> _buildFilterPills() {
    final List<Widget> children = <Widget>[];
    final List<TriadMatrixFilterV1> filters = _viewFilters(_view);
    for (final TriadMatrixFilterV1 filter in filters) {
      children.add(
        Padding(
          padding: EdgeInsets.only(right: _gapAfterFilter(filter)),
          child: DrumSelectablePill(
            label: _chipText(filter.label, _filters.contains(filter)),
            selected: _filters.contains(filter),
            onPressed: () => _toggleFilter(filter),
          ),
        ),
      );
    }
    return children;
  }

  List<Widget> _buildActionPills() {
    final List<Widget> pills = <Widget>[
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: DrumActionPill(
          label: const Text('Try It Out'),
          onPressed: _isPhraseBuilding
              ? _practiceSelectionInFlow
              : _practiceSelection,
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: DrumActionPill(
          label: Text(
            _isEditingFromPracticeItem
                ? 'Back to Working On'
                : _selectionIsInRoutine
                ? 'In Working On'
                : 'Add to Working On',
          ),
          onPressed: _isEditingFromPracticeItem
              ? (_selectedItemIds.isEmpty ? null : _finishEditing)
              : _selectionIsInRoutine
              ? null
              : _addSelectionToWorkingOn,
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: DrumActionPill(
          label: const Text('Clear'),
          onPressed: () => setState(_selectedItemIds.clear),
        ),
      ),
    ];
    return pills;
  }

  Widget _chipText(String label, bool selected) {
    return Text(
      label,
      style: TextStyle(
        color: selected ? Colors.white : null,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  void _toggleRow(String rowLabel) {
    setState(() {
      if (_selectedRows.contains(rowLabel)) {
        _selectedRows.remove(rowLabel);
      } else {
        _selectedRows.add(rowLabel);
      }
    });
  }

  void _toggleColumn(String columnLabel) {
    setState(() {
      if (_selectedColumns.contains(columnLabel)) {
        _selectedColumns.remove(columnLabel);
      } else {
        _selectedColumns.add(columnLabel);
      }
    });
  }

  void _selectView(_MatrixPrimaryView view) {
    setState(() {
      if (_view == view) return;
      final Set<TriadMatrixFilterV1> previousFilters = _filters.toSet();
      _view = view;
      _filters
        ..clear()
        ..addAll(_normalizedFiltersForView(view, previousFilters));
    });
  }

  void _toggleFilter(TriadMatrixFilterV1 filter) {
    setState(() {
      final bool selected = _filters.contains(filter);
      if (_view == _MatrixPrimaryView.traits) {
        _toggleTraitFilter(filter, selected);
      } else if (_view == _MatrixPrimaryView.progress) {
        _toggleProgressFilter(filter, selected);
      } else if (selected) {
        _filters.remove(filter);
      } else {
        _filters.add(filter);
      }
    });
  }

  void _toggleTraitFilter(TriadMatrixFilterV1 filter, bool selected) {
    if (selected) {
      _filters.remove(filter);
      return;
    }

    if (_isContentFilter(filter)) {
      _filters
        ..remove(TriadMatrixFilterV1.handsOnly)
        ..remove(TriadMatrixFilterV1.hasKick);
    }

    if (filter == TriadMatrixFilterV1.handsOnly) {
      _filters
        ..remove(TriadMatrixFilterV1.hasKick)
        ..remove(TriadMatrixFilterV1.startsWithKick)
        ..remove(TriadMatrixFilterV1.endsWithKick);
    }

    if (filter == TriadMatrixFilterV1.hasKick ||
        _isKickPlacementFilter(filter)) {
      _filters.remove(TriadMatrixFilterV1.handsOnly);
    }

    _filters.add(filter);
  }

  void _toggleProgressFilter(TriadMatrixFilterV1 filter, bool selected) {
    if (_isStatusFilter(filter)) {
      _filters.removeAll(_statusFilters);
      if (!selected) _filters.add(filter);
      return;
    }

    if (selected) {
      _filters.remove(filter);
    } else {
      _filters.add(filter);
    }
  }

  void _toggleItemSelection(String itemId) {
    if (!widget.controller.canAppendToPhrase(
      currentItemIds: _selectedItemIds,
      nextItemId: itemId,
    )) {
      return;
    }
    setState(() {
      _selectedItemIds.add(itemId);
    });
  }

  void _finishEditing() {
    widget.onFinishEditing?.call(List<String>.from(_selectedItemIds));
  }

  void _removeSelectedAt(int index) {
    if (index < 0 || index >= _selectedItemIds.length) return;
    setState(() {
      _selectedItemIds.removeAt(index);
    });
  }

  void _practiceSelection() {
    if (_selectedItemIds.isEmpty) return;
    widget.onPreviewSelection(
      List<String>.from(_selectedItemIds),
      PracticeModeV1.singleSurface,
    );
  }

  void _practiceSelectionInFlow() {
    if (_selectedItemIds.isEmpty) return;
    widget.onPreviewSelection(
      List<String>.from(_selectedItemIds),
      PracticeModeV1.flow,
    );
  }

  Future<void> _addSelectionToWorkingOn() async {
    if (_selectedItemIds.isEmpty) return;

    if (_selectedItemIds.length == 1) {
      final String itemId = _selectedItemIds.first;
      await _showExistingItemPrompt(
        title: '${widget.controller.itemById(itemId).name} already exists',
        message: 'Open it to add it to Working On.',
        itemId: itemId,
      );
      return;
    }

    final PracticeCombinationV1? existing = widget.controller
        .combinationForItemIdsOrNull(_selectedItemIds);
    if (existing != null && widget.controller.itemById(existing.id).saved) {
      await _showExistingItemPrompt(
        title: 'This phrase is already saved',
        message: 'Open it to add it to Working On.',
        itemId: existing.id,
      );
      return;
    }

    final PracticeCombinationV1 draft = widget.controller
        .createDraftCombinationForEditing(itemIds: _selectedItemIds);
    widget.onOpenItem(draft.id);
  }

  Future<void> _showExistingItemPrompt({
    required String title,
    required String message,
    required String itemId,
  }) async {
    final bool? open = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Open Item'),
            ),
          ],
        );
      },
    );
    if (open == true && mounted) {
      widget.onOpenItem(itemId);
    }
  }

  void _applyRequest(MatrixScreenRequest request) {
    setState(() {
      _view = _viewForRequest(request);
      _filters
        ..clear()
        ..addAll(_normalizedIncomingFilters(request));
      _selectedRows.clear();
      _selectedColumns.clear();
      _selectedItemIds
        ..clear()
        ..addAll(request.selectedItemIds);
    });
  }

  Set<TriadMatrixFilterV1> _normalizedIncomingFilters(
    MatrixScreenRequest request,
  ) {
    final Set<TriadMatrixFilterV1> incoming = <TriadMatrixFilterV1>{
      ...request.filters,
    };

    switch (request.lane) {
      case LearningLaneV1.control:
        incoming.add(TriadMatrixFilterV1.handsOnly);
      case LearningLaneV1.balance:
        incoming
          ..add(TriadMatrixFilterV1.rightLead)
          ..add(TriadMatrixFilterV1.leftLead);
      case LearningLaneV1.dynamics:
        incoming.add(TriadMatrixFilterV1.needsWorkStatus);
      case LearningLaneV1.integration:
        incoming.add(TriadMatrixFilterV1.hasKick);
      case LearningLaneV1.phrasing:
      case LearningLaneV1.flow:
      case null:
        break;
    }

    return _normalizedFiltersForView(_view, incoming);
  }

  Set<TriadMatrixFilterV1> _normalizedFiltersForView(
    _MatrixPrimaryView view,
    Set<TriadMatrixFilterV1> filters,
  ) {
    final Set<TriadMatrixFilterV1> allowed = switch (view) {
      _MatrixPrimaryView.traits => _traitFilters,
      _MatrixPrimaryView.progress => _progressFilters,
    };

    final Set<TriadMatrixFilterV1> normalized = filters
        .where(allowed.contains)
        .toSet();

    if (view == _MatrixPrimaryView.traits) {
      if (normalized.contains(TriadMatrixFilterV1.handsOnly)) {
        normalized
          ..remove(TriadMatrixFilterV1.hasKick)
          ..remove(TriadMatrixFilterV1.startsWithKick)
          ..remove(TriadMatrixFilterV1.endsWithKick);
      }
      if (normalized.contains(TriadMatrixFilterV1.hasKick) ||
          _kickPlacementFilters.any(normalized.contains)) {
        normalized.remove(TriadMatrixFilterV1.handsOnly);
      }
    }

    if (view == _MatrixPrimaryView.progress) {
      final List<TriadMatrixFilterV1> activeStatuses = _statusFilters
          .where(normalized.contains)
          .toList(growable: false);
      if (activeStatuses.length > 1) {
        normalized.removeAll(activeStatuses.skip(1));
      }
    }

    return normalized;
  }

  _MatrixPrimaryView _viewForRequest(MatrixScreenRequest request) {
    if (request.lane == LearningLaneV1.dynamics ||
        request.filters.any(_progressFilters.contains)) {
      return _MatrixPrimaryView.progress;
    }

    return _MatrixPrimaryView.traits;
  }

  List<TriadMatrixFilterV1> _viewFilters(_MatrixPrimaryView view) {
    return switch (view) {
      _MatrixPrimaryView.traits => const <TriadMatrixFilterV1>[
        TriadMatrixFilterV1.rightLead,
        TriadMatrixFilterV1.leftLead,
        TriadMatrixFilterV1.handsOnly,
        TriadMatrixFilterV1.hasKick,
        TriadMatrixFilterV1.startsWithKick,
        TriadMatrixFilterV1.endsWithKick,
        TriadMatrixFilterV1.doubles,
      ],
      _MatrixPrimaryView.progress => const <TriadMatrixFilterV1>[
        TriadMatrixFilterV1.notTrained,
        TriadMatrixFilterV1.activeStatus,
        TriadMatrixFilterV1.needsWorkStatus,
        TriadMatrixFilterV1.strongStatus,
        TriadMatrixFilterV1.inRoutine,
        TriadMatrixFilterV1.inPhrases,
        TriadMatrixFilterV1.underPracticed,
        TriadMatrixFilterV1.recent,
      ],
    };
  }

  String _viewLabel(_MatrixPrimaryView view) {
    return switch (view) {
      _MatrixPrimaryView.traits => 'Traits',
      _MatrixPrimaryView.progress => 'Progress',
    };
  }

  bool _isContentFilter(TriadMatrixFilterV1 filter) {
    return filter == TriadMatrixFilterV1.handsOnly ||
        filter == TriadMatrixFilterV1.hasKick;
  }

  bool _isKickPlacementFilter(TriadMatrixFilterV1 filter) {
    return filter == TriadMatrixFilterV1.startsWithKick ||
        filter == TriadMatrixFilterV1.endsWithKick;
  }

  bool _isStatusFilter(TriadMatrixFilterV1 filter) {
    return _statusFilters.contains(filter);
  }

  double _gapAfterFilter(TriadMatrixFilterV1 filter) {
    return switch (_view) {
      _MatrixPrimaryView.traits
          when filter == TriadMatrixFilterV1.leftLead ||
              filter == TriadMatrixFilterV1.endsWithKick =>
        16,
      _MatrixPrimaryView.progress
          when filter == TriadMatrixFilterV1.strongStatus =>
        16,
      _ => 8,
    };
  }
}

class _MatrixPhrasePanel extends StatelessWidget {
  final AppController controller;
  final List<String> selectedItemIds;
  final ValueChanged<int> onRemoveAt;
  final List<Widget> actionPills;
  final bool showProgressLegend;
  final String? warningMessage;

  const _MatrixPhrasePanel({
    required this.controller,
    required this.selectedItemIds,
    required this.onRemoveAt,
    required this.actionPills,
    required this.showProgressLegend,
    required this.warningMessage,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> phraseTokens = selectedItemIds
        .expand(controller.noteTokensFor)
        .toList(growable: false);
    final List<PatternNoteMarkingV1> phraseMarkings = selectedItemIds
        .expand(controller.noteMarkingsFor)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showProgressLegend) ...<Widget>[
          const _ProgressLegendCard(),
          const SizedBox(height: 10),
        ],
        DrumPanel(
          tone: DrumPanelTone.warm,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const DrumEyebrow(text: 'Phrase'),
              const SizedBox(height: 8),
              if (selectedItemIds.isEmpty)
                Text(
                  'Select triads in the grid to build a phrase or practice one item directly.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5E584D),
                    height: 1.35,
                  ),
                )
              else ...<Widget>[
                PatternDisplayText(
                  tokens: phraseTokens,
                  markings: phraseMarkings,
                  grouping: PatternGroupingV1.triads,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 10),
                PatternSequenceEditor(
                  controller: controller,
                  itemIds: selectedItemIds,
                  onRemoveAt: onRemoveAt,
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: actionPills),
                ),
                if (warningMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _MatrixPhraseWarning(message: warningMessage!),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

const Set<TriadMatrixFilterV1> _traitFilters = <TriadMatrixFilterV1>{
  TriadMatrixFilterV1.rightLead,
  TriadMatrixFilterV1.leftLead,
  TriadMatrixFilterV1.handsOnly,
  TriadMatrixFilterV1.hasKick,
  TriadMatrixFilterV1.startsWithKick,
  TriadMatrixFilterV1.endsWithKick,
  TriadMatrixFilterV1.doubles,
};

const Set<TriadMatrixFilterV1> _progressFilters = <TriadMatrixFilterV1>{
  TriadMatrixFilterV1.notTrained,
  TriadMatrixFilterV1.activeStatus,
  TriadMatrixFilterV1.needsWorkStatus,
  TriadMatrixFilterV1.strongStatus,
  TriadMatrixFilterV1.inRoutine,
  TriadMatrixFilterV1.inPhrases,
  TriadMatrixFilterV1.underPracticed,
  TriadMatrixFilterV1.recent,
};

const Set<TriadMatrixFilterV1> _statusFilters = <TriadMatrixFilterV1>{
  TriadMatrixFilterV1.notTrained,
  TriadMatrixFilterV1.activeStatus,
  TriadMatrixFilterV1.needsWorkStatus,
  TriadMatrixFilterV1.strongStatus,
};

const Set<TriadMatrixFilterV1> _kickPlacementFilters = <TriadMatrixFilterV1>{
  TriadMatrixFilterV1.startsWithKick,
  TriadMatrixFilterV1.endsWithKick,
};

class _ProgressLegendCard extends StatelessWidget {
  const _ProgressLegendCard();

  @override
  Widget build(BuildContext context) {
    const List<({String label, Color color})> items =
        <({String label, Color color})>[
          (label: 'Not practiced', color: Color(0xFFFFFFFF)),
          (label: 'Active', color: Color(0xFFD9E9F7)),
          (label: 'Needs work', color: Color(0xFFF0B2AA)),
          (label: 'Strong', color: Color(0xFFDDEDDD)),
        ];

    return DrumPanel(
      tone: DrumPanelTone.warm,
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: items
            .map(
              (item) => Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0x22000000)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _MatrixPhraseWarning extends StatelessWidget {
  final String message;

  const _MatrixPhraseWarning({required this.message});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF4E7CF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB98739)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5C4423)),
        ),
      ),
    );
  }
}
