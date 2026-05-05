import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../features/app/drumcabulary_theme.dart';
import '../../features/app/drumcabulary_ui.dart';
import '../../features/app/unsaved_changes_dialog.dart';
import '../../state/app_controller.dart';
import '../practice/widgets/sheet_notation_display.dart';
import '../practice/widgets/session_setup_controls.dart';
import '../practice/widgets/pattern_text_styles.dart';

enum _ItemEditorControlSet { build, dynamics, voices }

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
  late List<DrumSheetNoteValue?> _durationOverrides;
  late DrumSheetNoteValue _draftSubdivision;
  late int _sessionBpm;
  late TimerPresetV1 _timerPreset;
  late Set<int> _selectedNoteIndices;
  late final TextEditingController _patternController;
  late final TextEditingController _groupingController;
  final List<_DraftSnapshot> _undoStack = <_DraftSnapshot>[];
  String _lastPatternText = '';
  String _lastGroupingText = '';
  _ItemEditorControlSet _activeControlSet = _ItemEditorControlSet.build;

  @override
  void initState() {
    super.initState();
    _loadDraftFromController();
    final PracticeItemV1 item = widget.controller.itemById(widget.itemId);
    _lastPatternText = _draftPatternText();
    _lastGroupingText = _initialGroupingTextForItem(item);
    _patternController = TextEditingController(text: _lastPatternText);
    _groupingController = TextEditingController(text: _lastGroupingText);
  }

  @override
  void dispose() {
    _patternController.dispose();
    _groupingController.dispose();
    super.dispose();
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
                        TextField(
                          controller: _patternController,
                          textAlignVertical: TextAlignVertical.center,
                          style: PatternTextStyles.editableInput(context),
                          strutStyle: const StrutStyle(
                            fontSize: PatternTextStyles.editableInputFontSize,
                            height: PatternTextStyles.editableInputLineHeight,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Pattern',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding:
                                PatternTextStyles.editableInputPadding,
                          ),
                          onChanged: _handlePatternTextChanged,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child:
                                  DropdownButtonFormField<DrumSheetNoteValue>(
                                    key: ValueKey<DrumSheetNoteValue>(
                                      _draftSubdivision,
                                    ),
                                    initialValue: _draftSubdivision,
                                    decoration: const InputDecoration(
                                      labelText: 'Subdivision',
                                      border: OutlineInputBorder(),
                                    ),
                                    items:
                                        <DropdownMenuItem<DrumSheetNoteValue>>[
                                          for (final DrumSheetNoteValue value
                                              in DrumSheetNoteValue.values)
                                            DropdownMenuItem<
                                              DrumSheetNoteValue
                                            >(
                                              value: value,
                                              child: Text(
                                                '1/${value.patternLabel}',
                                              ),
                                            ),
                                        ],
                                    onChanged: (DrumSheetNoteValue? next) {
                                      if (next == null) return;
                                      _recordUndo();
                                      setState(() {
                                        _draftSubdivision = next;
                                        _syncPatternTextFromDraft();
                                      });
                                    },
                                  ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _groupingController,
                                decoration: const InputDecoration(
                                  labelText: 'Grouping',
                                  hintText: '4, 3535, 3 5 3 5',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: _handleGroupingTextChanged,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _SheetNotationControls(
                          canUndo: _undoStack.isNotEmpty,
                          onUndo: _undoStack.isEmpty ? null : _undoDraftEdit,
                          onShowLegend: _showSheetNotationLegend,
                        ),
                        const SizedBox(height: 12),
                        DrumSheetNotationDisplay(
                          document: _draftSheetNotationDocument(draftMarkings),
                          grouping: _effectiveGroupingText(),
                          selectedIndexes: _selectedNoteIndices,
                          onSelectionChanged: (Set<int> next) {
                            setState(() => _selectedNoteIndices = next);
                          },
                          minNoteWidth: 40,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap notes to select them, or edit the pattern text directly.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: DrumcabularyTheme.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _SelectedSheetNoteEditor(
                          activeControlSet: _activeControlSet,
                          notes: _draftSheetNotes(draftMarkings),
                          selectedIndices: _selectedNoteIndices,
                          subdivision: _draftSubdivision,
                          onControlSetChanged: (_ItemEditorControlSet next) =>
                              setState(() {
                                _activeControlSet = next;
                              }),
                          onDurationChanged: _setDurationForSelection,
                          onVoiceChanged: _setSheetVoiceForSelection,
                          onToggleAccent: _toggleAccentForSelection,
                          onToggleGhost: _toggleGhostForSelection,
                          onDeleteSelection: _deleteSelection,
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
    _durationOverrides = _sheetNoteValuesForStoredOverrides(
      item.noteValueOverrides,
      _draftTokens.length,
    );
    _draftSubdivision = _sheetNoteValueForStoredValue(item.notationSubdivision);
    _sessionBpm = widget.controller.launchBpmForItem(item.id);
    _timerPreset = widget.controller.launchTimerPresetForItem(item.id);
    _selectedNoteIndices = <int>{};
    _undoStack.clear();
  }

  DrumSheetNotationDocument _draftSheetNotationDocument(
    List<PatternNoteMarkingV1> markings,
  ) {
    return DrumSheetNotationDocument(
      subdivision: _draftSubdivision,
      measures: <DrumSheetNotationMeasure>[
        DrumSheetNotationMeasure(notes: _draftSheetNotes(markings)),
      ],
    );
  }

  List<DrumSheetNotationNote> _draftSheetNotes(
    List<PatternNoteMarkingV1> markings,
  ) {
    return List<DrumSheetNotationNote>.generate(_draftTokens.length, (
      int index,
    ) {
      return _sheetNoteForDraftIndex(index, markings[index]);
    }, growable: false);
  }

  String _draftPatternText() {
    return DrumSheetPatternParser.serialize(
      _draftSheetNotes(_draftMarkingsFor(_draftTokens.length)),
      subdivision: _draftSubdivision,
    );
  }

  void _syncPatternTextFromDraft() {
    final String next = _draftPatternText();
    if (_patternController.text == next) {
      _lastPatternText = next;
      return;
    }
    _patternController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _lastPatternText = next;
  }

  DrumSheetNotationNote _sheetNoteForDraftIndex(
    int index,
    PatternNoteMarkingV1 marking,
  ) {
    final PatternTokenV1 token = _draftTokens[index];
    final DrumVoiceV1 oldVoice = index < _voiceAssignments.length
        ? _voiceAssignments[index]
        : _defaultVoiceForDraftToken(token);
    return DrumSheetNotationNote(
      value: index < _durationOverrides.length
          ? _durationOverrides[index]
          : null,
      voices: token.isRest
          ? const <DrumSheetVoice>[]
          : _sheetVoicesForDraftToken(token, oldVoice),
      rest: token.isRest,
      sticking: _sheetStickingForDraftToken(token),
      accent: marking == PatternNoteMarkingV1.accent,
      ghost: marking == PatternNoteMarkingV1.ghost,
      flam: token.kind == PatternTokenKindV1.flam,
    );
  }

  List<DrumSheetVoice> _sheetVoicesForDraftToken(
    PatternTokenV1 token,
    DrumVoiceV1 oldVoice,
  ) {
    return switch (token.kind) {
      PatternTokenKindV1.kick => const <DrumSheetVoice>[DrumSheetVoice.kick],
      PatternTokenKindV1.both => const <DrumSheetVoice>[
        DrumSheetVoice.hihat,
        DrumSheetVoice.snare,
      ],
      PatternTokenKindV1.accent => const <DrumSheetVoice>[DrumSheetVoice.crash],
      PatternTokenKindV1.flam => const <DrumSheetVoice>[DrumSheetVoice.snare],
      PatternTokenKindV1.rest => const <DrumSheetVoice>[],
      PatternTokenKindV1.right || PatternTokenKindV1.left => <DrumSheetVoice>[
        _sheetVoiceForLegacyVoice(oldVoice),
      ],
    };
  }

  DrumSheetVoice _sheetVoiceForLegacyVoice(DrumVoiceV1 voice) {
    return switch (voice) {
      DrumVoiceV1.snare => DrumSheetVoice.snare,
      DrumVoiceV1.rackTom => DrumSheetVoice.tom1,
      DrumVoiceV1.tom2 => DrumSheetVoice.tom2,
      DrumVoiceV1.floorTom => DrumSheetVoice.floorTom,
      DrumVoiceV1.hihat => DrumSheetVoice.hihat,
      DrumVoiceV1.crash => DrumSheetVoice.crash,
      DrumVoiceV1.ride => DrumSheetVoice.ride,
      DrumVoiceV1.kick => DrumSheetVoice.kick,
    };
  }

  String _sheetStickingForDraftToken(PatternTokenV1 token) {
    return switch (token.kind) {
      PatternTokenKindV1.right => 'R',
      PatternTokenKindV1.left => 'L',
      PatternTokenKindV1.kick => 'K',
      PatternTokenKindV1.both => 'B',
      PatternTokenKindV1.flam => 'F',
      PatternTokenKindV1.accent => 'X',
      PatternTokenKindV1.rest => '_',
    };
  }

  String? _sheetGroupingText(PatternGroupingV1 grouping) {
    final int? groupSize = grouping.groupSize;
    if (groupSize == null || groupSize <= 0) return null;
    return '$groupSize';
  }

  String _initialGroupingTextForItem(PracticeItemV1 item) {
    final String beatGrouping = item.beatGrouping.trim();
    if (beatGrouping.isNotEmpty) return beatGrouping;
    return _sheetGroupingText(item.groupingHint) ?? '';
  }

  void _handlePatternTextChanged(String value) {
    try {
      _recordUndo(
        patternText: _lastPatternText,
        groupingText: _lastGroupingText,
      );
      final List<DrumSheetNotationNote> notes = DrumSheetPatternParser.parse(
        value,
        lenient: true,
      );
      final String groupingText = _groupingTextFromPattern(value);
      setState(() {
        if (groupingText.isNotEmpty &&
            groupingText != _groupingController.text.trim()) {
          _groupingController.value = TextEditingValue(
            text: groupingText,
            selection: TextSelection.collapsed(offset: groupingText.length),
          );
          _lastGroupingText = groupingText;
        }
        if (groupingText.isNotEmpty) {
          _draftGrouping = _legacyGroupingForText(groupingText);
        }
        _applySheetNotesToDraft(notes, clearSelection: false);
        _lastPatternText = value;
      });
    } on FormatException {
      // Keep the current rendered draft while the user has an invalid token.
    } on ArgumentError {
      // Keep the current rendered draft while the user has an invalid token.
    }
  }

  void _handleGroupingTextChanged(String value) {
    _recordUndo(groupingText: _lastGroupingText);
    setState(() {
      _draftGrouping = _legacyGroupingForText(value);
      _lastGroupingText = value;
    });
  }

  String? _effectiveGroupingText() {
    final String text = _groupingController.text.trim();
    return text.isEmpty ? null : text;
  }

  String _groupingTextFromPattern(String pattern) {
    final List<String> groups = _topLevelPatternGroups(pattern);
    if (groups.length <= 1) return '';
    final List<String> counts = <String>[];
    for (final String group in groups) {
      final int count = DrumSheetPatternParser.parse(
        group,
        lenient: true,
      ).length;
      if (count <= 0) continue;
      counts.add('$count');
    }
    return counts.length > 1 ? counts.join(' ') : '';
  }

  List<String> _topLevelPatternGroups(String pattern) {
    final List<String> groups = <String>[];
    final StringBuffer current = StringBuffer();
    int bracketDepth = 0;
    int parenDepth = 0;
    for (int index = 0; index < pattern.length; index += 1) {
      final String char = pattern[index];
      if (char == '[') bracketDepth += 1;
      if (char == ']' && bracketDepth > 0) bracketDepth -= 1;
      if (char == '(') parenDepth += 1;
      if (char == ')' && parenDepth > 0) parenDepth -= 1;
      if (char.trim().isEmpty && bracketDepth == 0 && parenDepth == 0) {
        if (current.isNotEmpty) {
          groups.add(current.toString());
          current.clear();
        }
        continue;
      }
      current.write(char);
    }
    if (current.isNotEmpty) groups.add(current.toString());
    return groups;
  }

  PatternGroupingV1 _legacyGroupingForText(String text) {
    final List<int> groups = groupingSizesForText(text);
    if (groups.isEmpty) return PatternGroupingV1.none;
    final int first = groups.first;
    if (groups.any((int group) => group != first)) {
      return PatternGroupingV1.none;
    }
    return PatternGroupingV1(groupSize: first, separator: '-');
  }

  void _applySheetNotesToDraft(
    List<DrumSheetNotationNote> notes, {
    bool clearSelection = true,
  }) {
    _draftTokens = notes.map(_legacyTokenForSheetNote).toList(growable: false);
    _accentedNoteIndices = <int>[
      for (int index = 0; index < notes.length; index += 1)
        if (notes[index].accent) index,
    ];
    _ghostNoteIndices = <int>[
      for (int index = 0; index < notes.length; index += 1)
        if (notes[index].ghost) index,
    ];
    _voiceAssignments = notes
        .map(_legacyVoiceForSheetNote)
        .toList(growable: false);
    _durationOverrides = notes
        .map((DrumSheetNotationNote note) => note.value)
        .toList(growable: false);
    if (clearSelection) _selectedNoteIndices = <int>{};
    _normalizeDraftStructure();
  }

  PatternTokenV1 _legacyTokenForSheetNote(DrumSheetNotationNote note) {
    if (note.rest) return PatternTokenV1.rest;
    if (note.flam) return PatternTokenV1.flam;
    return switch (note.sticking.toUpperCase()) {
      'R' => PatternTokenV1.right,
      'L' => PatternTokenV1.left,
      'K' => PatternTokenV1.kick,
      'B' => PatternTokenV1.both,
      'F' => PatternTokenV1.flam,
      'C' || 'X' => PatternTokenV1.accent,
      'HH' => PatternTokenV1.accent,
      'FT' => PatternTokenV1.left,
      _ =>
        note.voices.contains(DrumSheetVoice.kick)
            ? PatternTokenV1.kick
            : PatternTokenV1.right,
    };
  }

  DrumVoiceV1 _legacyVoiceForSheetNote(DrumSheetNotationNote note) {
    if (note.rest) return DrumVoiceV1.snare;
    if (note.voices.isEmpty) return DrumVoiceV1.snare;
    return _legacyVoiceForSheetVoice(note.voices.first);
  }

  DrumVoiceV1 _legacyVoiceForSheetVoice(DrumSheetVoice voice) {
    return switch (voice) {
      DrumSheetVoice.snare => DrumVoiceV1.snare,
      DrumSheetVoice.tom1 => DrumVoiceV1.rackTom,
      DrumSheetVoice.tom2 => DrumVoiceV1.tom2,
      DrumSheetVoice.floorTom => DrumVoiceV1.floorTom,
      DrumSheetVoice.hihat => DrumVoiceV1.hihat,
      DrumSheetVoice.crash => DrumVoiceV1.crash,
      DrumSheetVoice.ride => DrumVoiceV1.ride,
      DrumSheetVoice.kick => DrumVoiceV1.kick,
    };
  }

  List<DrumSheetNoteValue?> _sheetNoteValuesForStoredOverrides(
    List<PatternNoteValueV1?> values,
    int noteCount,
  ) {
    return List<DrumSheetNoteValue?>.generate(noteCount, (int index) {
      if (index >= values.length) return null;
      final PatternNoteValueV1? value = values[index];
      return value == null ? null : _sheetNoteValueForStoredValue(value);
    }, growable: false);
  }

  List<PatternNoteValueV1?> _storedNoteValuesForSheetValues(
    List<DrumSheetNoteValue?> values,
  ) {
    return values
        .map(
          (DrumSheetNoteValue? value) =>
              value == null ? null : _storedNoteValueForSheetValue(value),
        )
        .toList(growable: false);
  }

  DrumSheetNoteValue _sheetNoteValueForStoredValue(PatternNoteValueV1 value) {
    return switch (value) {
      PatternNoteValueV1.whole => DrumSheetNoteValue.whole,
      PatternNoteValueV1.half => DrumSheetNoteValue.half,
      PatternNoteValueV1.quarter => DrumSheetNoteValue.quarter,
      PatternNoteValueV1.eighth => DrumSheetNoteValue.eighth,
      PatternNoteValueV1.sixteenth => DrumSheetNoteValue.sixteenth,
      PatternNoteValueV1.thirtySecond => DrumSheetNoteValue.thirtySecond,
    };
  }

  PatternNoteValueV1 _storedNoteValueForSheetValue(DrumSheetNoteValue value) {
    return switch (value) {
      DrumSheetNoteValue.whole => PatternNoteValueV1.whole,
      DrumSheetNoteValue.half => PatternNoteValueV1.half,
      DrumSheetNoteValue.quarter => PatternNoteValueV1.quarter,
      DrumSheetNoteValue.eighth => PatternNoteValueV1.eighth,
      DrumSheetNoteValue.sixteenth => PatternNoteValueV1.sixteenth,
      DrumSheetNoteValue.thirtySecond => PatternNoteValueV1.thirtySecond,
    };
  }

  void _setDurationForSelection(DrumSheetNoteValue? value) {
    if (_selectedNoteIndices.isEmpty) return;
    _recordUndo();
    final List<DrumSheetNotationNote> notes =
        DrumSheetPatternParser.applyValueOverride(
          _draftSheetNotes(_draftMarkingsFor(_draftTokens.length)),
          _selectedNoteIndices,
          value,
        );
    setState(() {
      _applySheetNotesToDraft(notes);
      _syncPatternTextFromDraft();
    });
  }

  void _setSheetVoiceForSelection(DrumSheetVoice? voice) {
    if (_selectedNoteIndices.isEmpty) return;
    _recordUndo();
    final List<DrumSheetNotationNote> notes =
        DrumSheetPatternParser.applyVoiceOverride(
          _draftSheetNotes(_draftMarkingsFor(_draftTokens.length)),
          _selectedNoteIndices,
          voice,
        );
    setState(() {
      _applySheetNotesToDraft(notes);
      _syncPatternTextFromDraft();
    });
  }

  void _toggleAccentForSelection() {
    if (_selectedNoteIndices.isEmpty) return;
    _recordUndo();
    final List<DrumSheetNotationNote> notes =
        DrumSheetPatternParser.toggleAccent(
          _draftSheetNotes(_draftMarkingsFor(_draftTokens.length)),
          _selectedNoteIndices,
        );
    setState(() {
      _applySheetNotesToDraft(notes);
      _syncPatternTextFromDraft();
    });
  }

  void _toggleGhostForSelection() {
    if (_selectedNoteIndices.isEmpty) return;
    _recordUndo();
    final List<DrumSheetNotationNote> notes =
        DrumSheetPatternParser.toggleGhost(
          _draftSheetNotes(_draftMarkingsFor(_draftTokens.length)),
          _selectedNoteIndices,
        );
    setState(() {
      _applySheetNotesToDraft(notes);
      _syncPatternTextFromDraft();
    });
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

  bool _supportsMatrixEditingDraft() {
    if (_draftTokens.isEmpty || _draftTokens.length % 3 != 0) return false;
    return !_draftTokens.any((PatternTokenV1 token) => token.isRest);
  }

  DrumVoiceV1 _defaultVoiceForDraftToken(PatternTokenV1 token) {
    return token.isKick ? DrumVoiceV1.kick : DrumVoiceV1.snare;
  }

  void _deleteSelection() {
    final Set<int> selected = Set<int>.from(_selectedNoteIndices);
    if (selected.isEmpty) return;
    _recordUndo();
    final List<PatternTokenV1> nextTokens = <PatternTokenV1>[];
    final List<DrumVoiceV1> nextVoices = <DrumVoiceV1>[];
    final List<DrumSheetNoteValue?> nextDurations = <DrumSheetNoteValue?>[];
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
      nextDurations.add(
        index < _durationOverrides.length ? _durationOverrides[index] : null,
      );
    }

    setState(() {
      _draftTokens = nextTokens;
      _voiceAssignments = nextVoices;
      _durationOverrides = nextDurations;
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
      _syncPatternTextFromDraft();
      _selectedNoteIndices = <int>{};
    });
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
        if (_draftTokens[index].isKick) return DrumVoiceV1.kick;
        if (!_draftTokens[index].allowsAuthoredVoice) return DrumVoiceV1.snare;
        return voice == DrumVoiceV1.kick ? DrumVoiceV1.snare : voice;
      },
      growable: false,
    );
    _voiceAssignments = nextVoices;
    _durationOverrides = List<DrumSheetNoteValue?>.generate(symbols.length, (
      int index,
    ) {
      if (index >= _durationOverrides.length) return null;
      return _durationOverrides[index];
    }, growable: false);
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
        item.beatGrouping.trim() != _groupingController.text.trim() ||
        item.notationSubdivision !=
            _storedNoteValueForSheetValue(_draftSubdivision) ||
        !listEquals(
          item.noteValueOverrides,
          _storedNoteValuesForSheetValues(_durationOverrides),
        ) ||
        !listEquals(
          widget.controller.noteVoicesFor(item.id),
          _voiceAssignments,
        ) ||
        widget.controller.launchBpmForItem(item.id) != _sessionBpm ||
        widget.controller.launchTimerPresetForItem(item.id) != _timerPreset;
  }

  void _recordUndo({String? patternText, String? groupingText}) {
    final _DraftSnapshot snapshot = _DraftSnapshot(
      tokens: List<PatternTokenV1>.from(_draftTokens),
      grouping: _draftGrouping,
      groupingText: groupingText ?? _groupingController.text,
      accentedNoteIndices: List<int>.from(_accentedNoteIndices),
      ghostNoteIndices: List<int>.from(_ghostNoteIndices),
      voiceAssignments: List<DrumVoiceV1>.from(_voiceAssignments),
      durationOverrides: List<DrumSheetNoteValue?>.from(_durationOverrides),
      subdivision: _draftSubdivision,
      selectedNoteIndices: Set<int>.from(_selectedNoteIndices),
      patternText: patternText ?? _draftPatternText(),
    );
    if (_undoStack.isNotEmpty && _undoStack.last == snapshot) return;
    _undoStack.add(snapshot);
    if (_undoStack.length > 50) _undoStack.removeAt(0);
  }

  void _undoDraftEdit() {
    if (_undoStack.isEmpty) return;
    final _DraftSnapshot snapshot = _undoStack.removeLast();
    setState(() {
      _draftTokens = List<PatternTokenV1>.from(snapshot.tokens);
      _draftGrouping = snapshot.grouping;
      _accentedNoteIndices = List<int>.from(snapshot.accentedNoteIndices);
      _ghostNoteIndices = List<int>.from(snapshot.ghostNoteIndices);
      _voiceAssignments = List<DrumVoiceV1>.from(snapshot.voiceAssignments);
      _durationOverrides = List<DrumSheetNoteValue?>.from(
        snapshot.durationOverrides,
      );
      _draftSubdivision = snapshot.subdivision;
      _selectedNoteIndices = Set<int>.from(snapshot.selectedNoteIndices);
      _patternController.value = TextEditingValue(
        text: snapshot.patternText,
        selection: TextSelection.collapsed(offset: snapshot.patternText.length),
      );
      _groupingController.value = TextEditingValue(
        text: snapshot.groupingText,
        selection: TextSelection.collapsed(
          offset: snapshot.groupingText.length,
        ),
      );
      _lastPatternText = snapshot.patternText;
      _lastGroupingText = snapshot.groupingText;
    });
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
      beatGrouping: _groupingController.text.trim(),
      notationSubdivision: _storedNoteValueForSheetValue(_draftSubdivision),
      noteValueOverrides: _storedNoteValuesForSheetValues(_durationOverrides),
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
    _syncPatternTextFromDraft();
    final PracticeItemV1 item = widget.controller.itemById(originalItemId);
    final String groupingText = _initialGroupingTextForItem(item);
    _groupingController.value = TextEditingValue(
      text: groupingText,
      selection: TextSelection.collapsed(offset: groupingText.length),
    );
    _lastGroupingText = groupingText;
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

  Future<void> _showSheetNotationLegend() {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Input legend'),
          content: const _SheetNotationLegend(),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _SheetNotationControls extends StatelessWidget {
  final bool canUndo;
  final VoidCallback? onUndo;
  final VoidCallback onShowLegend;

  const _SheetNotationControls({
    required this.canUndo,
    required this.onUndo,
    required this.onShowLegend,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: canUndo ? onUndo : null,
          icon: const Icon(Icons.undo),
          label: const Text('Undo'),
        ),
        OutlinedButton.icon(
          onPressed: onShowLegend,
          icon: const Icon(Icons.help_outline),
          label: const Text('Input legend'),
        ),
      ],
    );
  }
}

class _SheetNotationLegend extends StatelessWidget {
  const _SheetNotationLegend();

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.bodyMedium;
    return DefaultTextStyle.merge(
      style: style,
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        children: const <Widget>[
          _LegendEntry(token: 'R/L', text: 'snare'),
          _LegendEntry(token: 'K', text: 'kick'),
          _LegendEntry(token: 'HH', text: 'hi-hat'),
          _LegendEntry(token: 'C or X', text: 'crash'),
          _LegendEntry(token: 'FT', text: 'floor tom'),
          _LegendEntry(token: 'F', text: 'flam'),
          _LegendEntry(token: 'B', text: 'hi-hat + snare'),
          _LegendEntry(token: '_', text: 'rest'),
          _LegendEntry(token: '^R', text: 'accent'),
          _LegendEntry(token: '(L)', text: 'ghost'),
          _LegendEntry(token: '[32:R L]', text: 'duration override'),
          _LegendEntry(token: '[T1:L]', text: 'voice override'),
          _LegendEntry(token: '[T1 16:L]', text: 'combined override'),
          _LegendEntry(token: 'RLR LK', text: 'space-defined grouping'),
          _LegendEntry(token: '^[T1:R] or [T1:^R]', text: 'accented override'),
          _LegendEntry(token: '[T1:(L)] or ([T1:L])', text: 'ghosted override'),
          _LegendEntry(token: '^(L)', text: 'invalid'),
        ],
      ),
    );
  }
}

class _LegendEntry extends StatelessWidget {
  final String token;
  final String text;

  const _LegendEntry({required this.token, required this.text});

  @override
  Widget build(BuildContext context) {
    final TextStyle baseStyle = DefaultTextStyle.of(context).style;
    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: <InlineSpan>[
          TextSpan(
            text: '$token: ',
            style: baseStyle.copyWith(fontWeight: FontWeight.w900),
          ),
          TextSpan(text: text),
        ],
      ),
    );
  }
}

