import 'package:flutter/material.dart';

import '../app/drumcabulary_theme.dart';
import 'midi_pattern_capture.dart';

class MidiPatternCaptureFramingControls extends StatelessWidget {
  final MidiPatternCaptureConfig config;
  final bool enabled;
  final ValueChanged<MidiPatternCaptureConfig> onChanged;

  const MidiPatternCaptureFramingControls({
    super.key,
    required this.config,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _CaptureDropdown<String>(
          label: 'Time Signature',
          value: config.timeSignature,
          values: const <String>['4/4', '3/4', '6/8'],
          enabled: enabled,
          labelFor: (String value) => value,
          onChanged: (String value) =>
              onChanged(config.copyWith(timeSignature: value)),
        ),
        _CaptureDropdown<int>(
          label: 'Pattern Length',
          value: config.measureCount,
          values: const <int>[1, 2, 4, 8],
          enabled: enabled,
          labelFor: (int value) => '$value measure${value == 1 ? '' : 's'}',
          onChanged: (int value) =>
              onChanged(config.copyWith(measureCount: value)),
        ),
        _CaptureDropdown<MidiPatternCaptureTempoMode>(
          label: 'Tempo',
          value: config.tempoMode,
          values: MidiPatternCaptureTempoMode.values,
          enabled: enabled,
          labelFor: (MidiPatternCaptureTempoMode value) {
            return switch (value) {
              MidiPatternCaptureTempoMode.auto => 'Auto',
              MidiPatternCaptureTempoMode.fixed => 'Fixed',
            };
          },
          onChanged: (MidiPatternCaptureTempoMode value) =>
              onChanged(config.copyWith(tempoMode: value)),
        ),
        if (config.isFixedTempo)
          _CaptureBpmStepper(
            bpm: config.fixedBpm,
            enabled: enabled,
            onChanged: (int value) =>
                onChanged(config.copyWith(fixedBpm: value)),
          ),
        _CaptureDropdown<int>(
          label: 'Count-In',
          value: config.countInMeasures,
          values: const <int>[0, 1, 2],
          enabled: enabled && config.isFixedTempo,
          labelFor: (int value) =>
              value == 0 ? 'Off' : '$value measure${value == 1 ? '' : 's'}',
          onChanged: (int value) =>
              onChanged(config.copyWith(countInMeasures: value)),
        ),
        FilterChip(
          label: const Text('Capture Until Recognized'),
          selected: config.autoStopWhenRecognized,
          onSelected: enabled
              ? (bool selected) =>
                    onChanged(config.copyWith(autoStopWhenRecognized: selected))
              : null,
          showCheckmark: true,
        ),
      ],
    );
  }
}

class _CaptureDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> values;
  final bool enabled;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;

  const _CaptureDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.enabled,
    required this.labelFor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 172,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        items: <DropdownMenuItem<T>>[
          for (final T entry in values)
            DropdownMenuItem<T>(value: entry, child: Text(labelFor(entry))),
        ],
        onChanged: enabled
            ? (T? next) {
                if (next != null) onChanged(next);
              }
            : null,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _CaptureBpmStepper extends StatelessWidget {
  final int bpm;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _CaptureBpmStepper({
    required this.bpm,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DrumcabularyTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            onPressed: enabled && bpm > 30 ? () => onChanged(bpm - 1) : null,
            icon: const Icon(Icons.remove_rounded),
            tooltip: 'Decrease BPM',
          ),
          SizedBox(
            width: 64,
            child: Text(
              '$bpm BPM',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          IconButton(
            onPressed: enabled && bpm < 300 ? () => onChanged(bpm + 1) : null,
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Increase BPM',
          ),
        ],
      ),
    );
  }
}
