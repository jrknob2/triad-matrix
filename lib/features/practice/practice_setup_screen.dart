import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../state/app_controller.dart';
import 'practice_session_screen.dart';

class PracticeSetupScreen extends StatefulWidget {
  final AppController controller;
  final String? initialItemId;
  final bool generated;

  const PracticeSetupScreen({
    super.key,
    required this.controller,
    this.initialItemId,
    this.generated = false,
  });

  @override
  State<PracticeSetupScreen> createState() => _PracticeSetupScreenState();
}

class _PracticeSetupScreenState extends State<PracticeSetupScreen> {
  late MaterialFamilyV1 _family;
  late PracticeIntentV1 _intent;
  late PracticeContextV1 _context;
  late int _bpm;
  late TimerPresetV1 _timerPreset;
  late bool _clickEnabled;
  late bool _generated;
  late FlowFillLengthV1 _flowFillLength;
  late String _selectedItemId;

  @override
  void initState() {
    super.initState();
    final profile = widget.controller.profile;
    final initialItem = widget.initialItemId != null
        ? widget.controller.itemById(widget.initialItemId!)
        : null;

    _family = initialItem?.family ?? MaterialFamilyV1.triad;
    _intent = initialItem?.family == MaterialFamilyV1.fiveNote
        ? PracticeIntentV1.flow
        : PracticeIntentV1.coreSkills;
    _context = _intent == PracticeIntentV1.flow
        ? PracticeContextV1.kit
        : PracticeContextV1.singleSurface;
    _bpm = profile.defaultBpm;
    _timerPreset = profile.defaultTimerPreset;
    _clickEnabled = profile.clickEnabledByDefault;
    _generated = widget.generated;
    _flowFillLength = profile.defaultFlowFillLength;

    final items = widget.controller.itemsByFamily(_family);
    _selectedItemId = initialItem?.id ?? items.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final familyItems = widget.controller.itemsByFamily(_family);
    if (!familyItems.any((item) => item.id == _selectedItemId)) {
      _selectedItemId = familyItems.first.id;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Practice Setup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Generated Session'),
            subtitle: const Text('Let the app choose what to practice.'),
            value: _generated,
            onChanged: (bool value) {
              setState(() => _generated = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MaterialFamilyV1>(
            initialValue: _family,
            decoration: const InputDecoration(
              labelText: 'Material Family',
              border: OutlineInputBorder(),
            ),
            items: MaterialFamilyV1.values
                .map(
                  (family) => DropdownMenuItem<MaterialFamilyV1>(
                    value: family,
                    child: Text(family.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (MaterialFamilyV1? value) {
              if (value == null) return;
              setState(() {
                _family = value;
                _selectedItemId = widget.controller.itemsByFamily(value).first.id;
              });
            },
          ),
          if (!_generated) ...<Widget>[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedItemId,
              decoration: const InputDecoration(
                labelText: 'Practice Item',
                border: OutlineInputBorder(),
              ),
              items: familyItems
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.id,
                      child: Text('${item.name} · ${item.sticking}'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (String? value) {
                if (value == null) return;
                setState(() => _selectedItemId = value);
              },
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<PracticeIntentV1>(
            initialValue: _intent,
            decoration: const InputDecoration(
              labelText: 'Intent',
              border: OutlineInputBorder(),
            ),
            items: PracticeIntentV1.values
                .map(
                  (intent) => DropdownMenuItem<PracticeIntentV1>(
                    value: intent,
                    child: Text(intent.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (PracticeIntentV1? value) {
              if (value == null) return;
              setState(() {
                _intent = value;
                if (_intent == PracticeIntentV1.flow) {
                  _context = PracticeContextV1.kit;
                }
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PracticeContextV1>(
            initialValue: _context,
            decoration: const InputDecoration(
              labelText: 'Context',
              border: OutlineInputBorder(),
            ),
            items: PracticeContextV1.values
                .map(
                  (context) => DropdownMenuItem<PracticeContextV1>(
                    value: context,
                    child: Text(context.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (PracticeContextV1? value) {
              if (value == null) return;
              setState(() => _context = value);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Text('BPM', style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                onPressed: _bpm <= 30 ? null : () => setState(() => _bpm -= 1),
                icon: const Icon(Icons.remove),
              ),
              Text('$_bpm'),
              IconButton(
                onPressed: _bpm >= 260 ? null : () => setState(() => _bpm += 1),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<TimerPresetV1>(
            initialValue: _timerPreset,
            decoration: const InputDecoration(
              labelText: 'Timer Target',
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
              setState(() => _timerPreset = value);
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Click'),
            subtitle: const Text('Use a metronome during the session.'),
            value: _clickEnabled,
            onChanged: (bool value) => setState(() => _clickEnabled = value),
          ),
          if (_intent == PracticeIntentV1.flow) ...<Widget>[
            const SizedBox(height: 12),
            DropdownButtonFormField<FlowFillLengthV1>(
              initialValue: _flowFillLength,
              decoration: const InputDecoration(
                labelText: 'Flow Fill Length',
                border: OutlineInputBorder(),
              ),
              items: FlowFillLengthV1.values
                  .map(
                    (fillLength) => DropdownMenuItem<FlowFillLengthV1>(
                      value: fillLength,
                      child: Text(fillLength.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (FlowFillLengthV1? value) {
                if (value == null) return;
                setState(() => _flowFillLength = value);
              },
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                title: const Text('Flow Rule'),
                subtitle: const Text(
                  'Resolve phrases to land on beat 1 in 4/4 over a 16th-note grid.',
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => _startSession(context),
            child: Text(_generated ? 'Generate and Start' : 'Start Session'),
          ),
        ],
      ),
    );
  }

  void _startSession(BuildContext context) {
    final PracticeSessionSetupV1 setup;

    if (_generated) {
      setup = widget.controller.buildGeneratedSetup(
        family: _family,
        intent: _intent,
        context: _context,
        bpm: _bpm,
        timerPreset: _timerPreset,
        clickEnabled: _clickEnabled,
        flowSpec: _intent == PracticeIntentV1.flow
            ? FlowSpecV1.v1Default.copyWith(fillLength: _flowFillLength)
            : null,
      );
    } else {
      setup = PracticeSessionSetupV1(
        practiceItemIds: <String>[_selectedItemId],
        family: _family,
        intent: _intent,
        context: _context,
        bpm: _bpm,
        timerPreset: _timerPreset,
        clickEnabled: _clickEnabled,
        generated: false,
        flowSpec: _intent == PracticeIntentV1.flow
            ? FlowSpecV1.v1Default.copyWith(fillLength: _flowFillLength)
            : null,
        generatorOptions: null,
        routineId: null,
      );
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeSessionScreen(
          controller: widget.controller,
          setup: setup,
        ),
      ),
    );
  }
}