@immutable
class _DraftSnapshot {
  final List<PatternTokenV1> tokens;
  final PatternGroupingV1 grouping;
  final String groupingText;
  final List<int> accentedNoteIndices;
  final List<int> ghostNoteIndices;
  final List<DrumVoiceV1> voiceAssignments;
  final List<DrumSheetNoteValue?> durationOverrides;
  final DrumSheetNoteValue subdivision;
  final Set<int> selectedNoteIndices;
  final String patternText;

  const _DraftSnapshot({
    required this.tokens,
    required this.grouping,
    required this.groupingText,
    required this.accentedNoteIndices,
    required this.ghostNoteIndices,
    required this.voiceAssignments,
    required this.durationOverrides,
    required this.subdivision,
    required this.selectedNoteIndices,
    required this.patternText,
  });
}

class _SelectedSheetNoteEditor extends StatelessWidget {
  final _ItemEditorControlSet activeControlSet;
  final List<DrumSheetNotationNote> notes;
  final Set<int> selectedIndices;
  final DrumSheetNoteValue subdivision;
  final ValueChanged<_ItemEditorControlSet> onControlSetChanged;
  final ValueChanged<DrumSheetNoteValue?> onDurationChanged;
  final ValueChanged<DrumSheetVoice?> onVoiceChanged;
  final VoidCallback onToggleAccent;
  final VoidCallback onToggleGhost;
  final VoidCallback onDeleteSelection;

