import 'package:flutter/material.dart';

import '../../../core/practice/practice_domain_v1.dart';
import '../../app/app_formatters.dart';
import '../../app/drumcabulary_ui.dart';

class SessionSetupControls extends StatelessWidget {
  final int bpm;
  final TimerPresetV1 timerPreset;
  final ValueChanged<int> onBpmChanged;
  final ValueChanged<TimerPresetV1> onTimerPresetChanged;
  final String eyebrow;

  const SessionSetupControls({
    super.key,
    required this.bpm,
    required this.timerPreset,
    required this.onBpmChanged,
    required this.onTimerPresetChanged,
    this.eyebrow = 'Session Setup',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DrumEyebrow(text: eyebrow),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFCF7),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2D8C6)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: <Widget>[
                      Text(
                        'BPM',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: bpm <= 30
                            ? null
                            : () => onBpmChanged(bpm - 1),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$bpm',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: bpm >= 260
                            ? null
                            : () => onBpmChanged(bpm + 1),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<TimerPresetV1>(
                initialValue: timerPreset,
                decoration: const InputDecoration(
                  labelText: 'Length',
                  isDense: true,
                ),
                items: TimerPresetV1.values
                    .map(
                      (TimerPresetV1 preset) => DropdownMenuItem<TimerPresetV1>(
                        value: preset,
                        child: Text(preset.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (TimerPresetV1? value) {
                  if (value == null) return;
                  onTimerPresetChanged(value);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
