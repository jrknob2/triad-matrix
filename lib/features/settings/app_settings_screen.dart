import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../features/app/app_runtime_flags.dart';
import '../../features/app/drumcabulary_theme.dart';
import '../../features/app/unsaved_changes_dialog.dart';
import '../../features/hardware/hardware_capabilities.dart';
import '../../features/midi/drum_kit_mapper.dart';
import '../../features/midi/midi_input_models.dart';
import '../../features/midi/midi_input_service.dart';
import '../../features/midi/midi_pattern_capture.dart';
import '../../features/midi/midi_pattern_capture_card.dart';
import '../../features/midi/shared_midi_input_service.dart';
import '../../features/midi/shared_serial_led_controller.dart';
import '../../state/app_controller.dart';
import 'hardware_midi_settings_screen.dart';

class AppSettingsScreen extends StatefulWidget {
  final AppController controller;

  const AppSettingsScreen({super.key, required this.controller});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  late UserProfileV1 _draft;
  MidiPatternCaptureController? _captureController;
  StreamSubscription<RawMidiEvent>? _midiCaptureSubscription;
  final StreamController<DrumInputEvent> _mappedMidiEvents =
      StreamController<DrumInputEvent>.broadcast(sync: true);
  final DrumKitMapper _drumKitMapper = const DrumKitMapper();

  @override
  void initState() {
    super.initState();
    _draft = widget.controller.profile;
    if (HardwareCapabilities.supportsPatternMidiCapture) {
      _captureController = MidiPatternCaptureController()
        ..addListener(_handleCaptureChanged);
      final MidiInputService service = SharedMidiInputService.instance;
      unawaited(service.start());
      _midiCaptureSubscription = service.events.listen(_handleMidiCaptureEvent);
    }
  }

