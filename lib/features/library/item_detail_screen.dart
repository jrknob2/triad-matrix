import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../features/app/drumcabulary_ui.dart';
import '../../features/app/unsaved_changes_dialog.dart';
import '../../state/app_controller.dart';
import '../matrix/widgets/triad_matrix_grid.dart';
import '../practice/widgets/session_setup_controls.dart';
import '../practice/widgets/pattern_voice_display.dart';

enum _ItemDetailControlSet { append, dynamics, voices }

enum _StructureToolOption { right, left, kick, rest, triad }

enum _StructureActionKind { append, insertBefore, insertAfter, replace }

class _RecordedStructureAction {
  final _StructureActionKind kind;
  final List<PatternTokenV1> tokens;
  final bool usesTriadGroupingRule;

  const _RecordedStructureAction({
    required this.kind,
    required this.tokens,
    required this.usesTriadGroupingRule,
  });
}

class ItemDetailScreen extends StatefulWidget {
  final AppController controller;
  final String itemId;
  final Future<List<String>?> Function(String) onOpenInMatrix;

  const ItemDetailScreen({
    super.key,
    required this.controller,
    required this.itemId,
    required this.onOpenInMatrix,
  });

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late List<PatternTokenV1> _draftTokens;
  late PatternGroupingV1 _draftGrouping;
  late List<int> _accentedNoteIndices;
  late List<int> _ghostNoteIndices;
  late List<DrumVoiceV1> _voiceAssignments;
  late int _sessionBpm;
  late TimerPresetV1 _timerPreset;
  late Set<int> _selectedNoteIndices;
  _ItemDetailControlSet _activeControlSet = _ItemDetailControlSet.append;
  _StructureToolOption? _pendingStructureTool;
  _RecordedStructureAction? _lastStructureAction;

