import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/drumcabulary_theme.dart';
import '../../features/app/drumcabulary_ui.dart';
import '../../features/hardware/hardware_capabilities.dart';
import '../../features/midi/drum_kit_mapper.dart';
import '../../features/midi/midi_input_models.dart';
import '../../features/midi/midi_input_service.dart';
import '../../features/midi/midi_pattern_capture.dart';
import '../../features/midi/midi_pattern_capture_panel.dart';
import '../../features/midi/shared_midi_input_service.dart';
import '../../features/app/unsaved_changes_dialog.dart';
import '../../state/app_controller.dart';
import 'exercise_authoring_mapper.dart';
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

enum _PatternEditContext { dynamics, voices }

@immutable
class _VoiceOption {
  final DrumSheetVoice voice;
  final String label;

  const _VoiceOption(this.voice, this.label);
}

const List<_VoiceOption> _voiceOptions = <_VoiceOption>[
  _VoiceOption(DrumSheetVoice.snare, 'Snare'),
  _VoiceOption(DrumSheetVoice.tom1, 'T1'),
  _VoiceOption(DrumSheetVoice.tom2, 'T2'),
  _VoiceOption(DrumSheetVoice.floorTom, 'FT'),
  _VoiceOption(DrumSheetVoice.hihat, 'HH'),
  _VoiceOption(DrumSheetVoice.openHiHat, 'OHH'),
  _VoiceOption(DrumSheetVoice.crash, 'Crash'),
  _VoiceOption(DrumSheetVoice.ride, 'Ride'),
  _VoiceOption(DrumSheetVoice.kick, 'Kick'),
];

int _voiceSortOrder(DrumSheetVoice voice) {
  return switch (voice) {
    DrumSheetVoice.snare => 0,
    DrumSheetVoice.tom1 => 1,
    DrumSheetVoice.tom2 => 2,
    DrumSheetVoice.floorTom => 3,
    DrumSheetVoice.hihat => 4,
    DrumSheetVoice.openHiHat => 5,
    DrumSheetVoice.crash => 6,
    DrumSheetVoice.ride => 7,
    DrumSheetVoice.kick => 8,
  };
}

bool _isPatternLimb(String value) {
  final String normalized = value.toUpperCase();
  return normalized == 'R' || normalized == 'L';
}