  @override
  void dispose() {
    _midiCaptureSubscription?.cancel();
    _mappedMidiEvents.close();
    _captureController
      ?..removeListener(_handleCaptureChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasUnsavedChanges = _hasUnsavedChanges;

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
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            if (HardwareCapabilities.supportsDesktopHardware) ...<Widget>[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.usb_rounded),
                  title: const Text('Hardware & MIDI'),
                  subtitle: const Text('Configure desktop MIDI and LEDs.'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HardwareMidiSettingsScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          'Default BPM',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Text(
                          '${_draft.defaultBpm}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: _draft.defaultBpm <= 30
                              ? null
                              : () => setState(
                                  () => _draft = _draft.copyWith(
                                    defaultBpm: _draft.defaultBpm - 1,
                                  ),
                                ),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Expanded(
                          child: Slider(
                            value: _draft.defaultBpm.toDouble(),
                            min: 30,
                            max: 260,
                            divisions: 230,
                            label: '${_draft.defaultBpm} BPM',
                            onChanged: (double value) {
                              setState(
                                () => _draft = _draft.copyWith(
                                  defaultBpm: value.round(),
                                ),
                              );
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: _draft.defaultBpm >= 260
                              ? null
                              : () => setState(
                                  () => _draft = _draft.copyWith(
                                    defaultBpm: _draft.defaultBpm + 1,
                                  ),
                                ),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TimerPresetV1>(
              initialValue: _draft.defaultTimerPreset,
              decoration: const InputDecoration(
                labelText: 'Default Timer',
                border: OutlineInputBorder(),
              ),
              items: TimerPresetV1.values
                  .map(
                    (preset) => DropdownMenuItem<TimerPresetV1>(
                      value: preset,
                      child: Text(preset.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (TimerPresetV1? value) {
                if (value == null) return;
                setState(
                  () => _draft = _draft.copyWith(defaultTimerPreset: value),
                );
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Click Enabled by Default'),
              value: _draft.clickEnabledByDefault,
              onChanged: (bool value) {
                setState(() {
                  _draft = _draft.copyWith(clickEnabledByDefault: value);
                });
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dark Sheet Music in Player'),
              subtitle: const Text(
                'Use white engraving on the dark practice player background.',
              ),
              value: _draft.darkPracticeSheetNotation,
              onChanged: (bool value) {
                setState(() {
                  _draft = _draft.copyWith(darkPracticeSheetNotation: value);
                });
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                _saveDraft();
                Navigator.of(context).pop();
              },
              child: const Text('Save Settings'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _confirmClearAppData(context),
              child: const Text('Clear App Data'),
            ),
            if (mockScenariosEnabled) ...<Widget>[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Mock Scenarios',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'These are runtime-only screen states for design and QA. Leaving mock mode restores the real app state.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<AppMockScenarioV1?>(
                        initialValue: widget.controller.activeMockScenario,
                        decoration: const InputDecoration(
                          labelText: 'Scenario',
                          border: OutlineInputBorder(),
                        ),
                        items: <DropdownMenuItem<AppMockScenarioV1?>>[
                          const DropdownMenuItem<AppMockScenarioV1?>(
                            value: null,
                            child: Text('Live App State'),
                          ),
                          ...AppMockScenarioV1.values.map(
                            (AppMockScenarioV1 scenario) =>
                                DropdownMenuItem<AppMockScenarioV1?>(
                                  value: scenario,
                                  child: Text(scenario.label),
                                ),
                          ),
                        ],
                        onChanged: (AppMockScenarioV1? value) {
                          widget.controller.setMockScenario(value);
                          setState(() => _draft = widget.controller.profile);
                        },
                      ),
                      if (widget.controller.isMockScenarioActive) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          'Active: ${widget.controller.activeMockScenario!.label}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            if (HardwareCapabilities.supportsPatternMidiCapture &&
                _captureController != null) ...<Widget>[
              const SizedBox(height: 24),
              MidiPatternCaptureCard(
                controller: _captureController!,
                drumEvents: _mappedMidiEvents.stream,
                ledController: SharedSerialLedController.instance,
                playbackBpm: _draft.defaultBpm,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleCaptureChanged() {
    if (mounted) setState(() {});
  }

  void _handleMidiCaptureEvent(RawMidiEvent raw) {
    final MidiPatternCaptureController? captureController = _captureController;
    if (raw.messageType != MidiMessageType.noteOn || raw.velocity <= 0) {
      return;
    }
    final DrumInputEvent drum = _drumKitMapper.map(raw);
    if (drum.voice == DrumVoice.unknown) {
      return;
    }
    if (!_mappedMidiEvents.isClosed) {
      _mappedMidiEvents.add(drum);
    }
    if (captureController == null || !captureController.isRecording) return;
    captureController.captureMappedEvent(raw: raw, drum: drum);
  }

  Future<void> _confirmClearAppData(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: DrumcabularyTheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: DrumcabularyTheme.line),
          ),
          title: const Text('Clear App Data'),
          content: const Text(
            'This resets the app to a fresh start. Practice history, working-on items, competency, saved phrases, your patterns, and settings will be cleared. Built-in material stays available.',
          ),
          actions: <Widget>[
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;
    widget.controller.clearAppData();
    setState(() => _draft = widget.controller.profile);
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  }

  bool get _hasUnsavedChanges {
    final UserProfileV1 current = widget.controller.profile;
    return _draft.defaultBpm != current.defaultBpm ||
        _draft.defaultTimerPreset != current.defaultTimerPreset ||
        _draft.clickEnabledByDefault != current.clickEnabledByDefault ||
        _draft.darkPracticeSheetNotation != current.darkPracticeSheetNotation;
  }

  void _saveDraft() {
    widget.controller.updateProfile(_draft);
  }

  Future<bool> _handleUnsavedExit() async {
    final UnsavedChangesDecision? decision = await showUnsavedChangesDialog(
      context,
      title: 'Unsaved Changes',
      message: 'Save your settings before leaving?',
      saveLabel: 'Save Settings',
    );
    if (!mounted) return false;
    return switch (decision) {
      UnsavedChangesDecision.save => () {
        _saveDraft();
        return true;
      }(),
      UnsavedChangesDecision.discard => true,
      _ => false,
    };
  }
}
