import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../features/app/drumcabulary_ui.dart';
import '../../features/app/unsaved_changes_dialog.dart';
import '../../state/app_controller.dart';
import '../practice/widgets/session_setup_controls.dart';

class ItemDetailScreen extends StatefulWidget {
  final AppController controller;
  final String itemId;
  final void Function(String, PracticeModeV1) onPracticeItemInMode;
  final Future<List<String>?> Function(String) onOpenInMatrix;

  const ItemDetailScreen({
    super.key,
    required this.controller,
    required this.itemId,
    required this.onPracticeItemInMode,
    required this.onOpenInMatrix,
  });

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late List<int> _accentedNoteIndices;
  late List<int> _ghostNoteIndices;
  late List<DrumVoiceV1> _voiceAssignments;
  late CompetencyLevelV1 _competency;
  late int _sessionBpm;
  late TimerPresetV1 _timerPreset;
  late Set<int> _selectedNoteIndices;

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
        final PracticeItemV1 item = widget.controller.itemById(widget.itemId);
        final bool isDraftItem = !item.saved;
        final bool supportsMatrixEditing = item.isTriad || item.isCombo;
        final Duration totalTime = widget.controller.totalTime(itemId: item.id);
        final int sessionCount = widget.controller.sessionCount(
          itemId: item.id,
        );
        final List<String> tokens = widget.controller.noteTokensFor(item.id);
        final bool flowCapable = _hasDraftFlowVoices(tokens, _voiceAssignments);
        final List<PatternNoteMarkingV1> draftMarkings = _draftMarkingsFor(
          item.noteCount,
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
                          grouping: widget.controller.displayGroupingFor(
                            item.id,
                          ),
                          selectedIndices: _selectedNoteIndices,
                          showVoices: flowCapable,
                          onSelect: (int index) {
                            if (tokens[index] == 'K') return;
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
                          'Tap notes to select them, then assign one change.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFF5B5345)),
                        ),
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 16),
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
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DrumPanel(
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'Competency',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            PopupMenuButton<CompetencyLevelV1>(
                              onSelected: (CompetencyLevelV1 next) {
                                setState(() => _competency = next);
                              },
                              itemBuilder: (BuildContext context) =>
                                  CompetencyLevelV1.values
                                      .map(
                                        (CompetencyLevelV1 level) =>
                                            PopupMenuItem<CompetencyLevelV1>(
                                              value: level,
                                              child: Text(level.label),
                                            ),
                                      )
                                      .toList(growable: false),
                              child: DrumTag(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      _competency.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.expand_more, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.controller.competencyGuidanceFor(
                            item.id,
                            _competency,
                          ),
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: const Color(0xFF5B5345),
                                height: 1.35,
                              ),
                        ),
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
                FilledButton.tonal(
                  onPressed: isDraftItem
                      ? null
                      : () async {
                          if (hasUnsavedChanges) _saveDraft();
                          widget.controller.rememberLaunchPreferencesForItem(
                            itemId: item.id,
                            bpm: _sessionBpm,
                            timerPreset: _timerPreset,
                          );
                          widget.onPracticeItemInMode(
                            item.id,
                            PracticeModeV1.singleSurface,
                          );
                        },
                  child: const Text('Practice on One Surface'),
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: isDraftItem || !flowCapable
                      ? null
                      : () async {
                          if (hasUnsavedChanges) _saveDraft();
                          widget.controller.rememberLaunchPreferencesForItem(
                            itemId: item.id,
                            bpm: _sessionBpm,
                            timerPreset: _timerPreset,
                          );
                          widget.onPracticeItemInMode(
                            item.id,
                            PracticeModeV1.flow,
                          );
                        },
                  child: const Text('Practice in Flow'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: isDraftItem || !supportsMatrixEditing
                      ? null
                      : () async {
                          if (hasUnsavedChanges) {
                            _saveDraft();
                          }
                          final List<String>? selection = await widget
                              .onOpenInMatrix(item.id);
                          if (!mounted ||
                              selection == null ||
                              !item.isCombo ||
                              listEquals(
                                selection,
                                widget.controller.matrixSelectionItemIdsForItem(
                                  item.id,
                                ),
                              )) {
                            return;
                          }
                          widget.controller.updateCombinationSelection(
                            comboId: item.id,
                            itemIds: selection,
                          );
                          _loadDraftFromController();
                          setState(() {});
                        },
                  child: const Text('Open in Matrix'),
                ),
                if (!isDraftItem) ...<Widget>[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () =>
                        widget.controller.toggleRoutineItem(item.id),
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
    _accentedNoteIndices = List<int>.from(item.accentedNoteIndices)..sort();
    _ghostNoteIndices = List<int>.from(item.ghostNoteIndices)..sort();
    _voiceAssignments = List<DrumVoiceV1>.from(
      widget.controller.noteVoicesFor(item.id),
    );
    _competency = widget.controller.competencyFor(item.id);
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
    if (_selectedNoteIndices.isEmpty) return;
    setState(() {
      final Set<int> accents = _accentedNoteIndices.toSet();
      final Set<int> ghosts = _ghostNoteIndices.toSet();
      for (final int noteIndex in _selectedNoteIndices) {
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
    if (_selectedNoteIndices.isEmpty) return;
    setState(() {
      final List<DrumVoiceV1> nextAssignments = List<DrumVoiceV1>.from(
        _voiceAssignments,
      );
      for (final int index in _selectedNoteIndices) {
        nextAssignments[index] = next;
      }
      _voiceAssignments = nextAssignments;
      _selectedNoteIndices = <int>{};
    });
  }

  bool _hasDraftFlowVoices(List<String> tokens, List<DrumVoiceV1> voices) {
    for (int index = 0; index < tokens.length; index++) {
      if (tokens[index] == 'K') continue;
      if (voices[index] != DrumVoiceV1.snare) return true;
    }
    return false;
  }

  void _clearVoices() {
    final List<String> tokens = widget.controller.noteTokensFor(widget.itemId);
    setState(() {
      _voiceAssignments = List<DrumVoiceV1>.generate(tokens.length, (
        int index,
      ) {
        return tokens[index] == 'K' ? DrumVoiceV1.kick : DrumVoiceV1.snare;
      });
      _selectedNoteIndices = <int>{};
    });
  }

  bool _hasUnsavedChanges(PracticeItemV1 item) {
    final List<PatternNoteMarkingV1> currentMarkings = widget.controller
        .noteMarkingsFor(item.id);
    final List<PatternNoteMarkingV1> draftMarkings = _draftMarkingsFor(
      item.noteCount,
    );
    return !item.saved ||
        !listEquals(currentMarkings, draftMarkings) ||
        !listEquals(
          widget.controller.noteVoicesFor(item.id),
          _voiceAssignments,
        ) ||
        widget.controller.competencyFor(item.id) != _competency ||
        widget.controller.launchBpmForItem(item.id) != _sessionBpm ||
        widget.controller.launchTimerPresetForItem(item.id) != _timerPreset;
  }

  void _saveDraft({bool saveToWorkingOn = false}) {
    widget.controller.rememberLaunchPreferencesForItem(
      itemId: widget.itemId,
      bpm: _sessionBpm,
      timerPreset: _timerPreset,
    );
    widget.controller.savePracticeItemEdits(
      itemId: widget.itemId,
      accentedNoteIndices: _accentedNoteIndices,
      ghostNoteIndices: _ghostNoteIndices,
      voiceAssignments: _voiceAssignments,
      competency: _competency,
      saveToWorkingOn: saveToWorkingOn,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saveToWorkingOn ? 'Saved to Working On.' : 'Changes saved.',
        ),
      ),
    );
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
        final List<_NotationChunk> chunks = _chunksForWidth(
          maxWidth,
          separators,
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
                      enabled: tokens[index] != 'K',
                      showVoice: showVoices,
                      patternStyle: patternStyle,
                      voiceStyle: voiceStyle,
                      onTap: () => onSelect(index),
                    ),
                    if (separators[index].isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          separators[index],
                          style: patternStyle.copyWith(
                            color: const Color(0xFF6B6254),
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
    List<String> separators,
  ) {
    const double cellWidth = 52;
    const double separatorWidth = 10;
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
            cellWidth + (separators[end].isNotEmpty ? separatorWidth : 0);
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
          width: 52,
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
              RichText(
                textAlign: TextAlign.center,
                softWrap: false,
                text: TextSpan(
                  style: patternStyle,
                  children: switch (marking) {
                    PatternNoteMarkingV1.normal => <InlineSpan>[
                      TextSpan(
                        text: token,
                        style: enabled
                            ? patternStyle
                            : patternStyle.copyWith(
                                color:
                                    (patternStyle.color ??
                                            const Color(0xFF101010))
                                        .withValues(alpha: 0.45),
                              ),
                      ),
                    ],
                    PatternNoteMarkingV1.accent => <InlineSpan>[
                      TextSpan(text: '^', style: patternStyle),
                      TextSpan(text: token, style: patternStyle),
                    ],
                    PatternNoteMarkingV1.ghost => <InlineSpan>[
                      TextSpan(text: '(', style: patternStyle),
                      TextSpan(
                        text: token,
                        style: patternStyle.copyWith(
                          fontSize: (patternStyle.fontSize ?? 28) * 0.84,
                          color: (patternStyle.color ?? const Color(0xFF101010))
                              .withValues(alpha: 0.72),
                        ),
                      ),
                      TextSpan(text: ')', style: patternStyle),
                    ],
                  },
                ),
              ),
              if (showVoice) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  voice.shortLabel,
                  style: voiceStyle,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
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
    if (selectedIndices.isEmpty) {
      return Text(
        'Select one or more hand notes to set accents or ghosts.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF5B5345),
          fontWeight: FontWeight.w700,
        ),
      );
    }
    final List<int> sortedIndices = selectedIndices.toList()..sort();
    final Set<PatternNoteMarkingV1> currentValues = sortedIndices
        .map((int index) => markings[index])
        .toSet();
    final PatternNoteMarkingV1? current = currentValues.length == 1
        ? currentValues.first
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _selectionLabel(sortedIndices, tokens, current),
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
                  onPressed: () => onChanged(option),
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
    List<int> indices,
    List<String> tokens,
    PatternNoteMarkingV1? current,
  ) {
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
    if (selectedIndices.isEmpty) {
      return Text(
        'Select one or more hand notes to assign a voice.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF5B5345),
          fontWeight: FontWeight.w700,
        ),
      );
    }
    final List<int> sortedIndices = selectedIndices.toList()..sort();
    final Set<DrumVoiceV1> currentValues = sortedIndices
        .map((int index) => voices[index])
        .toSet();
    final DrumVoiceV1? current = currentValues.length == 1
        ? currentValues.first
        : null;

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
          current == null
              ? '${sortedIndices.length} notes selected'
              : '${sortedIndices.length} notes selected · ${current.shortLabel}',
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
                  onPressed: () => onChanged(option),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
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
