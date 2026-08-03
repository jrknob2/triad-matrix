import 'package:flutter/material.dart';

import '../app/drumcabulary_theme.dart';
import '../app/drumcabulary_ui.dart';
import '../practice/widgets/pattern_text_styles.dart';
import 'midi_input_models.dart';
import 'midi_pattern_capture.dart';
import 'midi_pattern_capture_controls.dart';

class MidiPatternCapturePanel extends StatelessWidget {
  final MidiPatternCaptureController controller;
  final MidiInputStatus? midiStatus;
  final String? message;
  final VoidCallback onRecord;
  final VoidCallback onStop;
  final VoidCallback onClear;
  final VoidCallback? onReplace;
  final VoidCallback? onAppend;

  const MidiPatternCapturePanel({
    super.key,
    required this.controller,
    required this.midiStatus,
    required this.message,
    required this.onRecord,
    required this.onStop,
    required this.onClear,
    this.onReplace,
    this.onAppend,
  });

  @override
  Widget build(BuildContext context) {
    final bool connected = midiStatus == MidiInputStatus.connected;
    final bool hasCapture = controller.generatedPattern.trim().isNotEmpty;
    return DrumPanel(
      tone: DrumPanelTone.warm,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: DrumSectionTitle(text: 'MIDI Capture')),
              Text(
                _midiCaptureStatusLabel(midiStatus),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: connected
                      ? DrumcabularyTheme.edgeOrange
                      : DrumcabularyTheme.edgeTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          MidiPatternCaptureFramingControls(
            config: controller.config,
            enabled: !controller.isRecording,
            onChanged: controller.updateConfig,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Chip(label: Text(_captureStatusLabel(controller))),
              if (controller.tempoEstimate != null)
                Chip(
                  label: Text(
                    'Estimated ${controller.tempoEstimate!.roundedBpm} BPM',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (controller.generatedPattern.isNotEmpty)
            SelectableText(
              controller.generatedPattern,
              style: PatternTextStyles.editableInput(
                context,
              ).copyWith(fontSize: 18, height: 1.25),
            )
          else
            Text(
              'Capture from the configured MIDI input.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DrumcabularyTheme.edgeTextSecondary,
              ),
            ),
          if (message != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DrumcabularyTheme.edgeTextSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: connected && !controller.isRecording
                    ? onRecord
                    : null,
                icon: const Icon(Icons.fiber_manual_record_rounded),
                label: const Text('Record'),
              ),
              OutlinedButton(
                onPressed: controller.isRecording ? onStop : null,
                child: const Text('Stop'),
              ),
              OutlinedButton(
                onPressed: controller.isRecording || hasCapture
                    ? onClear
                    : null,
                child: const Text('Clear Capture'),
              ),
              if (onReplace != null)
                OutlinedButton(
                  onPressed: hasCapture && !controller.isRecording
                      ? onReplace
                      : null,
                  child: const Text('Replace Pattern'),
                ),
              if (onAppend != null)
                OutlinedButton(
                  onPressed: hasCapture && !controller.isRecording
                      ? onAppend
                      : null,
                  child: const Text('Append'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _midiCaptureStatusLabel(MidiInputStatus? status) {
  return switch (status) {
    MidiInputStatus.connected => 'Connected',
    MidiInputStatus.connecting => 'Connecting',
    MidiInputStatus.scanning => 'Scanning',
    MidiInputStatus.connectionError => 'Connection Error',
    MidiInputStatus.noDevicesFound => 'No Device',
    MidiInputStatus.disconnected || null => 'Disconnected',
  };
}

String _captureStatusLabel(MidiPatternCaptureController controller) {
  final String? message = controller.statusMessage;
  if (message != null && message.trim().isNotEmpty) return message;
  return switch (controller.status) {
    MidiPatternCaptureStatus.countingIn => 'Count-in',
    MidiPatternCaptureStatus.recording => 'Listening',
    MidiPatternCaptureStatus.analyzing => 'Confirming pattern',
    MidiPatternCaptureStatus.finishingCycle => 'Finish this repetition',
    MidiPatternCaptureStatus.captured => 'Captured',
    MidiPatternCaptureStatus.review => 'Review',
    MidiPatternCaptureStatus.error => 'Capture error',
    MidiPatternCaptureStatus.idle => 'Ready',
  };
}
