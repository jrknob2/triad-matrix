import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../state/app_controller.dart';

class AppSettingsScreen extends StatefulWidget {
  final AppController controller;

  const AppSettingsScreen({
    super.key,
    required this.controller,
  });

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
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          DropdownButtonFormField<HandednessV1>(
            initialValue: _draft.handedness,
            decoration: const InputDecoration(
              labelText: 'Handedness',
              border: OutlineInputBorder(),
            ),
            items: HandednessV1.values
                .map(
                  (handedness) => DropdownMenuItem<HandednessV1>(
                    value: handedness,
                    child: Text(handedness.name),
                  ),
                )
                .toList(growable: false),
            onChanged: (HandednessV1? value) {
              if (value == null) return;
              setState(() => _draft = _draft.copyWith(handedness: value));
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PlayerSelfRankV1>(
            initialValue: _draft.selfRank,
            decoration: const InputDecoration(
              labelText: 'Overall Level',
              border: OutlineInputBorder(),
            ),
            items: PlayerSelfRankV1.values
                .map(
                  (rank) => DropdownMenuItem<PlayerSelfRankV1>(
                    value: rank,
                    child: Text(rank.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (PlayerSelfRankV1? value) {
              if (value == null) return;
              setState(() => _draft = _draft.copyWith(selfRank: value));
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Default BPM',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: _draft.defaultBpm <= 30
                    ? null
                    : () => setState(
                          () => _draft = _draft.copyWith(
                            defaultBpm: _draft.defaultBpm - 1,
                          ),
                        ),
                icon: const Icon(Icons.remove),
              ),
              Text('${_draft.defaultBpm}'),
              IconButton(
                onPressed: _draft.defaultBpm >= 260
                    ? null
                    : () => setState(
                          () => _draft = _draft.copyWith(
                            defaultBpm: _draft.defaultBpm + 1,
                          ),
                        ),
                icon: const Icon(Icons.add),
              ),
            ],
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
              setState(() => _draft = _draft.copyWith(defaultTimerPreset: value));
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<FlowFillLengthV1>(
            initialValue: _draft.defaultFlowFillLength,
            decoration: const InputDecoration(
              labelText: 'Default Flow Fill Length',
              border: OutlineInputBorder(),
            ),
            items: FlowFillLengthV1.values
                .map(
                  (length) => DropdownMenuItem<FlowFillLengthV1>(
                    value: length,
                    child: Text(length.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (FlowFillLengthV1? value) {
              if (value == null) return;
              setState(
                () => _draft = _draft.copyWith(defaultFlowFillLength: value),
              );
            },
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              widget.controller.updateProfile(_draft);
              Navigator.of(context).pop();
            },
            child: const Text('Save Settings'),
          ),
        ],
      ),
    );
  }
}