  @override
  void initState() {
    super.initState();
    _loadDraftFromController();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        final PracticeItemV1? item = widget.controller.itemByIdOrNull(
          widget.itemId,
        );
        if (item == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final NavigatorState navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            }
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        final bool isDraftItem = !item.saved;
        final bool supportsMatrixEditing = _supportsMatrixEditingDraft();
        final Duration totalTime = widget.controller.totalTime(itemId: item.id);
        final int sessionCount = widget.controller.sessionCount(
          itemId: item.id,
        );
        final List<String> tokens = _draftTokens
            .map((PatternTokenV1 token) => token.symbol)
            .toList(growable: false);
        final bool flowCapable = _hasDraftFlowVoices(tokens, _voiceAssignments);
        final List<PatternNoteMarkingV1> draftMarkings = _draftMarkingsFor(
          _draftTokens.length,
        );
        final bool hasUnsavedChanges = _hasUnsavedChanges(item);

        return PopScope(
          canPop: !hasUnsavedChanges,
          onPopInvokedWithResult: (bool didPop, Object? result) async {
            if (didPop || !hasUnsavedChanges || !mounted) return;
            final bool shouldPop = await _handleUnsavedExit();
            if (shouldPop && mounted) {
              Navigator.of(this.context).pop();
            }
          },
          child: Scaffold(
            appBar: AppBar(title: const Text('Practice Item')),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                DrumPanel(
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _SelectableNotationBlock(
                          tokens: tokens,
                          markings: draftMarkings,
                          voices: _voiceAssignments,
                          grouping: _draftGrouping,
                          selectedIndices: _selectedNoteIndices,
                          showVoices: flowCapable,
                          onSelect: (int index) {
                            setState(() {
                              if (_selectedNoteIndices.contains(index)) {
                                _selectedNoteIndices.remove(index);
                              } else {
                                _selectedNoteIndices.add(index);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap positions to select them, then edit structure, dynamics, or voice.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFF5B5345)),
                        ),
                        const SizedBox(height: 12),
                        const DrumEyebrow(text: 'Filters'),
                        const SizedBox(height: 8),
                        DrumHorizontalControlStrip(
                          child: Row(
                            children: _ItemDetailControlSet.values
                                .map(
                                  (_ItemDetailControlSet controlSet) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: DrumSelectablePill(
                                      label: Text(
                                        _labelForControlSet(controlSet),
                                        style: TextStyle(
                                          color: _activeControlSet == controlSet
                                              ? Colors.white
                                              : null,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      selected: _activeControlSet == controlSet,
                                      onPressed: () {
                                        setState(() {
                                          _activeControlSet = controlSet;
                                        });
                                      },
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_activeControlSet ==
                            _ItemDetailControlSet.append) ...<Widget>[
                          Text(
                            'Pattern Structure',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          _StructureEditor(
                            tokens: _draftTokens,
                            selectedIndices: _selectedNoteIndices,
                            selectedTool: _pendingStructureTool,
                            lastAction: _lastStructureAction,
                            onToolChanged: _handleStructureToolChanged,
                            onAppend: _applyPendingAppend,
                            onInsertBefore: _applyPendingInsertBefore,
                            onInsertAfter: _applyPendingInsertAfter,
                            onReplaceSelection: _applyPendingReplaceSelection,
                            onDeleteSelection: _deleteSelection,
                            onRepeatLastAction: _repeatLastStructureAction,
                          ),
                          const SizedBox(height: 12),
                          _GroupingControl(
                            tokenCount: _draftTokens.length,
                            grouping: _draftGrouping,
                            onChanged: (PatternGroupingV1 next) {
                              setState(() {
                                _draftGrouping = next;
                              });
                            },
                          ),
                        ],
                        if (_activeControlSet ==
                            _ItemDetailControlSet.dynamics) ...<Widget>[
                          Text(
                            'Accents & Ghosts',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          _SelectedMarkingEditor(
                            tokens: tokens,
                            markings: draftMarkings,
                            selectedIndices: _selectedNoteIndices,
                            onChanged: (PatternNoteMarkingV1 next) {
                              _setMarkingForSelection(next);
                            },
                          ),
                        ],
                        if (_activeControlSet ==
                            _ItemDetailControlSet.voices) ...<Widget>[
                          Text(
                            'Flow Voices',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          _SelectedVoiceEditor(
                            tokens: tokens,
                            voices: _voiceAssignments,
                            selectedIndices: _selectedNoteIndices,
                            onChanged: (DrumVoiceV1 next) {
                              _setVoiceForSelection(next);
                            },
                          ),
                          if (flowCapable) ...<Widget>[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton(
                                onPressed: _clearVoices,
                                child: const Text('Clear Voices'),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _FlowReadinessNote(ready: flowCapable),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DrumPanel(
                  child: SessionSetupControls(
                    bpm: _sessionBpm,
                    timerPreset: _timerPreset,
                    onBpmChanged: (int next) {
                      setState(() => _sessionBpm = next.clamp(30, 260));
                    },
                    onTimerPresetChanged: (TimerPresetV1 next) {
                      setState(() => _timerPreset = next);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                DrumPanel(
                  child: Column(
                    children: <Widget>[
                      if (!isDraftItem) ...<Widget>[
                        ListTile(
                          title: const Text('Logged Time'),
                          trailing: Text(formatDuration(totalTime)),
                        ),
                        ListTile(
                          title: const Text('Sessions'),
                          trailing: Text('$sessionCount'),
                        ),
                        ListTile(
                          title: const Text('Last Worked'),
                          trailing: Text(
                            widget.controller.recentSummaryForItem(item.id),
                          ),
                        ),
                      ] else
                        const ListTile(
                          title: Text('New Phrase'),
                          subtitle: Text(
                            'Save this phrase to Working On when you are ready.',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: hasUnsavedChanges || isDraftItem
                      ? () => _saveDraft(saveToWorkingOn: isDraftItem)
                      : null,
                  child: Text(
                    isDraftItem ? 'Save to Working On' : 'Save Changes',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: !supportsMatrixEditing
                      ? null
                      : () async {
                          final String currentItemId = hasUnsavedChanges
                              ? _saveDraft()
                              : item.id;
                          final List<String>? selection = await widget
                              .onOpenInMatrix(currentItemId);
                          if (!mounted ||
                              selection == null ||
                              listEquals(
                                selection,
                                widget.controller.matrixSelectionItemIdsForItem(
                                  currentItemId,
                                ),
                              )) {
                            return;
                          }
                          _applyMatrixSelectionResult(
                            originalItemId: currentItemId,
                            selection: selection,
                          );
                        },
                  child: const Text('Open in Matrix'),
                ),
                if (!isDraftItem) ...<Widget>[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      if (hasUnsavedChanges) {
                        _saveDraft(saveToWorkingOn: true);
                        return;
                      }
                      widget.controller.toggleRoutineItem(item.id);
                    },
                    child: Text(
                      widget.controller.isDirectRoutineEntry(item.id)
                          ? 'Remove from Working On'
                          : 'Add to Working On',
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _loadDraftFromController() {
    final PracticeItemV1 item = widget.controller.itemById(widget.itemId);
    _draftTokens = List<PatternTokenV1>.from(item.tokens);
    _draftGrouping = item.groupingHint;
    _accentedNoteIndices = List<int>.from(item.accentedNoteIndices)..sort();
    _ghostNoteIndices = List<int>.from(item.ghostNoteIndices)..sort();
    _voiceAssignments = List<DrumVoiceV1>.from(
      widget.controller.noteVoicesFor(item.id),
    );
    _sessionBpm = widget.controller.launchBpmForItem(item.id);
    _timerPreset = widget.controller.launchTimerPresetForItem(item.id);
    _selectedNoteIndices = <int>{};
  }

  List<PatternNoteMarkingV1> _draftMarkingsFor(int noteCount) {
    final Set<int> accents = _accentedNoteIndices.toSet();
    final Set<int> ghosts = _ghostNoteIndices.toSet();
    return List<PatternNoteMarkingV1>.generate(noteCount, (int index) {
      if (ghosts.contains(index)) return PatternNoteMarkingV1.ghost;
      if (accents.contains(index)) return PatternNoteMarkingV1.accent;
      return PatternNoteMarkingV1.normal;
    });
  }

  void _setMarkingForSelection(PatternNoteMarkingV1 next) {
    final List<int> editableIndices = _selectedNoteIndices
        .where(
          (int index) =>
              index >= 0 &&
              index < _draftTokens.length &&
              !_draftTokens[index].isKick &&
              !_draftTokens[index].isRest,
        )
        .toList(growable: false);
    if (editableIndices.isEmpty) return;
    setState(() {
      final Set<int> accents = _accentedNoteIndices.toSet();
      final Set<int> ghosts = _ghostNoteIndices.toSet();
      for (final int noteIndex in editableIndices) {
        accents.remove(noteIndex);
        ghosts.remove(noteIndex);
        switch (next) {
          case PatternNoteMarkingV1.normal:
            break;
          case PatternNoteMarkingV1.accent:
            accents.add(noteIndex);
            break;
          case PatternNoteMarkingV1.ghost:
            ghosts.add(noteIndex);
            break;
        }
      }
      _accentedNoteIndices = accents.toList()..sort();
      _ghostNoteIndices = ghosts.toList()..sort();
      _selectedNoteIndices = <int>{};
    });
  }

  void _setVoiceForSelection(DrumVoiceV1 next) {
    final List<int> editableIndices = _selectedNoteIndices
        .where(
          (int index) =>
              index >= 0 &&
              index < _draftTokens.length &&
              !_draftTokens[index].isKick &&
              !_draftTokens[index].isRest,
        )
        .toList(growable: false);
    if (editableIndices.isEmpty) return;
    setState(() {
      final List<DrumVoiceV1> nextAssignments = List<DrumVoiceV1>.from(
        _voiceAssignments,
      );
      for (final int index in editableIndices) {
        nextAssignments[index] = next;
      }
      _voiceAssignments = nextAssignments;
      _selectedNoteIndices = <int>{};
    });
  }

  String _labelForControlSet(_ItemDetailControlSet controlSet) {
    return switch (controlSet) {
      _ItemDetailControlSet.append => 'Build',
      _ItemDetailControlSet.dynamics => 'Dynamics',
      _ItemDetailControlSet.voices => 'Voices',
    };
  }

  bool _hasDraftFlowVoices(List<String> tokens, List<DrumVoiceV1> voices) {
    for (int index = 0; index < tokens.length; index++) {
      if (tokens[index] == 'K' || tokens[index] == '_') continue;
      if (voices[index] != DrumVoiceV1.snare) return true;
    }
    return false;
  }

  bool _supportsMatrixEditingDraft() {
    if (_draftTokens.isEmpty || _draftTokens.length % 3 != 0) return false;
    return !_draftTokens.any((PatternTokenV1 token) => token.isRest);
  }

  DrumVoiceV1 _defaultVoiceForDraftToken(PatternTokenV1 token) {
    return token.isKick ? DrumVoiceV1.kick : DrumVoiceV1.snare;
  }

  void _insertTokens(
    List<PatternTokenV1> inserted, {
    required bool beforeSelection,
    PatternGroupingV1? groupingOverride,
    bool recordAction = true,
  }) {
    if (inserted.isEmpty) return;
    final List<int> sortedIndices = _selectedNoteIndices.toList()..sort();
    final int insertAt = sortedIndices.isEmpty
        ? _draftTokens.length
        : (beforeSelection ? sortedIndices.first : sortedIndices.last + 1);
    final List<PatternTokenV1> nextTokens = List<PatternTokenV1>.from(
      _draftTokens,
    )..insertAll(insertAt, inserted);
    final int shift = inserted.length;

    setState(() {
      _draftTokens = nextTokens;
      _accentedNoteIndices =
          _accentedNoteIndices
              .map((int index) => index >= insertAt ? index + shift : index)
              .toList(growable: false)
            ..sort();
      _ghostNoteIndices =
          _ghostNoteIndices
              .map((int index) => index >= insertAt ? index + shift : index)
              .toList(growable: false)
            ..sort();
      final List<DrumVoiceV1> nextVoices = List<DrumVoiceV1>.from(
        _voiceAssignments,
      )..insertAll(insertAt, inserted.map(_defaultVoiceForDraftToken));
      _voiceAssignments = nextVoices;
      if (groupingOverride != null) {
        _draftGrouping = groupingOverride;
      }
      _normalizeDraftStructure();
      _selectedNoteIndices = <int>{};
      if (recordAction) {
        _lastStructureAction = _RecordedStructureAction(
          kind: beforeSelection
              ? _StructureActionKind.insertBefore
              : _StructureActionKind.insertAfter,
          tokens: List<PatternTokenV1>.unmodifiable(inserted),
          usesTriadGroupingRule: groupingOverride != null,
        );
      }
    });
  }

  void _appendTokens(
    List<PatternTokenV1> appended, {
    PatternGroupingV1? groupingOverride,
    bool recordAction = true,
  }) {
    if (appended.isEmpty) return;
    final int insertAt = _draftTokens.length;
    final List<PatternTokenV1> nextTokens = List<PatternTokenV1>.from(
      _draftTokens,
    )..insertAll(insertAt, appended);

    setState(() {
      _draftTokens = nextTokens;
      _accentedNoteIndices = List<int>.from(_accentedNoteIndices)..sort();
      _ghostNoteIndices = List<int>.from(_ghostNoteIndices)..sort();
      final List<DrumVoiceV1> nextVoices = List<DrumVoiceV1>.from(
        _voiceAssignments,
      )..insertAll(insertAt, appended.map(_defaultVoiceForDraftToken));
      _voiceAssignments = nextVoices;
      if (groupingOverride != null) {
        _draftGrouping = groupingOverride;
      }
      _normalizeDraftStructure();
      _selectedNoteIndices = <int>{};
      if (recordAction) {
        _lastStructureAction = _RecordedStructureAction(
          kind: _StructureActionKind.append,
          tokens: List<PatternTokenV1>.unmodifiable(appended),
          usesTriadGroupingRule: groupingOverride != null,
        );
      }
    });
  }

  void _replaceSelectionWithTokens(
    List<PatternTokenV1> replacement, {
    PatternGroupingV1? groupingOverride,
    bool recordAction = true,
  }) {
    final List<int> sortedSelection = _selectedNoteIndices.toList()..sort();
    if (sortedSelection.isEmpty) return;
    final Set<int> selected = sortedSelection.toSet();
    final int insertAt = sortedSelection.first;
    final List<PatternTokenV1> nextTokens = <PatternTokenV1>[];
    final List<DrumVoiceV1> nextVoices = <DrumVoiceV1>[];
    final Map<int, int> nextIndexByOld = <int, int>{};

    for (int index = 0; index < _draftTokens.length; index++) {
      if (index == insertAt) {
        nextTokens.addAll(replacement);
        nextVoices.addAll(replacement.map(_defaultVoiceForDraftToken));
      }
      if (selected.contains(index)) continue;
      nextIndexByOld[index] = nextTokens.length;
      nextTokens.add(_draftTokens[index]);
      nextVoices.add(
        index < _voiceAssignments.length
            ? _voiceAssignments[index]
            : _defaultVoiceForDraftToken(_draftTokens[index]),
      );
    }

    setState(() {
      _draftTokens = nextTokens;
      _voiceAssignments = nextVoices;
      _accentedNoteIndices =
          _accentedNoteIndices
              .where(nextIndexByOld.containsKey)
              .map((int index) => nextIndexByOld[index]!)
              .toList(growable: false)
            ..sort();
      _ghostNoteIndices =
          _ghostNoteIndices
              .where(nextIndexByOld.containsKey)
              .map((int index) => nextIndexByOld[index]!)
              .toList(growable: false)
            ..sort();
      if (groupingOverride != null) {
        _draftGrouping = groupingOverride;
      }
      _normalizeDraftStructure();
      _selectedNoteIndices = <int>{};
      if (recordAction) {
        _lastStructureAction = _RecordedStructureAction(
          kind: _StructureActionKind.replace,
          tokens: List<PatternTokenV1>.unmodifiable(replacement),
          usesTriadGroupingRule: groupingOverride != null,
        );
      }
    });
  }

  void _deleteSelection() {
    final Set<int> selected = Set<int>.from(_selectedNoteIndices);
    if (selected.isEmpty) return;
    final List<PatternTokenV1> nextTokens = <PatternTokenV1>[];
    final List<DrumVoiceV1> nextVoices = <DrumVoiceV1>[];
    final Map<int, int> nextIndexByOld = <int, int>{};

    for (int index = 0; index < _draftTokens.length; index++) {
      if (selected.contains(index)) continue;
      nextIndexByOld[index] = nextTokens.length;
      nextTokens.add(_draftTokens[index]);
      nextVoices.add(
        index < _voiceAssignments.length
            ? _voiceAssignments[index]
            : _defaultVoiceForDraftToken(_draftTokens[index]),
      );
    }

    setState(() {
      _draftTokens = nextTokens;
      _voiceAssignments = nextVoices;
      _accentedNoteIndices =
          _accentedNoteIndices
              .where(nextIndexByOld.containsKey)
              .map((int index) => nextIndexByOld[index]!)
              .toList(growable: false)
            ..sort();
      _ghostNoteIndices =
          _ghostNoteIndices
              .where(nextIndexByOld.containsKey)
              .map((int index) => nextIndexByOld[index]!)
              .toList(growable: false)
            ..sort();
      _normalizeDraftStructure();
      _selectedNoteIndices = <int>{};
    });
  }

  Future<List<PatternTokenV1>?> _showTriadInsertDialog() async {
    final List<String>? selectedItemIds = await showDialog<List<String>>(
      context: context,
      builder: (BuildContext context) {
        final List<String> localSelectedItemIds = <String>[];
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: DrumPanel(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Insert Triad',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pick one or more triads from the shared matrix grid, then insert them into the pattern in selection order.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF5B5345),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: TriadMatrixGrid(
                          controller: widget.controller,
                          filters: const MatrixFiltersV1(
                            lane: null,
                            filters: <TriadMatrixFilterV1>{},
                            selectedRows: <String>{},
                            selectedColumns: <String>{},
                          ),
                          selection: MatrixSelectionStateV1(
                            orderedItemIds: List<String>.unmodifiable(
                              localSelectedItemIds,
                            ),
                          ),
                          showProgressColors: false,
                          axisSelectionEnabled: false,
                          onToggleRow: (_) {},
                          onToggleColumn: (_) {},
                          onTapItem: (String itemId) {
                            setModalState(() {
                              if (localSelectedItemIds.contains(itemId)) {
                                localSelectedItemIds.remove(itemId);
                              } else {
                                localSelectedItemIds.add(itemId);
                              }
                            });
                          },
                        ),
                      ),
                      if (localSelectedItemIds.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          '${localSelectedItemIds.length} triad${localSelectedItemIds.length == 1 ? '' : 's'} selected',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: const Color(0xFF5B5345),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: localSelectedItemIds.isEmpty
                                ? null
                                : () => Navigator.of(context).pop(
                                    List<String>.from(localSelectedItemIds),
                                  ),
                            child: const Text('Insert'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (!mounted || selectedItemIds == null || selectedItemIds.isEmpty) {
      return null;
    }
    return selectedItemIds
        .expand((String itemId) => widget.controller.itemById(itemId).tokens)
        .toList(growable: false);
  }

  PatternGroupingV1 _groupingAfterTriadStructureChange(
    List<PatternTokenV1> nextTokens,
  ) {
    final bool canKeepTriadGrouping =
        nextTokens.isNotEmpty &&
        !nextTokens.any((PatternTokenV1 token) => token.isRest) &&
        nextTokens.length % 3 == 0;
    return canKeepTriadGrouping ? PatternGroupingV1.triads : _draftGrouping;
  }

  Future<List<PatternTokenV1>?> _tokensForStructureTool(
    _StructureToolOption? tool,
  ) async {
    return switch (tool) {
      _StructureToolOption.right => const <PatternTokenV1>[
        PatternTokenV1.right,
      ],
      _StructureToolOption.left => const <PatternTokenV1>[PatternTokenV1.left],
      _StructureToolOption.kick => const <PatternTokenV1>[PatternTokenV1.kick],
      _StructureToolOption.rest => const <PatternTokenV1>[PatternTokenV1.rest],
      _StructureToolOption.triad => _showTriadInsertDialog(),
      null => null,
    };
  }

  Future<void> _handleStructureToolChanged(_StructureToolOption? next) async {
    if (next == null) {
      setState(() {
        _pendingStructureTool = null;
      });
      return;
    }
    if (_selectedNoteIndices.isEmpty) {
      setState(() {
        _pendingStructureTool = null;
      });
      final List<PatternTokenV1>? inserted = await _tokensForStructureTool(
        next,
      );
      if (!mounted || inserted == null || inserted.isEmpty) return;
      if (next == _StructureToolOption.triad) {
        final List<PatternTokenV1> nextTokens = List<PatternTokenV1>.from(
          _draftTokens,
        )..addAll(inserted);
        _appendTokens(
          inserted,
          groupingOverride: _groupingAfterTriadStructureChange(nextTokens),
        );
      } else {
        _appendTokens(inserted);
      }
      return;
    }
    setState(() {
      _pendingStructureTool = next;
    });
  }

  Future<void> _applyPendingAppend() async {
    final List<PatternTokenV1>? appended = await _tokensForStructureTool(
      _pendingStructureTool,
    );
    if (!mounted || appended == null || appended.isEmpty) return;
    if (_pendingStructureTool == _StructureToolOption.triad) {
      final List<PatternTokenV1> nextTokens = List<PatternTokenV1>.from(
        _draftTokens,
      )..addAll(appended);
      _appendTokens(
        appended,
        groupingOverride: _groupingAfterTriadStructureChange(nextTokens),
      );
      return;
    }
    _appendTokens(appended);
  }

  Future<void> _applyPendingInsertBefore() async {
    final List<PatternTokenV1>? inserted = await _tokensForStructureTool(
      _pendingStructureTool,
    );
    if (!mounted || inserted == null || inserted.isEmpty) return;
    if (_pendingStructureTool == _StructureToolOption.triad) {
      final List<int> sortedSelection = _selectedNoteIndices.toList()..sort();
      final int insertAt = sortedSelection.isEmpty
          ? _draftTokens.length
          : sortedSelection.first;
      final List<PatternTokenV1> nextTokens = List<PatternTokenV1>.from(
        _draftTokens,
      )..insertAll(insertAt, inserted);
      _insertTokens(
        inserted,
        beforeSelection: true,
        groupingOverride: _groupingAfterTriadStructureChange(nextTokens),
      );
      return;
    }
    _insertTokens(inserted, beforeSelection: true);
  }

  Future<void> _applyPendingInsertAfter() async {
    final List<PatternTokenV1>? inserted = await _tokensForStructureTool(
      _pendingStructureTool,
    );
    if (!mounted || inserted == null || inserted.isEmpty) return;
    if (_pendingStructureTool == _StructureToolOption.triad) {
      final List<int> sortedSelection = _selectedNoteIndices.toList()..sort();
      final int insertAt = sortedSelection.isEmpty
          ? _draftTokens.length
          : sortedSelection.last + 1;
      final List<PatternTokenV1> nextTokens = List<PatternTokenV1>.from(
        _draftTokens,
      )..insertAll(insertAt, inserted);
      _insertTokens(
        inserted,
        beforeSelection: false,
        groupingOverride: _groupingAfterTriadStructureChange(nextTokens),
      );
      return;
    }
    _insertTokens(inserted, beforeSelection: false);
  }

  Future<void> _applyPendingReplaceSelection() async {
    if (_selectedNoteIndices.isEmpty) return;
    final List<PatternTokenV1>? replacement = await _tokensForStructureTool(
      _pendingStructureTool,
    );
    if (!mounted || replacement == null || replacement.isEmpty) return;
    final PatternGroupingV1? groupingOverride =
        _pendingStructureTool == _StructureToolOption.triad
        ? _groupingAfterTriadStructureChange(
            _tokensAfterReplacingSelection(replacement),
          )
        : null;
    _replaceSelectionWithTokens(
      replacement,
      groupingOverride: groupingOverride,
    );
  }

  Future<void> _repeatLastStructureAction() async {
    final _RecordedStructureAction? lastAction = _lastStructureAction;
    if (lastAction == null || lastAction.tokens.isEmpty) return;
    final PatternGroupingV1? groupingOverride = lastAction.usesTriadGroupingRule
        ? _groupingAfterTriadStructureChange(
            switch (lastAction.kind) {
              _StructureActionKind.append => List<PatternTokenV1>.from(
                _draftTokens,
              )..addAll(lastAction.tokens),
              _StructureActionKind.insertBefore => (() {
                  final List<int> sortedSelection =
                      _selectedNoteIndices.toList()..sort();
                  final int insertAt = sortedSelection.isEmpty
                      ? _draftTokens.length
                      : sortedSelection.first;
                  return List<PatternTokenV1>.from(_draftTokens)
                    ..insertAll(insertAt, lastAction.tokens);
                })(),
              _StructureActionKind.insertAfter => (() {
                  final List<int> sortedSelection =
                      _selectedNoteIndices.toList()..sort();
                  final int insertAt = sortedSelection.isEmpty
                      ? _draftTokens.length
                      : sortedSelection.last + 1;
                  return List<PatternTokenV1>.from(_draftTokens)
                    ..insertAll(insertAt, lastAction.tokens);
                })(),
              _StructureActionKind.replace => _tokensAfterReplacingSelection(
                lastAction.tokens,
              ),
            },
          )
        : null;

    switch (lastAction.kind) {
      case _StructureActionKind.append:
        _appendTokens(
          lastAction.tokens,
          groupingOverride: groupingOverride,
          recordAction: false,
        );
        break;
      case _StructureActionKind.insertBefore:
        if (_selectedNoteIndices.isEmpty) return;
        _insertTokens(
          lastAction.tokens,
          beforeSelection: true,
          groupingOverride: groupingOverride,
          recordAction: false,
        );
        break;
      case _StructureActionKind.insertAfter:
        if (_selectedNoteIndices.isEmpty) return;
        _insertTokens(
          lastAction.tokens,
          beforeSelection: false,
          groupingOverride: groupingOverride,
          recordAction: false,
        );
        break;
      case _StructureActionKind.replace:
        if (_selectedNoteIndices.isEmpty) return;
        _replaceSelectionWithTokens(
          lastAction.tokens,
          groupingOverride: groupingOverride,
          recordAction: false,
        );
        break;
    }
  }

  List<PatternTokenV1> _tokensAfterReplacingSelection(
    List<PatternTokenV1> replacement,
  ) {
    final List<int> sortedSelection = _selectedNoteIndices.toList()..sort();
    if (sortedSelection.isEmpty) return List<PatternTokenV1>.from(_draftTokens);
    final Set<int> selected = sortedSelection.toSet();
    final int insertAt = sortedSelection.first;
    final List<PatternTokenV1> nextTokens = <PatternTokenV1>[];
    for (int index = 0; index < _draftTokens.length; index++) {
      if (index == insertAt) {
        nextTokens.addAll(replacement);
      }
      if (selected.contains(index)) continue;
      nextTokens.add(_draftTokens[index]);
    }
    return nextTokens;
  }

  void _normalizeDraftStructure() {
    final List<String> symbols = _draftTokens
        .map((PatternTokenV1 token) => token.symbol)
        .toList(growable: false);
    final int? groupSize = _draftGrouping.groupSize;
    if (groupSize != null &&
        (_draftTokens.isEmpty || _draftTokens.length % groupSize != 0)) {
      _draftGrouping = PatternGroupingV1.none;
    }
    _accentedNoteIndices =
        _accentedNoteIndices
            .where(
              (int index) =>
                  index >= 0 &&
                  index < symbols.length &&
                  symbols[index] != 'K' &&
                  symbols[index] != '_',
            )
            .toSet()
            .toList(growable: false)
          ..sort();
    _ghostNoteIndices =
        _ghostNoteIndices
            .where(
              (int index) =>
                  index >= 0 && index < symbols.length && symbols[index] != '_',
            )
            .toSet()
            .toList(growable: false)
          ..sort();
    final List<DrumVoiceV1> nextVoices = List<DrumVoiceV1>.generate(
      symbols.length,
      (int index) {
        final DrumVoiceV1 fallback = _defaultVoiceForDraftToken(
          _draftTokens[index],
        );
        if (index >= _voiceAssignments.length) return fallback;
        final DrumVoiceV1 voice = _voiceAssignments[index];
        if (symbols[index] == 'K') return DrumVoiceV1.kick;
        if (symbols[index] == '_') return DrumVoiceV1.snare;
        return voice == DrumVoiceV1.kick ? DrumVoiceV1.snare : voice;
      },
      growable: false,
    );
    _voiceAssignments = nextVoices;
  }

  void _clearVoices() {
    setState(() {
      _voiceAssignments = List<DrumVoiceV1>.generate(_draftTokens.length, (
        int index,
      ) {
        return _defaultVoiceForDraftToken(_draftTokens[index]);
      });
      _selectedNoteIndices = <int>{};
    });
  }

  bool _hasUnsavedChanges(PracticeItemV1 item) {
    final List<PatternNoteMarkingV1> currentMarkings = widget.controller
        .noteMarkingsFor(item.id);
    final List<PatternNoteMarkingV1> draftMarkings = _draftMarkingsFor(
      _draftTokens.length,
    );
    return !item.saved ||
        !listEquals(item.tokens, _draftTokens) ||
        item.groupingHint != _draftGrouping ||
        !listEquals(currentMarkings, draftMarkings) ||
        !listEquals(
          widget.controller.noteVoicesFor(item.id),
          _voiceAssignments,
        ) ||
        widget.controller.launchBpmForItem(item.id) != _sessionBpm ||
        widget.controller.launchTimerPresetForItem(item.id) != _timerPreset;
  }

  String _saveDraft({bool saveToWorkingOn = false}) {
    widget.controller.rememberLaunchPreferencesForItem(
      itemId: widget.itemId,
      bpm: _sessionBpm,
      timerPreset: _timerPreset,
    );
    final String savedItemId = widget.controller.savePracticeItemEdits(
      itemId: widget.itemId,
      accentedNoteIndices: _accentedNoteIndices,
      ghostNoteIndices: _ghostNoteIndices,
      voiceAssignments: _voiceAssignments,
      competency: widget.controller.competencyFor(widget.itemId),
      sequence: PatternSequenceV1(tokens: _draftTokens),
      groupingHint: _draftGrouping,
      saveToWorkingOn: saveToWorkingOn,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saveToWorkingOn ? 'Saved to Working On.' : 'Changes saved.',
        ),
      ),
    );
    return savedItemId;
  }

  void _applyMatrixSelectionResult({
    required String originalItemId,
    required List<String> selection,
  }) {
    widget.controller.applyMatrixSelectionToItem(
      itemId: originalItemId,
      itemIds: selection,
    );
    widget.controller.rememberLaunchPreferencesForItem(
      itemId: originalItemId,
      bpm: _sessionBpm,
      timerPreset: _timerPreset,
    );
    _loadDraftFromController();
    setState(() {});
  }

  Future<bool> _handleUnsavedExit() async {
    final bool isDraftItem = !widget.controller.itemById(widget.itemId).saved;
    final UnsavedChangesDecision? decision = await showUnsavedChangesDialog(
      context,
      title: 'Unsaved Changes',
      message: isDraftItem
          ? 'Save this phrase to Working On before leaving?'
          : 'Save your changes to this practice item before leaving?',
      saveLabel: isDraftItem ? 'Save to Working On' : 'Save Changes',
    );
    if (!mounted) return false;
    return switch (decision) {
      UnsavedChangesDecision.save => () {
        _saveDraft(saveToWorkingOn: isDraftItem);
        return true;
      }(),
      UnsavedChangesDecision.discard => () {
        if (isDraftItem) {
          widget.controller.discardUnsavedPracticeItem(widget.itemId);
        }
        return true;
      }(),
      _ => false,
    };
  }
}

class _SelectableNotationBlock extends StatelessWidget {
  static const double _rendererCellWidthInput = 38;
  static const double _selectionHaloWidth = 8;

  final List<String> tokens;
  final List<PatternNoteMarkingV1> markings;
  final List<DrumVoiceV1> voices;
  final PatternGroupingV1 grouping;
  final Set<int> selectedIndices;
  final bool showVoices;
  final ValueChanged<int> onSelect;

  const _SelectableNotationBlock({
    required this.tokens,
    required this.markings,
    required this.voices,
    required this.grouping,
    required this.selectedIndices,
    required this.showVoices,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final TextStyle patternStyle =
        Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ) ??
        const TextStyle(fontSize: 28, fontWeight: FontWeight.w900);
    final TextStyle voiceStyle =
        Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF5B5345),
        ) ??
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w800);
    final List<double> outerCellWidths = List<double>.generate(
      markings.length,
      (int index) =>
          PatternVoiceDisplay.tokenWidthForMarking(
            markings[index],
            patternStyle,
            _rendererCellWidthInput,
          ) +
          _selectionHaloWidth,
      growable: false,
    );
    final double separatorSlotWidth =
        PatternVoiceDisplay.separatorWidthForStyle(
          patternStyle,
          _rendererCellWidthInput,
        );
    final List<String> separators = List<String>.generate(
      tokens.length,
      (int index) => grouping.separatorAfter(index, tokens.length),
      growable: false,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : double.infinity;
        if (tokens.isEmpty) {
          final double patternRowHeight = (patternStyle.fontSize ?? 28) * 1.35;
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: maxWidth.isFinite ? maxWidth : 180,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x1F000000)),
              ),
              child: SizedBox(height: patternRowHeight),
            ),
          );
        }
        final List<_NotationChunk> chunks = _chunksForWidth(
          maxWidth,
          outerCellWidths,
          separators,
          separatorSlotWidth: separatorSlotWidth,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int i = 0; i < chunks.length; i++) ...<Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (
                    int index = chunks[i].start;
                    index < chunks[i].end;
                    index++
                  ) ...<Widget>[
                    _SelectableNotationCell(
                      token: tokens[index],
                      marking: markings[index],
                      voice: voices[index],
                      selected: selectedIndices.contains(index),
                      enabled: true,
                      showVoice: showVoices,
                      patternStyle: patternStyle,
                      voiceStyle: voiceStyle,
                      outerCellWidth: outerCellWidths[index],
                      innerCellWidth: _rendererCellWidthInput,
                      onTap: () => onSelect(index),
                    ),
                    if (separators[index].isNotEmpty)
                      SizedBox(
                        width: separatorSlotWidth,
                        child: Center(
                          child: Text(
                            separators[index],
                            style: patternStyle.copyWith(
                              color: const Color(0xFF6B6254),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
              if (i < chunks.length - 1) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }

  List<_NotationChunk> _chunksForWidth(
    double maxWidth,
    List<double> outerCellWidths,
    List<String> separators, {
    required double separatorSlotWidth,
  }) {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      return <_NotationChunk>[_NotationChunk(start: 0, end: tokens.length)];
    }
    final List<_NotationChunk> chunks = <_NotationChunk>[];
    int start = 0;
    while (start < tokens.length) {
      double width = 0;
      int end = start;
      while (end < tokens.length) {
        final double nextWidth =
            outerCellWidths[end] +
            (separators[end].isNotEmpty ? separatorSlotWidth : 0);
        if (end > start && width + nextWidth > maxWidth) break;
        width += nextWidth;
        end++;
      }
      if (end == start) end++;
      chunks.add(_NotationChunk(start: start, end: end));
      start = end;
    }
    return chunks;
  }
}

class _SelectableNotationCell extends StatelessWidget {
  final String token;
  final PatternNoteMarkingV1 marking;
  final DrumVoiceV1 voice;
  final bool selected;
  final bool enabled;
  final bool showVoice;
  final TextStyle patternStyle;
  final TextStyle voiceStyle;
  final double outerCellWidth;
  final double innerCellWidth;
  final VoidCallback onTap;

  const _SelectableNotationCell({
    required this.token,
    required this.marking,
    required this.voice,
    required this.selected,
    required this.enabled,
    required this.showVoice,
    required this.patternStyle,
    required this.voiceStyle,
    required this.outerCellWidth,
    required this.innerCellWidth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: outerCellWidth,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE7D6A8) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF8E6B1F)
                  : (enabled ? Colors.transparent : const Color(0x14000000)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PatternVoiceDisplay(
                tokens: <PatternTokenV1>[PatternTokenV1.fromSymbol(token)],
                markings: <PatternNoteMarkingV1>[marking],
                voices: <DrumVoiceV1>[voice],
                patternStyle: patternStyle,
                voiceStyle: voiceStyle,
                cellWidth: innerCellWidth,
                scrollable: false,
                wrap: false,
                grouping: PatternGroupingV1.none,
                showVoiceRow: showVoice,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StructureEditor extends StatelessWidget {
  final List<PatternTokenV1> tokens;
  final Set<int> selectedIndices;
  final _StructureToolOption? selectedTool;
  final _RecordedStructureAction? lastAction;
  final ValueChanged<_StructureToolOption?> onToolChanged;
  final Future<void> Function() onAppend;
  final Future<void> Function() onInsertBefore;
  final Future<void> Function() onInsertAfter;
  final Future<void> Function() onReplaceSelection;
  final VoidCallback onDeleteSelection;
  final Future<void> Function() onRepeatLastAction;

  const _StructureEditor({
    required this.tokens,
    required this.selectedIndices,
    required this.selectedTool,
    required this.lastAction,
    required this.onToolChanged,
    required this.onAppend,
    required this.onInsertBefore,
    required this.onInsertAfter,
    required this.onReplaceSelection,
    required this.onDeleteSelection,
    required this.onRepeatLastAction,
  });

  @override
  Widget build(BuildContext context) {
    final List<int> sortedSelection = selectedIndices.toList()..sort();
    final bool hasSelection = sortedSelection.isNotEmpty;
    final bool hasTool = selectedTool != null;
    final bool canAppend = hasTool;
    final bool canInsert = hasSelection && hasTool;
    final bool canDelete = hasSelection && !hasTool;
    final bool canReplace = hasSelection && hasTool;
    final bool canRepeat = switch (lastAction?.kind) {
      _StructureActionKind.append => true,
      _StructureActionKind.insertBefore ||
      _StructureActionKind.insertAfter ||
      _StructureActionKind.replace => hasSelection,
      null => false,
    };
    final String summary = switch ((hasSelection, selectedTool)) {
      (false, null) =>
        'No position selected. Tap a stroke to append it to the pattern.',
      (false, _) =>
        'No position selected. Tapping a stroke appends it automatically.',
      (true, null) =>
        sortedSelection.length == 1
            ? 'Position ${sortedSelection.first + 1} selected · ${tokens[sortedSelection.first].symbol}. Choose a stroke source or delete the selection.'
            : '${sortedSelection.length} positions selected. Choose a stroke source or delete the selected positions.',
      (true, _) =>
        '${sortedSelection.length} position${sortedSelection.length == 1 ? '' : 's'} selected · ${_labelForTool(selectedTool!)} ready.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          summary,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF5B5345),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        const DrumEyebrow(text: 'Strokes'),
        const SizedBox(height: 8),
        DrumHorizontalControlStrip(
          child: Row(
            children: _StructureToolOption.values
                .map(
                  (_StructureToolOption tool) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: DrumSelectablePill(
                      label: Text(
                        _labelForTool(tool),
                        style: TextStyle(
                          color: selectedTool == tool ? Colors.white : null,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      selected: selectedTool == tool,
                      onPressed: () {
                        onToolChanged(selectedTool == tool ? null : tool);
                      },
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 8),
        const DrumEyebrow(text: 'Actions'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _TokenActionPill(
              label: 'Append',
              onPressed: canAppend
                  ? () {
                      onAppend();
                    }
                  : null,
            ),
            _TokenActionPill(
              label: 'Repeat',
              onPressed: canRepeat
                  ? () {
                      onRepeatLastAction();
                    }
                  : null,
            ),
            _TokenActionPill(
              label: 'Insert Before',
              onPressed: canInsert
                  ? () {
                      onInsertBefore();
                    }
                  : null,
            ),
            _TokenActionPill(
              label: 'Insert After',
              onPressed: canInsert
                  ? () {
                      onInsertAfter();
                    }
                  : null,
            ),
            _TokenActionPill(
              label: 'Replace',
              onPressed: canReplace
                  ? () {
                      onReplaceSelection();
                    }
                  : null,
            ),
            _TokenActionPill(
              label: 'Delete',
              onPressed: canDelete ? onDeleteSelection : null,
            ),
          ],
        ),
      ],
    );
  }

  String _labelForTool(_StructureToolOption tool) {
    return switch (tool) {
      _StructureToolOption.right => 'R',
      _StructureToolOption.left => 'L',
      _StructureToolOption.kick => 'K',
      _StructureToolOption.rest => 'Rest',
      _StructureToolOption.triad => 'Triad',
    };
  }
}

class _GroupingControl extends StatelessWidget {
  final int tokenCount;
  final PatternGroupingV1 grouping;
  final ValueChanged<PatternGroupingV1> onChanged;

  const _GroupingControl({
    required this.tokenCount,
    required this.grouping,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final List<_GroupingOption> options = <_GroupingOption>[
      const _GroupingOption(
        label: 'None',
        grouping: PatternGroupingV1.none,
        enabled: true,
      ),
      _GroupingOption(
        label: '3',
        grouping: PatternGroupingV1.triads,
        enabled: tokenCount > 0 && tokenCount % 3 == 0,
      ),
      _GroupingOption(
        label: '4',
        grouping: PatternGroupingV1.fourNote,
        enabled: tokenCount > 0 && tokenCount % 4 == 0,
      ),
      _GroupingOption(
        label: '5',
        grouping: PatternGroupingV1.fiveNote,
        enabled: tokenCount > 0 && tokenCount % 5 == 0,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Grouping',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFF5B5345),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final _GroupingOption option in options)
              DrumSelectablePill(
                label: Text(option.label),
                selected: option.grouping == grouping,
                onPressed: option.enabled
                    ? () => onChanged(option.grouping)
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _GroupingOption {
  final String label;
  final PatternGroupingV1 grouping;
  final bool enabled;

  const _GroupingOption({
    required this.label,
    required this.grouping,
    required this.enabled,
  });
}

class _TokenActionPill extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _TokenActionPill({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return DrumSelectablePill(
      label: Text(label),
      selected: false,
      onPressed: onPressed,
    );
  }
}

class _SelectedMarkingEditor extends StatelessWidget {
  final List<String> tokens;
  final List<PatternNoteMarkingV1> markings;
  final Set<int> selectedIndices;
  final ValueChanged<PatternNoteMarkingV1> onChanged;

  const _SelectedMarkingEditor({
    required this.tokens,
    required this.markings,
    required this.selectedIndices,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final List<int> editableIndices = selectedIndices
        .where((int index) => tokens[index] != 'K' && tokens[index] != '_')
        .toList(growable: false);
    final List<int> sortedIndices = editableIndices..sort();
    final Set<PatternNoteMarkingV1> currentValues = sortedIndices
        .map((int index) => markings[index])
        .toSet();
    final PatternNoteMarkingV1? current = currentValues.length == 1
        ? currentValues.first
        : null;
    final bool enabled = sortedIndices.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _selectionLabel(selectedIndices, sortedIndices, tokens, current),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF5B5345),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PatternNoteMarkingV1.values
              .map(
                (PatternNoteMarkingV1 option) => DrumSelectablePill(
                  label: Text(_markingOptionLabel(option)),
                  selected: current != null && current == option,
                  onPressed: enabled ? () => onChanged(option) : null,
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  static String _markingOptionLabel(PatternNoteMarkingV1 marking) {
    return switch (marking) {
      PatternNoteMarkingV1.normal => 'Normal',
      PatternNoteMarkingV1.accent => 'Accent',
      PatternNoteMarkingV1.ghost => 'Ghost',
    };
  }

  static String _markingLabel(String token, PatternNoteMarkingV1 marking) {
    return switch (marking) {
      PatternNoteMarkingV1.normal => token,
      PatternNoteMarkingV1.accent => '^$token',
      PatternNoteMarkingV1.ghost => '($token)',
    };
  }

  static String _selectionLabel(
    Set<int> allSelectedIndices,
    List<int> indices,
    List<String> tokens,
    PatternNoteMarkingV1? current,
  ) {
    if (allSelectedIndices.isEmpty) {
      return 'No hand notes selected';
    }
    if (indices.isEmpty) {
      return 'Selection has no editable hand notes';
    }
    final String positions = indices
        .map((int index) => '${index + 1}')
        .join(', ');
    if (indices.length == 1) {
      final String token = tokens[indices.first];
      return current == null
          ? 'Note ${indices.first + 1} · $token'
          : 'Note ${indices.first + 1} · ${_markingLabel(token, current)}';
    }
    if (current == null) {
      return '${indices.length} notes selected · $positions';
    }
    return '${indices.length} notes selected · ${_markingOptionLabel(current)}';
  }
}

class _SelectedVoiceEditor extends StatelessWidget {
  final List<String> tokens;
  final List<DrumVoiceV1> voices;
  final Set<int> selectedIndices;
  final ValueChanged<DrumVoiceV1> onChanged;

  const _SelectedVoiceEditor({
    required this.tokens,
    required this.voices,
    required this.selectedIndices,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final List<int> editableIndices = selectedIndices
        .where((int index) => tokens[index] != 'K' && tokens[index] != '_')
        .toList(growable: false);
    final List<int> sortedIndices = editableIndices..sort();
    final Set<DrumVoiceV1> currentValues = sortedIndices
        .map((int index) => voices[index])
        .toSet();
    final DrumVoiceV1? current = currentValues.length == 1
        ? currentValues.first
        : null;
    final bool enabled = sortedIndices.isNotEmpty;

    const List<DrumVoiceV1> options = <DrumVoiceV1>[
      DrumVoiceV1.snare,
      DrumVoiceV1.rackTom,
      DrumVoiceV1.tom2,
      DrumVoiceV1.floorTom,
      DrumVoiceV1.hihat,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _selectionLabel(selectedIndices, sortedIndices, current),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF5B5345),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (DrumVoiceV1 option) => DrumSelectablePill(
                  label: Text(option.shortLabel),
                  selected: current != null && current == option,
                  onPressed: enabled ? () => onChanged(option) : null,
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  static String _selectionLabel(
    Set<int> allSelectedIndices,
    List<int> editableIndices,
    DrumVoiceV1? current,
  ) {
    if (allSelectedIndices.isEmpty) {
      return 'No hand notes selected';
    }
    if (editableIndices.isEmpty) {
      return 'Selection has no editable hand notes';
    }
    return current == null
        ? '${editableIndices.length} notes selected'
        : '${editableIndices.length} notes selected · ${current.shortLabel}';
  }
}

class _NotationChunk {
  final int start;
  final int end;

  const _NotationChunk({required this.start, required this.end});
}

class _FlowReadinessNote extends StatelessWidget {
  final bool ready;

  const _FlowReadinessNote({required this.ready});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ready ? const Color(0xFFDDEDDD) : const Color(0xFFF1ECE3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22000000)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          ready
              ? 'The voices are set. Keep the sticking the same and let the voices do the moving.'
              : 'Set at least one note off the snare before you treat this as flow.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