class _PatternScreenState extends State<PatternScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _tagsController;
  late final TextEditingController _notesController;
  late final TextEditingController _patternController;
  late final FocusNode _patternFocusNode;
  late final MidiPatternCaptureController _captureController;
  MidiInputService? _midiInputService;
  StreamSubscription<RawMidiEvent>? _midiCaptureSubscription;
  final DrumKitMapper _drumKitMapper = const DrumKitMapper();

  final List<_PatternDraftSnapshot> _undoStack = <_PatternDraftSnapshot>[];
  String? _validationMessage;
  Set<int> _selectedNoteIndexes = const <int>{};
  _PatternEditContext _editContext = _PatternEditContext.dynamics;
  bool _syncingPatternSelectionFromNotation = false;
  bool _notationSelectionOwnsPatternRange = false;
  TextSelection _lastPatternSelection = const TextSelection.collapsed(
    offset: 0,
  );
  String? _captureMessage;

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
    _patternFocusNode.addListener(_handlePatternFocusChanged);
    _captureController = MidiPatternCaptureController()
      ..addListener(_handleCaptureChanged);
    if (HardwareCapabilities.supportsPatternMidiCapture) {
      final MidiInputService service = SharedMidiInputService.instance;
      _midiInputService = service;
      unawaited(service.start());
      _midiCaptureSubscription = service.events.listen(_handleMidiCaptureEvent);
    }
  }

  @override
  void dispose() {
    _patternController.removeListener(_handlePatternControllerChanged);
    _patternFocusNode.removeListener(_handlePatternFocusChanged);
    _midiCaptureSubscription?.cancel();
    _captureController
      ..removeListener(_handleCaptureChanged)
      ..dispose();
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

        return PopScope(
          canPop: !_hasUnsavedChanges(item),
          onPopInvokedWithResult: (bool didPop, Object? result) async {
            if (didPop || !_hasUnsavedChanges(item) || !mounted) return;
            final bool shouldPop = await _handleUnsavedExit(item);
            if (shouldPop && mounted) Navigator.of(this.context).pop();
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Exercise'),
              actions: <Widget>[
                IconButton(
                  onPressed: _showInputLegend,
                  icon: const Icon(Icons.help_outline),
                  tooltip: 'Notation Grammar',
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: <Widget>[
                DrumPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const DrumSectionTitle(text: 'Exercise Notation'),
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
                        ).copyWith(fontSize: 22, height: 1.25),
                        inputFormatters: const <TextInputFormatter>[
                          _PatternTextInputFormatter(),
                        ],
                        decoration: InputDecoration(
                          hintText:
                              _patternFocusNode.hasFocus ||
                                  _patternController.text.isNotEmpty
                              ? null
                              : 'Enter Notation',
                          border: OutlineInputBorder(),
                          contentPadding: const EdgeInsets.all(16),
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
                      DrumSheetNotationDisplay(
                        document: _currentNotationDocument,
                        grouping: _groupingTextFromPattern(
                          _patternController.text,
                        ),
                        selection: DrumSheetNotationSelection.editing(
                          _selectedNoteIndexes,
                        ),
                        onSelectionChanged: _syncPatternSelectionFromNotation,
                        selectable: true,
                        compactLayout: true,
                        minNoteWidth: 34,
                        audioPreviewEnabled: true,
                        audioPreviewBpm: widget.controller.profile.defaultBpm,
                        audioPreviewAccentVoice:
                            widget.controller.profile.accentVoice,
                      ),
                      if (HardwareCapabilities.supportsPatternMidiCapture) ...[
                        const SizedBox(height: 12),
                        MidiPatternCapturePanel(
                          controller: _captureController,
                          midiStatus: _midiInputService?.status,
                          message: _captureMessage,
                          onRecord: _startMidiCapture,
                          onStop: _stopMidiCapture,
                          onClear: _clearMidiCapture,
                          onReplace: _replacePatternWithCapture,
                          onAppend: _appendCapturedPattern,
                        ),
                      ],
                      const SizedBox(height: 10),
                      _PatternContextPills(
                        selected: _editContext,
                        onSelected: (_PatternEditContext context) {
                          setState(() => _editContext = context);
                        },
                      ),
                      const SizedBox(height: 10),
                      _PatternContextControls(
                        selectedContext: _editContext,
                        hasSelection: _hasEditableSelection,
                        selectedVoices: _selectedVoiceSet,
                        onAccent: () => _transformSelectedNotes(
                          DrumSheetPatternParser.toggleAccent,
                        ),
                        onGhost: () => _transformSelectedNotes(
                          DrumSheetPatternParser.toggleGhost,
                        ),
                        onToggleVoice: _toggleVoiceForSelection,
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _undoStack.isEmpty ? null : _undo,
                        child: const Text('Undo'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _openSavePatternModal,
                  child: const Text('Save Exercise'),
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
    if (_syncingPatternSelectionFromNotation) return;
    final Set<int> selectedIndexes = _selectedIndexesForPatternSelection(
      selection,
    );
    if (!mounted) return;
    setState(() {
      _notationSelectionOwnsPatternRange = false;
      _selectedNoteIndexes = selectedIndexes;
    });
  }

  void _handleCaptureChanged() {
    if (mounted) setState(() {});
  }

  void _handleMidiCaptureEvent(RawMidiEvent raw) {
    final MidiInputService? service = _midiInputService;
    if (service == null || !_captureController.isRecording) return;
    final DrumInputEvent drum = _drumKitMapper.map(raw);
    if (drum.voice == DrumVoice.unknown) {
      if (raw.messageType == MidiMessageType.noteOn && raw.velocity > 0) {
        setState(() {
          _captureMessage = 'Unmapped MIDI note ${raw.note}; hit ignored.';
        });
      }
      return;
    }
    _captureController.captureMappedEvent(raw: raw, drum: drum);
  }

  Future<void> _startMidiCapture() async {
    final MidiInputService? service = _midiInputService;
    if (service == null) return;
    if (service.status != MidiInputStatus.connected) {
      setState(() {
        _captureMessage = 'Connect a MIDI input in Settings first.';
      });
      return;
    }
    _captureController.record();
    setState(() {
      _captureMessage = 'Recording MIDI hits...';
    });
  }

  void _stopMidiCapture() {
    final String pattern = _captureController.stop();
    setState(() {
      _captureMessage = pattern.isEmpty
          ? 'No supported MIDI hits captured.'
          : 'Capture ready. Replace or append it to the exercise.';
    });
  }

  void _clearMidiCapture() {
    _captureController.clear();
    setState(() {
      _captureMessage = null;
    });
  }

  void _replacePatternWithCapture() {
    final String captured = _captureController.generatedPattern.trim();
    if (captured.isEmpty) return;
    _recordUndo();
    _patternController.value = TextEditingValue(
      text: captured,
      selection: TextSelection.collapsed(offset: captured.length),
    );
    _validatePattern(captured, lenient: true);
    setState(() {
      _notationSelectionOwnsPatternRange = false;
      _selectedNoteIndexes = const <int>{};
      _captureMessage = 'Captured notation replaced the editor text.';
    });
  }

  void _appendCapturedPattern() {
    final String captured = _captureController.generatedPattern.trim();
    if (captured.isEmpty) return;
    final String existing = _patternController.text.trim();
    final String next = existing.isEmpty ? captured : '$existing $captured';
    _recordUndo();
    _patternController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _validatePattern(next, lenient: true);
    setState(() {
      _notationSelectionOwnsPatternRange = false;
      _selectedNoteIndexes = const <int>{};
      _captureMessage = 'Captured notation appended to the editor text.';
    });
  }

  void _handlePatternFocusChanged() {
    if (mounted) setState(() {});
  }

  void _handlePatternTextChanged(String value) {
    _validatePattern(value, lenient: true);
    setState(() {
      _notationSelectionOwnsPatternRange = false;
      _selectedNoteIndexes = _selectedIndexesForPatternSelection(
        _patternController.selection,
      );
    });
  }

  bool get _hasPatternSelection {
    final TextSelection selection = _patternController.selection;
    return selection.isValid && !selection.isCollapsed;
  }

  bool get _hasEditableSelection {
    return _hasPatternSelection || _selectedNoteIndexes.isNotEmpty;
  }

  Set<DrumSheetVoice> get _selectedVoiceSet {
    final List<DrumSheetNotationNote> notes = _notesForCurrentSelection()
        .where((DrumSheetNotationNote note) => !note.rest)
        .toList(growable: false);
    if (notes.isEmpty) return const <DrumSheetVoice>{};
    final Set<DrumSheetVoice> common = notes.first.voices.toSet();
    for (final DrumSheetNotationNote note in notes.skip(1)) {
      common.removeWhere(
        (DrumSheetVoice voice) => !note.voices.contains(voice),
      );
    }
    return common;
  }

  DrumSheetNotationDocument get _currentNotationDocument {
    try {
      return DrumSheetNotationDocument.fromPattern(
        _patternController.text.toUpperCase(),
        lenient: true,
      );
    } catch (_) {
      return const DrumSheetNotationDocument(
        measures: <DrumSheetNotationMeasure>[
          DrumSheetNotationMeasure(notes: <DrumSheetNotationNote>[]),
        ],
      );
    }
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
    if (_selectedNoteIndexes.isNotEmpty &&
        (_notationSelectionOwnsPatternRange || !_hasPatternSelection)) {
      _transformSelectedSheetNotes(transform);
      return;
    }
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

  void _transformSelectedSheetNotes(
    List<DrumSheetNotationNote> Function(List<DrumSheetNotationNote>, Set<int>)
    transform,
  ) {
    try {
      final List<DrumSheetNotationNote> notes = DrumSheetPatternParser.parse(
        _patternController.text,
      );
      if (notes.isEmpty) return;
      _recordUndo();
      final List<DrumSheetNotationNote> edited = transform(
        notes,
        _selectedNoteIndexes,
      );
      final String next = DrumSheetPatternParser.serialize(edited);
      _patternController.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
      _validatePattern(next, lenient: true);
      setState(() {
        _notationSelectionOwnsPatternRange = true;
        _selectedNoteIndexes = _selectedNoteIndexes
            .where((int index) => index >= 0 && index < edited.length)
            .toSet();
      });
    } on FormatException catch (error) {
      setState(() => _validationMessage = error.message);
    } on ArgumentError catch (error) {
      setState(() => _validationMessage = error.message ?? 'Invalid pattern.');
    }
  }

  void _toggleVoiceForSelection(DrumSheetVoice voice) {
    final _PatternSelection? selection = _selectedPatternText();
    if (_selectedNoteIndexes.isNotEmpty &&
        (_notationSelectionOwnsPatternRange || !_hasPatternSelection)) {
      _transformSelectedSheetNotes(
        (List<DrumSheetNotationNote> notes, Set<int> selectedIndexes) =>
            _toggleVoiceOnNotes(notes, selectedIndexes, voice),
      );
      return;
    }
    if (selection == null) return;
    try {
      final List<DrumSheetNotationNote> notes = DrumSheetPatternParser.parse(
        selection.text,
      );
      if (notes.isEmpty) return;
      _recordUndo();
      final List<DrumSheetNotationNote> edited = _toggleVoiceOnNotes(
        notes,
        Set<int>.from(Iterable<int>.generate(notes.length)),
        voice,
      );
      _replaceSelectedPatternText(DrumSheetPatternParser.serialize(edited));
    } on FormatException catch (error) {
      setState(() => _validationMessage = error.message);
    } on ArgumentError catch (error) {
      setState(() => _validationMessage = error.message ?? 'Invalid pattern.');
    }
  }

  List<DrumSheetNotationNote> _toggleVoiceOnNotes(
    List<DrumSheetNotationNote> notes,
    Set<int> selectedIndexes,
    DrumSheetVoice voice,
  ) {
    final List<int> playableIndexes = selectedIndexes
        .where(
          (int index) =>
              index >= 0 && index < notes.length && !notes[index].rest,
        )
        .toList(growable: false);
    if (playableIndexes.isEmpty) return notes;

    final bool shouldAdd = !playableIndexes.every(
      (int index) => notes[index].voices.contains(voice),
    );
    if (!shouldAdd &&
        playableIndexes.any((int index) => notes[index].voices.length <= 1)) {
      throw ArgumentError('A note needs at least one voice.');
    }

    return <DrumSheetNotationNote>[
      for (int index = 0; index < notes.length; index += 1)
        if (playableIndexes.contains(index))
          _noteWithVoices(
            notes[index],
            _voicesAfterToggle(notes[index].voices, voice, shouldAdd),
          )
        else
          notes[index],
    ];
  }

  DrumSheetNotationNote _noteWithVoices(
    DrumSheetNotationNote note,
    List<DrumSheetVoice> voices,
  ) {
    return note.copyWith(
      voices: voices,
      sticking: _stickingForVoices(note, voices),
    );
  }

  String _stickingForVoices(
    DrumSheetNotationNote note,
    List<DrumSheetVoice> voices,
  ) {
    final String existing = note.sticking.toUpperCase();
    if (voices.length == 1) {
      return switch (voices.first) {
        DrumSheetVoice.snare => _snareStickingFrom(existing),
        DrumSheetVoice.kick => 'K',
        DrumSheetVoice.crash => 'X',
        _ => _isPatternLimb(existing) ? existing : 'R',
      };
    }

    final List<String> representable = <String>[];
    if (voices.contains(DrumSheetVoice.snare)) {
      representable.add(_snareStickingFrom(existing));
    }
    if (voices.contains(DrumSheetVoice.crash)) representable.add('X');
    if (voices.contains(DrumSheetVoice.kick)) representable.add('K');
    if (representable.length == voices.length) return representable.join();
    return _isPatternLimb(existing) ? existing : 'R';
  }

  String _snareStickingFrom(String existing) {
    if (existing == 'L' || existing.contains('L') && !existing.contains('R')) {
      return 'L';
    }
    return 'R';
  }

  List<DrumSheetVoice> _voicesAfterToggle(
    List<DrumSheetVoice> voices,
    DrumSheetVoice voice,
    bool shouldAdd,
  ) {
    final List<DrumSheetVoice> next = <DrumSheetVoice>[...voices];
    if (shouldAdd) {
      if (!next.contains(voice)) next.add(voice);
    } else {
      next.remove(voice);
    }
    next.sort(
      (DrumSheetVoice a, DrumSheetVoice b) =>
          _voiceSortOrder(a).compareTo(_voiceSortOrder(b)),
    );
    return next;
  }

  List<DrumSheetNotationNote> _notesForCurrentSelection() {
    try {
      if (_selectedNoteIndexes.isNotEmpty &&
          (_notationSelectionOwnsPatternRange || !_hasPatternSelection)) {
        final List<DrumSheetNotationNote> notes = DrumSheetPatternParser.parse(
          _patternController.text,
        );
        return <DrumSheetNotationNote>[
          for (final int index in _selectedNoteIndexes)
            if (index >= 0 && index < notes.length) notes[index],
        ];
      }
      final _PatternSelection? selection = _selectedPatternText();
      if (selection == null) return const <DrumSheetNotationNote>[];
      return DrumSheetPatternParser.parse(selection.text);
    } catch (_) {
      return const <DrumSheetNotationNote>[];
    }
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
    setState(() => _notationSelectionOwnsPatternRange = false);
  }

  void _syncPatternSelectionFromNotation(Set<int> indexes) {
    final Set<int> selectedIndexes = Set<int>.unmodifiable(indexes);
    final int collapsedOffset = _patternController.selection.extentOffset
        .clamp(0, _patternController.text.length)
        .toInt();
    final TextSelection textSelection =
        _textSelectionForNoteIndexes(selectedIndexes) ??
        TextSelection.collapsed(offset: collapsedOffset);
    _syncingPatternSelectionFromNotation = true;
    try {
      _lastPatternSelection = textSelection;
      _patternController.value = _patternController.value.copyWith(
        selection: textSelection,
        composing: TextRange.empty,
      );
    } finally {
      _syncingPatternSelectionFromNotation = false;
    }
    if (!mounted) return;
    setState(() {
      _notationSelectionOwnsPatternRange = selectedIndexes.isNotEmpty;
      _selectedNoteIndexes = selectedIndexes;
    });
  }

  Set<int> _selectedIndexesForPatternSelection(TextSelection selection) {
    if (!selection.isValid || selection.isCollapsed) return const <int>{};
    final int start = selection.start < selection.end
        ? selection.start
        : selection.end;
    final int end = selection.start < selection.end
        ? selection.end
        : selection.start;
    final List<TextRange> ranges = _patternEventTextRanges(
      _patternController.text,
    );
    return <int>{
      for (int index = 0; index < ranges.length; index += 1)
        if (ranges[index].end > start && ranges[index].start < end) index,
    };
  }

  TextSelection? _textSelectionForNoteIndexes(Set<int> selectedIndexes) {
    if (selectedIndexes.isEmpty) return null;
    final List<TextRange> ranges = _patternEventTextRanges(
      _patternController.text,
    );
    final List<TextRange> selectedRanges = <TextRange>[
      for (final int index in selectedIndexes)
        if (index >= 0 && index < ranges.length) ranges[index],
    ];
    if (selectedRanges.isEmpty) return null;
    final int start = selectedRanges
        .map((TextRange range) => range.start)
        .reduce((int left, int right) => left < right ? left : right);
    final int end = selectedRanges
        .map((TextRange range) => range.end)
        .reduce((int left, int right) => left > right ? left : right);
    return TextSelection(baseOffset: start, extentOffset: end);
  }

  Future<void> _openSavePatternModal() async {
    final String? validationError = _strictValidationError();
    if (validationError != null) {
      setState(() => _validationMessage = validationError);
      return;
    }
    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: DrumcabularyTheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: DrumcabularyTheme.line),
          ),
          title: const Text('Save Exercise'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
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
                ),
              ],
            ),
          ),
          actions: <Widget>[
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    if (shouldSave == true) {
      _savePattern();
    } else {
      setState(() {});
    }
  }

  String? _strictValidationError() {
    try {
      final List<DrumSheetNotationNote> notes = DrumSheetPatternParser.parse(
        _patternController.text.trim().toUpperCase(),
      );
      return notes.isEmpty ? 'Enter notation before saving.' : null;
    } on FormatException catch (error) {
      return error.message;
    } on ArgumentError catch (error) {
      return error.message ?? 'Invalid pattern.';
    }
  }

  String _savePattern() {
    final String patternText = _patternController.text.trim().toUpperCase();
    final List<DrumSheetNotationNote> parsedNotes;
    try {
      parsedNotes = DrumSheetPatternParser.parse(patternText);
      if (parsedNotes.isEmpty) {
        setState(() {
          _validationMessage = 'Enter notation before saving.';
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
        .map(legacyTokenForSheetNote)
        .toList(growable: false);
    final String savedItemId = widget.controller.savePracticeItemEdits(
      itemId: widget.itemId,
      accentedNoteIndices: accentIndicesForSheetNotes(parsedNotes),
      ghostNoteIndices: ghostIndicesForSheetNotes(parsedNotes),
      voiceAssignments: parsedNotes
          .map(legacyVoiceForSheetNote)
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
          .map(
            (DrumSheetNotationNote note) =>
                storedValueForSheetNoteValue(note.value),
          )
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
    ).showSnackBar(const SnackBar(content: Text('Exercise saved.')));
    return savedItemId;
  }

  Future<bool> _handleUnsavedExit(PracticeItemV1 item) async {
    final UnsavedChangesDecision? decision = await showUnsavedChangesDialog(
      context,
      title: 'Unsaved Changes',
      message: item.saved
          ? 'Save your changes to this exercise before leaving?'
          : 'Save this exercise before leaving?',
      saveLabel: 'Save Exercise',
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
          title: const Text('Notation Grammer'),
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

class _PatternContextPills extends StatelessWidget {
  final _PatternEditContext selected;
  final ValueChanged<_PatternEditContext> onSelected;

  const _PatternContextPills({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        DrumSelectablePill(
          label: const Text('Dynamics'),
          selected: selected == _PatternEditContext.dynamics,
          onPressed: () => onSelected(_PatternEditContext.dynamics),
        ),
        DrumSelectablePill(
          label: const Text('Voices'),
          selected: selected == _PatternEditContext.voices,
          onPressed: () => onSelected(_PatternEditContext.voices),
        ),
      ],
    );
  }
}

class _PatternContextControls extends StatelessWidget {
  final _PatternEditContext selectedContext;
  final bool hasSelection;
  final Set<DrumSheetVoice> selectedVoices;
  final VoidCallback onAccent;
  final VoidCallback onGhost;
  final ValueChanged<DrumSheetVoice> onToggleVoice;

  const _PatternContextControls({
    required this.selectedContext,
    required this.hasSelection,
    required this.selectedVoices,
    required this.onAccent,
    required this.onGhost,
    required this.onToggleVoice,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (selectedContext == _PatternEditContext.dynamics)
          Wrap(
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
            ],
          )
        else
          _VoiceButtonGrid(
            enabled: hasSelection,
            selectedVoices: selectedVoices,
            onToggleVoice: onToggleVoice,
          ),
      ],
    );
  }
}

class _VoiceButtonGrid extends StatelessWidget {
  final bool enabled;
  final Set<DrumSheetVoice> selectedVoices;
  final ValueChanged<DrumSheetVoice> onToggleVoice;

  const _VoiceButtonGrid({
    required this.enabled,
    required this.selectedVoices,
    required this.onToggleVoice,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final _VoiceOption option in _voiceOptions)
          DrumSelectablePill(
            label: Text(option.label),
            selected: enabled && selectedVoices.contains(option.voice),
            onPressed: enabled ? () => onToggleVoice(option.voice) : null,
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
    final TextStyle? titleStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);
    final TextStyle? bodyStyle = Theme.of(context).textTheme.bodyMedium;
    return SizedBox(
      width: 360,
      child: DefaultTextStyle.merge(
        style: bodyStyle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Tokens', style: titleStyle),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 14,
              runSpacing: 10,
              children: <Widget>[
                _LegendEntry(token: 'R', text: 'right hand'),
                _LegendEntry(token: 'L', text: 'left hand'),
                _LegendEntry(token: 'K', text: 'kick'),
                _LegendEntry(token: 'F', text: 'flam'),
                _LegendEntry(token: 'X', text: 'crash / accent / big hit'),
                _LegendEntry(token: '_', text: 'rest'),
              ],
            ),
            const SizedBox(height: 16),
            Text('Dynamics', style: titleStyle),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 14,
              runSpacing: 10,
              children: <Widget>[
                _LegendEntry(token: '[S:^R]', text: 'accented snare'),
                _LegendEntry(token: '[S:(L)]', text: 'ghosted snare'),
                _LegendEntry(token: '[S:^(L)]', text: 'invalid'),
              ],
            ),
            const SizedBox(height: 16),
            Text('Multiple Voices', style: titleStyle),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 14,
              runSpacing: 10,
              children: <Widget>[
                _LegendEntry(token: '[CR K]', text: 'crash + kick'),
                _LegendEntry(token: '[HH K]', text: 'hi-hat + kick'),
                _LegendEntry(token: '[OHH S]', text: 'open hi-hat + snare'),
                _LegendEntry(token: '[HH:R S:L]', text: 'authored hands'),
                _LegendEntry(token: '[HH:RRRR K]', text: 'invalid'),
              ],
            ),
            const SizedBox(height: 16),
            Text('Voices', style: titleStyle),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 14,
              runSpacing: 10,
              children: <Widget>[
                _LegendEntry(token: '[HH]', text: 'closed hi-hat'),
                _LegendEntry(token: '[OHH]', text: 'open hi-hat'),
                _LegendEntry(token: '[T1:R]', text: 'tom 1, right hand'),
                _LegendEntry(token: '[FT:L]', text: 'floor tom, left hand'),
              ],
            ),
            const SizedBox(height: 16),
            Text('Phrasing', style: titleStyle),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 14,
              runSpacing: 10,
              children: <Widget>[
                _LegendEntry(token: '[S:LRLR]', text: 'four snare strokes'),
                _LegendEntry(token: '[S:(L)(L)^R]', text: 'ghosts + accent'),
              ],
            ),
          ],
        ),
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
            style: baseStyle.copyWith(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: text),
        ],
      ),
    );
  }
}

