import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../features/app/app_runtime_flags.dart';
import '../../features/app/drumcabulary_theme.dart';
import '../../features/app/unsaved_changes_dialog.dart';
import '../../features/hardware/hardware_capabilities.dart';
import '../../features/hardware/hardware_status_header.dart';
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

  @override
  void initState() {
    super.initState();
    _draft = widget.controller.profile;
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
          padding: const EdgeInsets.fromLTRB(
            16,
            HardwareStatusHeaderOverlay.appBarBodyTopInset,
            16,
            16,
          ),
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
            _AppearanceSettingsCard(
              draft: _draft,
              onChanged: _applyAppearanceChange,
            ),
            const SizedBox(height: 12),
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
                              ?.copyWith(fontWeight: FontWeight.w600),
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
          ],
        ),
      ),
    );
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
    return _draft.studentName != current.studentName ||
        _draft.defaultBpm != current.defaultBpm ||
        _draft.defaultTimerPreset != current.defaultTimerPreset ||
        _draft.clickEnabledByDefault != current.clickEnabledByDefault ||
        _draft.darkPracticeSheetNotation != current.darkPracticeSheetNotation ||
        _draft.themeMode != current.themeMode ||
        _draft.accentColorValue != current.accentColorValue;
  }

  void _saveDraft() {
    widget.controller.updateProfile(_draft);
  }

  void _applyAppearanceChange(UserProfileV1 nextDraft) {
    final UserProfileV1 current = widget.controller.profile;
    widget.controller.updateProfile(
      current.copyWith(
        themeMode: nextDraft.themeMode,
        accentColorValue: nextDraft.accentColorValue,
      ),
    );
    setState(() => _draft = nextDraft);
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

class _AppearanceSettingsCard extends StatelessWidget {
  final UserProfileV1 draft;
  final ValueChanged<UserProfileV1> onChanged;

  const _AppearanceSettingsCard({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<AppThemeModeV1>(
              segments: const <ButtonSegment<AppThemeModeV1>>[
                ButtonSegment<AppThemeModeV1>(
                  value: AppThemeModeV1.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Light'),
                ),
                ButtonSegment<AppThemeModeV1>(
                  value: AppThemeModeV1.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Dark'),
                ),
              ],
              selected: <AppThemeModeV1>{draft.themeMode},
              onSelectionChanged: (Set<AppThemeModeV1> selection) {
                onChanged(draft.copyWith(themeMode: selection.single));
              },
            ),
            const SizedBox(height: 16),
            Text('Accent Color', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                for (final _AccentColorOption option in _accentColorOptions)
                  _AccentColorSwatch(
                    option: option,
                    selected: draft.accentColorValue == option.color.toARGB32(),
                    onSelected: () {
                      onChanged(
                        draft.copyWith(
                          accentColorValue: option.color.toARGB32(),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentColorSwatch extends StatelessWidget {
  final _AccentColorOption option;
  final bool selected;
  final VoidCallback onSelected;

  const _AccentColorSwatch({
    required this.option,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: option.label,
      child: InkResponse(
        onTap: onSelected,
        radius: 24,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: option.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? DrumcabularyTheme.edgeTextPrimary
                  : DrumcabularyTheme.edgeBorder,
              width: selected ? 3 : 1.2,
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: option.color.withValues(alpha: 0.34),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: selected
              ? const Icon(Icons.check_rounded, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

class _AccentColorOption {
  final String label;
  final Color color;

  const _AccentColorOption(this.label, this.color);
}

const List<_AccentColorOption> _accentColorOptions = <_AccentColorOption>[
  _AccentColorOption('Burnt Orange', DrumcabularyTheme.defaultAccent),
  _AccentColorOption('Electric Blue', Color(0xFF2F80ED)),
  _AccentColorOption('Stage Purple', Color(0xFF9B5CFF)),
  _AccentColorOption('Signal Green', Color(0xFF2EB67D)),
  _AccentColorOption('Hot Pink', Color(0xFFFF4F87)),
  _AccentColorOption('Gold', Color(0xFFE0A800)),
];