  const _SelectedSheetNoteEditor({
    required this.activeControlSet,
    required this.notes,
    required this.selectedIndices,
    required this.subdivision,
    required this.onControlSetChanged,
    required this.onDurationChanged,
    required this.onVoiceChanged,
    required this.onToggleAccent,
    required this.onToggleGhost,
    required this.onDeleteSelection,
  });

  @override
  Widget build(BuildContext context) {
    final List<int> selected = selectedIndices.toList()..sort();
    final bool hasSelection = selected.isNotEmpty;
    final List<DrumSheetNotationNote> selectedNotes = selected
        .where((int index) => index >= 0 && index < notes.length)
        .map((int index) => notes[index])
        .toList(growable: false);
    final DrumSheetNoteValue? selectedDuration = _singleSelectedDuration(
      selectedNotes,
    );
    final DrumSheetVoice? selectedVoice = _singleSelectedVoice(selectedNotes);
    final bool allAccented =
        selectedNotes.isNotEmpty &&
        selectedNotes.every((DrumSheetNotationNote note) => note.accent);
    final bool allGhosted =
        selectedNotes.isNotEmpty &&
        selectedNotes.every((DrumSheetNotationNote note) => note.ghost);
    final bool canApplyBuildSelection = selectedNotes.isNotEmpty;
    final bool canApplyAccent = selectedNotes.any(_canAccent);
    final bool canApplyGhost = selectedNotes.any(_canGhost);
    final bool canApplyVoice =
        selectedNotes.isNotEmpty && selectedNotes.every(_canAssignVoice);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DrumHorizontalControlStrip(
          child: Row(
            children: <Widget>[
              _ControlSetPill(
                label: 'Build',
                selected: activeControlSet == _ItemEditorControlSet.build,
                onPressed: () =>
                    onControlSetChanged(_ItemEditorControlSet.build),
              ),
              _ControlSetPill(
                label: 'Dynamics',
                selected: activeControlSet == _ItemEditorControlSet.dynamics,
                onPressed: () =>
                    onControlSetChanged(_ItemEditorControlSet.dynamics),
              ),
              _ControlSetPill(
                label: 'Voices',
                selected: activeControlSet == _ItemEditorControlSet.voices,
                onPressed: () =>
                    onControlSetChanged(_ItemEditorControlSet.voices),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          hasSelection
              ? '${selected.length} note${selected.length == 1 ? '' : 's'} selected'
              : _emptySelectionMessage(activeControlSet),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: DrumcabularyTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _SelectedControlSetBody(
          activeControlSet: activeControlSet,
          selectedDuration: selectedDuration,
          selectedVoice: selectedVoice,
          allAccented: allAccented,
          allGhosted: allGhosted,
          canApplyBuildSelection: canApplyBuildSelection,
          canApplyAccent: canApplyAccent,
          canApplyGhost: canApplyGhost,
          canApplyVoice: canApplyVoice,
          onDurationChanged: onDurationChanged,
          onVoiceChanged: onVoiceChanged,
          onToggleAccent: onToggleAccent,
          onToggleGhost: onToggleGhost,
          onDeleteSelection: onDeleteSelection,
        ),
      ],
    );
  }

  String _emptySelectionMessage(_ItemEditorControlSet controlSet) {
    return switch (controlSet) {
      _ItemEditorControlSet.build =>
        'Select notes to edit duration or delete them.',
      _ItemEditorControlSet.dynamics =>
        'Select notes to edit accents or ghosts.',
      _ItemEditorControlSet.voices => 'Select notes to assign drum voices.',
    };
  }

  bool _canAccent(DrumSheetNotationNote note) {
    return !note.rest && note.sticking.toUpperCase() != 'K';
  }

  bool _canGhost(DrumSheetNotationNote note) {
    return !note.rest;
  }

  bool _canAssignVoice(DrumSheetNotationNote note) {
    final String sticking = note.sticking.toUpperCase();
    return !note.rest && (sticking == 'R' || sticking == 'L');
  }

  DrumSheetNoteValue? _singleSelectedDuration(
    List<DrumSheetNotationNote> selectedNotes,
  ) {
    if (selectedNotes.isEmpty) return null;
    final Set<DrumSheetNoteValue?> values = selectedNotes
        .map((DrumSheetNotationNote note) => note.value)
        .toSet();
    if (values.length != 1) return null;
    final DrumSheetNoteValue? value = values.single;
    return value == subdivision ? null : value;
  }

  DrumSheetVoice? _singleSelectedVoice(
    List<DrumSheetNotationNote> selectedNotes,
  ) {
    if (selectedNotes.isEmpty) return null;
    final Set<DrumSheetVoice?> values = selectedNotes.map((
      DrumSheetNotationNote note,
    ) {
      if (note.voices.length != 1) return null;
      return note.voices.single;
    }).toSet();
    if (values.length != 1) return null;
    return values.single;
  }
}

class _ControlSetPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _ControlSetPill({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: DrumSelectablePill(
        label: Text(label),
        selected: selected,
        onPressed: onPressed,
      ),
    );
  }
}

class _SelectedControlSetBody extends StatelessWidget {
  final _ItemEditorControlSet activeControlSet;
  final DrumSheetNoteValue? selectedDuration;
  final DrumSheetVoice? selectedVoice;
  final bool allAccented;
  final bool allGhosted;
  final bool canApplyBuildSelection;
  final bool canApplyAccent;
  final bool canApplyGhost;
  final bool canApplyVoice;
  final ValueChanged<DrumSheetNoteValue?> onDurationChanged;
  final ValueChanged<DrumSheetVoice?> onVoiceChanged;
  final VoidCallback onToggleAccent;
  final VoidCallback onToggleGhost;
  final VoidCallback onDeleteSelection;

