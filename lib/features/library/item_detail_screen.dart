import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../features/app/drumcabulary_ui.dart';
import '../../features/app/unsaved_changes_dialog.dart';
import '../../state/app_controller.dart';
import '../practice/widgets/pattern_display_text.dart';
import '../practice/widgets/pattern_marking_editor.dart';
import '../practice/widgets/pattern_voice_display.dart';
import '../practice/widgets/session_setup_controls.dart';
import '../practice/widgets/voice_assignment_editor.dart';

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
                        PatternDisplayText(
                          tokens: tokens,
                          markings: draftMarkings,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Accents & Ghosts',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        PatternMarkingEditor(
                          tokens: tokens,
                          markings: draftMarkings,
                          onTapNote: _cycleMarking,
                          showHelpText: false,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Flow Voices',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (flowCapable) ...<Widget>[
                          PatternVoiceDisplay(
                            tokens: tokens,
                            markings: draftMarkings,
                            voices: _voiceAssignments,
                            showPatternRow: false,
                            patternStyle: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                            voiceStyle: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                        ],
                        VoiceAssignmentEditor(
                          tokens: tokens,
                          voices: _voiceAssignments,
                          onTapNote: _cycleVoice,
                          showHelpText: false,
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

  void _cycleMarking(int noteIndex) {
    final PracticeItemV1 item = widget.controller.itemById(widget.itemId);
    final String token = widget.controller.noteTokensFor(item.id)[noteIndex];
    final PatternNoteMarkingV1 current = _draftMarkingsFor(
      item.noteCount,
    )[noteIndex];
    final PatternNoteMarkingV1 next = _nextMarking(token, current);

    setState(() {
      final Set<int> accents = _accentedNoteIndices.toSet();
      final Set<int> ghosts = _ghostNoteIndices.toSet();
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
      _accentedNoteIndices = accents.toList()..sort();
      _ghostNoteIndices = ghosts.toList()..sort();
    });
  }

  void _cycleVoice(int noteIndex) {
    final PracticeItemV1 item = widget.controller.itemById(widget.itemId);
    final String token = widget.controller.noteTokensFor(item.id)[noteIndex];
    final DrumVoiceV1 current = _voiceAssignments[noteIndex];
    final DrumVoiceV1 next = _nextVoice(token, current);
    setState(() {
      _voiceAssignments = List<DrumVoiceV1>.from(_voiceAssignments)
        ..[noteIndex] = next;
    });
  }

  PatternNoteMarkingV1 _nextMarking(
    String token,
    PatternNoteMarkingV1 current,
  ) {
    if (token == 'K') {
      return switch (current) {
        PatternNoteMarkingV1.normal => PatternNoteMarkingV1.ghost,
        PatternNoteMarkingV1.accent => PatternNoteMarkingV1.ghost,
        PatternNoteMarkingV1.ghost => PatternNoteMarkingV1.normal,
      };
    }

    return switch (current) {
      PatternNoteMarkingV1.normal => PatternNoteMarkingV1.accent,
      PatternNoteMarkingV1.accent => PatternNoteMarkingV1.ghost,
      PatternNoteMarkingV1.ghost => PatternNoteMarkingV1.normal,
    };
  }

  DrumVoiceV1 _nextVoice(String token, DrumVoiceV1 current) {
    if (token == 'K') return DrumVoiceV1.kick;

    const List<DrumVoiceV1> cycle = <DrumVoiceV1>[
      DrumVoiceV1.snare,
      DrumVoiceV1.rackTom,
      DrumVoiceV1.tom2,
      DrumVoiceV1.floorTom,
      DrumVoiceV1.hihat,
    ];

    final int index = cycle.indexOf(current);
    if (index < 0) return cycle.first;
    return cycle[(index + 1) % cycle.length];
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
