import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/drumcabulary_theme.dart';
import '../../features/app/drumcabulary_ui.dart';
import '../../features/app/unsaved_changes_dialog.dart';
import '../../state/app_controller.dart';
import '../practice/widgets/pattern_text_styles.dart';
import '../practice/widgets/sheet_notation_display.dart';

class PatternScreen extends StatefulWidget {
  final AppController controller;
  final String itemId;

  const PatternScreen({
    super.key,
    required this.controller,
    required this.itemId,
  });

  @override
  State<PatternScreen> createState() => _PatternScreenState();
}

class _PatternScreenState extends State<PatternScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _tagsController;
  late final TextEditingController _notesController;
  late final TextEditingController _patternController;
  late final FocusNode _patternFocusNode;

  final List<_PatternDraftSnapshot> _undoStack = <_PatternDraftSnapshot>[];
  String? _validationMessage;
  TextSelection _lastPatternSelection = const TextSelection.collapsed(
    offset: 0,
  );

  @override
  void initState() {
    super.initState();
    final PracticeItemV1 item = widget.controller.itemById(widget.itemId);
    _titleController = TextEditingController(text: item.name);
    _tagsController = TextEditingController(text: item.tags.join(', '));
    _notesController = TextEditingController(text: item.notes);
    _patternController = TextEditingController(
      text: _initialPatternTextFor(item),
    );
    _patternFocusNode = FocusNode();
    _patternController.addListener(_handlePatternControllerChanged);
  }

  @override
  void dispose() {
    _patternController.removeListener(_handlePatternControllerChanged);
    _titleController.dispose();
    _tagsController.dispose();
    _notesController.dispose();
    _patternController.dispose();
    _patternFocusNode.dispose();
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
            if (navigator.canPop()) navigator.pop();
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        final bool hasUnsavedChanges = _hasUnsavedChanges(item);
        return PopScope(
          canPop: !hasUnsavedChanges,
          onPopInvokedWithResult: (bool didPop, Object? result) async {
            if (didPop || !hasUnsavedChanges || !mounted) return;
            final bool shouldPop = await _handleUnsavedExit(item);
            if (shouldPop && mounted) Navigator.of(this.context).pop();
          },
          child: Scaffold(
            appBar: AppBar(title: const Text('Pattern')),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: <Widget>[
                DrumPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const DrumSectionTitle(text: 'Pattern Details'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _tagsController,
                        decoration: const InputDecoration(
                          labelText: 'Tags',
                          hintText: 'fill, warmup, groove',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        keyboardType: TextInputType.multiline,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                DrumPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const DrumSectionTitle(text: 'Pattern Text'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _patternController,
                        focusNode: _patternFocusNode,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        enableSuggestions: false,
                        smartDashesType: SmartDashesType.disabled,
                        smartQuotesType: SmartQuotesType.disabled,
                        minLines: 3,
                        maxLines: 6,
                        style: PatternTextStyles.editableInput(
                          context,
                        ).copyWith(fontSize: 28, height: 1.25),
                        inputFormatters: const <TextInputFormatter>[
                          _PatternTextInputFormatter(),
                        ],
                        decoration: const InputDecoration(
                          hintText: 'RLRLL K RLRLL RLRLL X',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(16),
                        ),
                        onChanged: _handlePatternTextChanged,
                      ),
                      if (_validationMessage != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          _validationMessage!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFF9D2B24)),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _PatternHelperRow(
                        hasSelection: _hasPatternSelection,
                        onAccent: () => _transformSelectedNotes(
                          DrumSheetPatternParser.toggleAccent,
                        ),
                        onGhost: () => _transformSelectedNotes(
                          DrumSheetPatternParser.toggleGhost,
                        ),
                        onCombine: _combineSelectedNotes,
                        onInsertRest: _insertRest,
                      ),
                      const SizedBox(height: 10),
                      _PatternUtilityRow(
                        canUndo: _undoStack.isNotEmpty,
                        onUndo: _undoStack.isEmpty ? null : _undo,
                        onShowLegend: _showInputLegend,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: hasUnsavedChanges ? () => _savePattern() : null,
                  child: const Text('Save Pattern'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _initialPatternTextFor(PracticeItemV1 item) {
    final String pattern = item.pattern.trim();
    if (pattern.isNotEmpty) return pattern.toUpperCase();
    return DrumSheetPatternParser.serialize(_sheetNotesForItem(item));
  }

  void _handlePatternControllerChanged() {
    final TextSelection selection = _patternController.selection;
    if (selection == _lastPatternSelection) return;
    _lastPatternSelection = selection;
    if (mounted) setState(() {});
  }

  void _handlePatternTextChanged(String value) {
    _validatePattern(value, lenient: true);
    setState(() {});
  }

  bool get _hasPatternSelection {
    final TextSelection selection = _patternController.selection;
    return selection.isValid && !selection.isCollapsed;
  }

  bool _hasUnsavedChanges(PracticeItemV1 item) {
    return !item.saved ||
        _titleController.text.trim() != item.name.trim() ||
        _patternController.text.trim().toUpperCase() !=
            _initialPatternTextFor(item).trim().toUpperCase() ||
        _tagListFromText(_tagsController.text).join('|') !=
            item.tags.map((String tag) => tag.trim()).join('|') ||
        _notesController.text.trim() != item.notes.trim();
  }

  void _validatePattern(String value, {required bool lenient}) {
    try {
      DrumSheetPatternParser.parse(value.toUpperCase(), lenient: lenient);
      _validationMessage = null;
    } on FormatException catch (error) {
      _validationMessage = error.message;
    } on ArgumentError catch (error) {
      _validationMessage = error.message ?? 'Invalid pattern.';
    }
  }

  void _recordUndo() {
    final _PatternDraftSnapshot snapshot = _PatternDraftSnapshot(
      title: _titleController.text,
      tags: _tagsController.text,
      notes: _notesController.text,
      pattern: _patternController.text,
      selection: _patternController.selection,
    );
    if (_undoStack.isNotEmpty && _undoStack.last == snapshot) return;
    _undoStack.add(snapshot);
    if (_undoStack.length > 50) _undoStack.removeAt(0);
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final _PatternDraftSnapshot snapshot = _undoStack.removeLast();
    setState(() {
      _titleController.text = snapshot.title;
      _tagsController.text = snapshot.tags;
      _notesController.text = snapshot.notes;
      _patternController.value = TextEditingValue(
        text: snapshot.pattern,
        selection: snapshot.selection,
      );
      _validatePattern(snapshot.pattern, lenient: true);
    });
  }

  void _transformSelectedNotes(
    List<DrumSheetNotationNote> Function(List<DrumSheetNotationNote>, Set<int>)
    transform,
  ) {
    final _PatternSelection? selection = _selectedPatternText();
    if (selection == null) return;
    try {
      final List<DrumSheetNotationNote> notes = DrumSheetPatternParser.parse(
        selection.text,
      );
      if (notes.isEmpty) return;
      _recordUndo();
      final List<DrumSheetNotationNote> edited = transform(
        notes,
        Set<int>.from(Iterable<int>.generate(notes.length)),
      );
      _replaceSelectedPatternText(DrumSheetPatternParser.serialize(edited));
    } on FormatException catch (error) {
      setState(() => _validationMessage = error.message);
    } on ArgumentError catch (error) {
      setState(() => _validationMessage = error.message ?? 'Invalid pattern.');
    }
  }

  void _combineSelectedNotes() {
    final _PatternSelection? selection = _selectedPatternText();
    if (selection == null) return;
    try {
      final String body = selection.text.replaceAll(RegExp(r'\s+'), '');
      final List<DrumSheetNotationNote> notes = DrumSheetPatternParser.parse(
        body,
      );
      if (notes.length < 2) {
        setState(() {
          _validationMessage =
              'Select at least two notes to combine into a simultaneous hit.';
        });
        return;
      }
      final String replacement = '[$body]';
      DrumSheetPatternParser.parse(replacement);
      _recordUndo();
      _replaceSelectedPatternText(replacement);
    } on FormatException catch (error) {
      setState(() => _validationMessage = error.message);
    } on ArgumentError catch (error) {
      setState(() => _validationMessage = error.message ?? 'Invalid pattern.');
    }
  }

  void _insertRest() {
    _recordUndo();
    final TextSelection selection = _patternController.selection;
    final int start = selection.isValid
        ? selection.start
        : _patternController.text.length;
    final int end = selection.isValid ? selection.end : start;
    final String text = _patternController.text;
    final String next = text.replaceRange(start, end, '_');
    _patternController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + 1),
    );
    _validatePattern(next, lenient: true);
    setState(() {});
  }

  _PatternSelection? _selectedPatternText() {
    final TextSelection selection = _patternController.selection;
    if (!selection.isValid || selection.isCollapsed) return null;
    final int start = selection.start < selection.end
        ? selection.start
        : selection.end;
    final int end = selection.start < selection.end
        ? selection.end
        : selection.start;
    return _PatternSelection(
      start: start,
      end: end,
      text: _patternController.text.substring(start, end),
    );
  }

  void _replaceSelectedPatternText(String replacement) {
    final _PatternSelection? selection = _selectedPatternText();
    if (selection == null) return;
    final String next = _patternController.text.replaceRange(
      selection.start,
      selection.end,
      replacement,
    );
    _patternController.value = TextEditingValue(
      text: next,
      selection: TextSelection(
        baseOffset: selection.start,
        extentOffset: selection.start + replacement.length,
      ),
    );
    _validatePattern(next, lenient: true);
    setState(() {});
  }

  String _savePattern() {
    final String patternText = _patternController.text.trim().toUpperCase();
    final List<DrumSheetNotationNote> parsedNotes;
    try {
      parsedNotes = DrumSheetPatternParser.parse(patternText);
      if (parsedNotes.isEmpty) {
        setState(() {
          _validationMessage = 'Enter a pattern before saving.';
        });
        return widget.itemId;
      }
    } on FormatException catch (error) {
      setState(() => _validationMessage = error.message);
      return widget.itemId;
    } on ArgumentError catch (error) {
      setState(() => _validationMessage = error.message ?? 'Invalid pattern.');
      return widget.itemId;
    }

    final List<PatternTokenV1> tokens = parsedNotes
        .map(_legacyTokenForSheetNote)
        .toList(growable: false);
    final String savedItemId = widget.controller.savePracticeItemEdits(
      itemId: widget.itemId,
      accentedNoteIndices: _accentIndicesFor(parsedNotes),
      ghostNoteIndices: _ghostIndicesFor(parsedNotes),
      voiceAssignments: parsedNotes
          .map(_legacyVoiceForSheetNote)
          .toList(growable: false),
      competency: widget.controller.competencyFor(widget.itemId),
      name: _titleController.text.trim(),
      tags: _tagListFromText(_tagsController.text),
      notes: _notesController.text.trim(),
      sequence: PatternSequenceV1(tokens: tokens),
      pattern: patternText,
      groupingHint: PatternGroupingV1.none,
      beatGrouping: _groupingTextFromPattern(patternText),
      noteValueOverrides: parsedNotes
          .map((DrumSheetNotationNote note) => _storedValueFor(note.value))
          .toList(growable: false),
      saveAsPattern: true,
    );
    _undoStack.clear();
    _patternController.value = TextEditingValue(
      text: patternText,
      selection: TextSelection.collapsed(offset: patternText.length),
    );
    setState(() => _validationMessage = null);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Pattern saved.')));
    return savedItemId;
  }

  Future<bool> _handleUnsavedExit(PracticeItemV1 item) async {
    final UnsavedChangesDecision? decision = await showUnsavedChangesDialog(
      context,
      title: 'Unsaved Changes',
      message: item.saved
          ? 'Save your changes to this pattern before leaving?'
          : 'Save this pattern before leaving?',
      saveLabel: 'Save Pattern',
    );
    if (!mounted) return false;
    return switch (decision) {
      UnsavedChangesDecision.save => () {
        _savePattern();
        return true;
      }(),
      UnsavedChangesDecision.discard => () {
        if (!item.saved) widget.controller.discardUnsavedPracticeItem(item.id);
        return true;
      }(),
      _ => false,
    };
  }

  Future<void> _showInputLegend() {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: DrumcabularyTheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: DrumcabularyTheme.line),
          ),
          title: const Text('Notation'),
          content: const _PatternInputLegend(),
          actions: <Widget>[
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _PatternHelperRow extends StatelessWidget {
  final bool hasSelection;
  final VoidCallback onAccent;
  final VoidCallback onGhost;
  final VoidCallback onCombine;
  final VoidCallback onInsertRest;

  const _PatternHelperRow({
    required this.hasSelection,
    required this.onAccent,
    required this.onGhost,
    required this.onCombine,
    required this.onInsertRest,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        OutlinedButton(
          onPressed: hasSelection ? onAccent : null,
          child: const Text('Accent'),
        ),
        OutlinedButton(
          onPressed: hasSelection ? onGhost : null,
          child: const Text('Ghost'),
        ),
        OutlinedButton(
          onPressed: hasSelection ? onCombine : null,
          child: const Text('Combine'),
        ),
        OutlinedButton(
          onPressed: onInsertRest,
          child: const Text('Insert Rest'),
        ),
      ],
    );
  }
}

class _PatternUtilityRow extends StatelessWidget {
  final bool canUndo;
  final VoidCallback? onUndo;
  final VoidCallback onShowLegend;

  const _PatternUtilityRow({
    required this.canUndo,
    required this.onUndo,
    required this.onShowLegend,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: canUndo ? onUndo : null,
          icon: const Icon(Icons.undo),
          label: const Text('Undo'),
        ),
        OutlinedButton.icon(
          onPressed: onShowLegend,
          icon: const Icon(Icons.help_outline),
          label: const Text('Notation'),
        ),
      ],
    );
  }
}

class _PatternTextInputFormatter extends TextInputFormatter {
  const _PatternTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String upper = newValue.text.toUpperCase();
    if (upper == newValue.text) return newValue;
    return newValue.copyWith(text: upper, composing: TextRange.empty);
  }
}

class _PatternInputLegend extends StatelessWidget {
  const _PatternInputLegend();

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.bodyMedium;
    return DefaultTextStyle.merge(
      style: style,
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        children: const <Widget>[
          _LegendEntry(token: 'R', text: 'right hand'),
          _LegendEntry(token: 'L', text: 'left hand'),
          _LegendEntry(token: 'K', text: 'kick'),
          _LegendEntry(token: 'F', text: 'flam'),
          _LegendEntry(token: 'X', text: 'accent / crash / big hit'),
          _LegendEntry(token: '_', text: 'rest'),
          _LegendEntry(token: '^R', text: 'accent'),
          _LegendEntry(token: '(L)', text: 'ghost'),
          _LegendEntry(token: '[XK]', text: 'simultaneous hit'),
          _LegendEntry(token: '[RL]', text: 'right + left together'),
          _LegendEntry(token: '[T1:L]', text: 'voice override'),
          _LegendEntry(token: '[32:R]', text: 'duration override text'),
          _LegendEntry(token: '[T1 16:L]', text: 'voice + duration text'),
          _LegendEntry(token: 'RLR LK', text: 'space-defined phrasing'),
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
class _PatternSelection {
  final int start;
  final int end;
  final String text;

  const _PatternSelection({
    required this.start,
    required this.end,
    required this.text,
  });
}

@immutable
class _PatternDraftSnapshot {
  final String title;
  final String tags;
  final String notes;
  final String pattern;
  final TextSelection selection;

  const _PatternDraftSnapshot({
    required this.title,
    required this.tags,
    required this.notes,
    required this.pattern,
    required this.selection,
  });
}

List<String> _tagListFromText(String text) {
  return text
      .split(',')
      .map((String tag) => tag.trim())
      .where((String tag) => tag.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

List<int> _accentIndicesFor(List<DrumSheetNotationNote> notes) {
  return <int>[
    for (int index = 0; index < notes.length; index += 1)
      if (notes[index].accent) index,
  ];
}

List<int> _ghostIndicesFor(List<DrumSheetNotationNote> notes) {
  return <int>[
    for (int index = 0; index < notes.length; index += 1)
      if (notes[index].ghost) index,
  ];
}

PatternTokenV1 _legacyTokenForSheetNote(DrumSheetNotationNote note) {
  if (note.rest) return PatternTokenV1.rest;
  if (note.flam) return PatternTokenV1.flam;
  return switch (note.sticking.toUpperCase()) {
    'R' => PatternTokenV1.right,
    'L' => PatternTokenV1.left,
    'K' => PatternTokenV1.kick,
    'F' => PatternTokenV1.flam,
    'X' => PatternTokenV1.accent,
    _ =>
      note.voices.contains(DrumSheetVoice.kick)
          ? PatternTokenV1.kick
          : PatternTokenV1.right,
  };
}

DrumVoiceV1 _legacyVoiceForSheetNote(DrumSheetNotationNote note) {
  if (note.rest || note.voices.isEmpty) return DrumVoiceV1.snare;
  return switch (note.voices.first) {
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

PatternNoteValueV1? _storedValueFor(DrumSheetNoteValue? value) {
  return switch (value) {
    null => null,
    DrumSheetNoteValue.whole => PatternNoteValueV1.whole,
    DrumSheetNoteValue.half => PatternNoteValueV1.half,
    DrumSheetNoteValue.quarter => PatternNoteValueV1.quarter,
    DrumSheetNoteValue.eighth => PatternNoteValueV1.eighth,
    DrumSheetNoteValue.sixteenth => PatternNoteValueV1.sixteenth,
    DrumSheetNoteValue.thirtySecond => PatternNoteValueV1.thirtySecond,
  };
}

DrumSheetNoteValue? _sheetValueFor(PatternNoteValueV1? value) {
  return switch (value) {
    null => null,
    PatternNoteValueV1.whole => DrumSheetNoteValue.whole,
    PatternNoteValueV1.half => DrumSheetNoteValue.half,
    PatternNoteValueV1.quarter => DrumSheetNoteValue.quarter,
    PatternNoteValueV1.eighth => DrumSheetNoteValue.eighth,
    PatternNoteValueV1.sixteenth => DrumSheetNoteValue.sixteenth,
    PatternNoteValueV1.thirtySecond => DrumSheetNoteValue.thirtySecond,
  };
}

String _groupingTextFromPattern(String pattern) {
  final List<String> groups = _topLevelPatternGroups(pattern);
  if (groups.length <= 1) return '';
  final List<String> counts = <String>[];
  for (final String group in groups) {
    final int count = DrumSheetPatternParser.parse(group, lenient: true).length;
    if (count > 0) counts.add('$count');
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

List<DrumSheetNotationNote> _sheetNotesForItem(PracticeItemV1 item) {
  final List<PatternNoteMarkingV1> markings = <PatternNoteMarkingV1>[
    for (int index = 0; index < item.tokens.length; index += 1)
      item.ghostNoteIndices.contains(index)
          ? PatternNoteMarkingV1.ghost
          : item.accentedNoteIndices.contains(index)
          ? PatternNoteMarkingV1.accent
          : PatternNoteMarkingV1.normal,
  ];
  return <DrumSheetNotationNote>[
    for (int index = 0; index < item.tokens.length; index += 1)
      _sheetNoteForToken(
        item.tokens[index],
        marking: markings[index],
        voice: index < item.voiceAssignments.length
            ? item.voiceAssignments[index]
            : null,
        value: index < item.noteValueOverrides.length
            ? _sheetValueFor(item.noteValueOverrides[index])
            : null,
      ),
  ];
}

DrumSheetNotationNote _sheetNoteForToken(
  PatternTokenV1 token, {
  required PatternNoteMarkingV1 marking,
  required DrumVoiceV1? voice,
  required DrumSheetNoteValue? value,
}) {
  final bool rest = token.isRest;
  return DrumSheetNotationNote(
    value: value,
    voices: rest
        ? const <DrumSheetVoice>[]
        : _sheetVoicesForToken(token, voice),
    rest: rest,
    sticking: token.symbol,
    accent: marking == PatternNoteMarkingV1.accent,
    ghost: marking == PatternNoteMarkingV1.ghost,
    flam: token.kind == PatternTokenKindV1.flam,
  );
}

List<DrumSheetVoice> _sheetVoicesForToken(
  PatternTokenV1 token,
  DrumVoiceV1? voice,
) {
  return switch (token.kind) {
    PatternTokenKindV1.kick => const <DrumSheetVoice>[DrumSheetVoice.kick],
    PatternTokenKindV1.accent => const <DrumSheetVoice>[DrumSheetVoice.crash],
    PatternTokenKindV1.flam => const <DrumSheetVoice>[DrumSheetVoice.snare],
    PatternTokenKindV1.rest => const <DrumSheetVoice>[],
    PatternTokenKindV1.right || PatternTokenKindV1.left => <DrumSheetVoice>[
      _sheetVoiceForLegacyVoice(voice ?? DrumVoiceV1.snare),
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