  const _SelectedControlSetBody({
    required this.activeControlSet,
    required this.selectedDuration,
    required this.selectedVoice,
    required this.allAccented,
    required this.allGhosted,
    required this.canApplyBuildSelection,
    required this.canApplyAccent,
    required this.canApplyGhost,
    required this.canApplyVoice,
    required this.onDurationChanged,
    required this.onVoiceChanged,
    required this.onToggleAccent,
    required this.onToggleGhost,
    required this.onDeleteSelection,
  });

  @override
  Widget build(BuildContext context) {
    return switch (activeControlSet) {
      _ItemEditorControlSet.build => _buildControls(context),
      _ItemEditorControlSet.dynamics => _dynamicsControls(context),
      _ItemEditorControlSet.voices => _voiceControls(context),
    };
  }

  Widget _buildControls(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 178,
          child: DropdownButtonFormField<DrumSheetNoteValue?>(
            key: ValueKey<DrumSheetNoteValue?>(selectedDuration),
            initialValue: selectedDuration,
            decoration: const InputDecoration(
              labelText: 'Duration Override',
              isDense: true,
            ),
            onChanged: canApplyBuildSelection ? onDurationChanged : null,
            items: <DropdownMenuItem<DrumSheetNoteValue?>>[
              const DropdownMenuItem<DrumSheetNoteValue?>(
                value: null,
                child: Text('Default'),
              ),
              for (final DrumSheetNoteValue value in DrumSheetNoteValue.values)
                DropdownMenuItem<DrumSheetNoteValue?>(
                  value: value,
                  child: Text('1/${value.patternLabel}'),
                ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: canApplyBuildSelection ? onDeleteSelection : null,
          child: const Text('Delete'),
        ),
      ],
    );
  }