List<TextRange> patternEventTextRangesForTesting(String pattern) {
  return _patternEventTextRanges(pattern);
}

List<TextRange> _patternEventTextRanges(String pattern) {
  final List<TextRange> ranges = <TextRange>[];
  for (int index = 0; index < pattern.length; index += 1) {
    final String char = pattern[index];
    if (char.trim().isEmpty) continue;
    final int start = index;
    int tokenIndex = index;
    while (tokenIndex < pattern.length && pattern[tokenIndex] == '^') {
      tokenIndex += 1;
      while (tokenIndex < pattern.length &&
          pattern[tokenIndex].trim().isEmpty) {
        tokenIndex += 1;
      }
    }
    if (tokenIndex >= pattern.length) {
      ranges.add(TextRange(start: start, end: pattern.length));
      break;
    }
    final String token = pattern[tokenIndex];
    if (token == '[') {
      final int close = _matchingTopLevelClose(pattern, tokenIndex, ']');
      final int end = close < 0 ? pattern.length : close + 1;
      ranges.add(TextRange(start: start, end: end));
      index = end - 1;
      continue;
    }
    if (token == '(') {
      final int close = _matchingGhostClose(pattern, tokenIndex);
      final int end = close < 0 ? pattern.length : close + 1;
      ranges.add(TextRange(start: start, end: end));
      index = end - 1;
      continue;
    }
    if (_isSinglePatternEventToken(token)) {
      ranges.add(TextRange(start: start, end: tokenIndex + 1));
      index = tokenIndex;
    }
  }
  return ranges;
}

int _matchingTopLevelClose(String pattern, int openIndex, String closeToken) {
  for (int index = openIndex + 1; index < pattern.length; index += 1) {
    if (pattern[index] == closeToken) return index;
  }
  return -1;
}

int _matchingGhostClose(String pattern, int openIndex) {
  int bracketDepth = 0;
  for (int index = openIndex + 1; index < pattern.length; index += 1) {
    final String char = pattern[index];
    if (char == '[') bracketDepth += 1;
    if (char == ']' && bracketDepth > 0) bracketDepth -= 1;
    if (char == ')' && bracketDepth == 0) return index;
  }
  return -1;
}

bool _isSinglePatternEventToken(String token) {
  return switch (token.toUpperCase()) {
    'R' || 'L' || 'K' || 'F' || 'X' || '_' => true,
    _ => false,
  };
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
            ? sheetValueForStoredNoteValue(item.noteValueOverrides[index])
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
    DrumVoiceV1.openHiHat => DrumSheetVoice.openHiHat,
    DrumVoiceV1.crash => DrumSheetVoice.crash,
    DrumVoiceV1.ride => DrumSheetVoice.ride,
    DrumVoiceV1.kick => DrumSheetVoice.kick,
  };
}