  Widget _dynamicsControls(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        OutlinedButton(
          onPressed: canApplyAccent ? onToggleAccent : null,
          child: Text(allAccented ? 'Remove Accent' : 'Accent'),
        ),
        OutlinedButton(
          onPressed: canApplyGhost ? onToggleGhost : null,
          child: Text(allGhosted ? 'Remove Ghost' : 'Ghost'),
        ),
      ],
    );
  }

  Widget _voiceControls(BuildContext context) {
    return SizedBox(
      width: 210,
      child: DropdownButtonFormField<DrumSheetVoice?>(
        key: ValueKey<DrumSheetVoice?>(selectedVoice),
        initialValue: selectedVoice,
        decoration: const InputDecoration(
          labelText: 'Voice Override',
          isDense: true,
        ),
        onChanged: canApplyVoice ? onVoiceChanged : null,
        items: const <DropdownMenuItem<DrumSheetVoice?>>[
          DropdownMenuItem<DrumSheetVoice?>(
            value: null,
            child: Text('Default'),
          ),
          DropdownMenuItem<DrumSheetVoice?>(
            value: DrumSheetVoice.snare,
            child: Text('Snare'),
          ),
          DropdownMenuItem<DrumSheetVoice?>(
            value: DrumSheetVoice.tom1,
            child: Text('Tom 1'),
          ),
          DropdownMenuItem<DrumSheetVoice?>(
            value: DrumSheetVoice.tom2,
            child: Text('Tom 2'),
          ),
          DropdownMenuItem<DrumSheetVoice?>(
            value: DrumSheetVoice.floorTom,
            child: Text('Floor tom'),
          ),
          DropdownMenuItem<DrumSheetVoice?>(
            value: DrumSheetVoice.hihat,
            child: Text('Hi-hat'),
          ),
          DropdownMenuItem<DrumSheetVoice?>(
            value: DrumSheetVoice.crash,
            child: Text('Crash'),
          ),
          DropdownMenuItem<DrumSheetVoice?>(
            value: DrumSheetVoice.ride,
            child: Text('Ride'),
          ),
          DropdownMenuItem<DrumSheetVoice?>(
            value: DrumSheetVoice.kick,
            child: Text('Kick'),
          ),
        ],
      ),
    );
  }
}
