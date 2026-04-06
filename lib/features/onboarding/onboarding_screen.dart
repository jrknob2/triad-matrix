import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../state/app_controller.dart';

class OnboardingScreen extends StatefulWidget {
  final AppController controller;

  const OnboardingScreen({super.key, required this.controller});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  late UserProfileV1 _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.controller.profile;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFF6E9C9), Color(0xFFF8F6F1)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Triad Trainer',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'First Light',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF6B5D42),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: switch (_step) {
                      0 => _IntroStep(key: const ValueKey<int>(0)),
                      1 => _HowItWorksStep(key: const ValueKey<int>(1)),
                      _ => _SetupStep(
                        key: const ValueKey<int>(2),
                        draft: _draft,
                        onChanged: (UserProfileV1 next) {
                          setState(() => _draft = next);
                        },
                      ),
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    if (_step > 0)
                      TextButton(
                        onPressed: () => setState(() => _step -= 1),
                        child: const Text('Back'),
                      )
                    else
                      const SizedBox(width: 64),
                    const Spacer(),
                    FilledButton(
                      onPressed: _step == 2 ? _finish : _next,
                      child: Text(_step == 2 ? 'Begin First Session' : 'Next'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _next() {
    setState(() => _step += 1);
  }

  void _finish() {
    widget.controller.completeOnboarding(_draft);
  }
}

class _IntroStep extends StatelessWidget {
  const _IntroStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Short patterns become usable vocabulary when they are practiced with control, balance, touch, and repetition.',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Text(
          'This app is built to take triads and short linear phrases from recognition to dependable use. The goal is not to collect patterns. The goal is to make them available when you play.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
        ),
      ],
    );
  }
}

class _HowItWorksStep extends StatelessWidget {
  const _HowItWorksStep({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Method',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Text(
          'Work begins with clean control on one surface. Then it expands into opposite-hand lead, dynamic shape, longer phrases, and flow on the kit.',
          style: textTheme.bodyLarge?.copyWith(height: 1.4),
        ),
        const SizedBox(height: 16),
        Text(
          'Today will point you toward the lanes that need attention. The matrix shows the vocabulary. Focus holds what you are actively developing.',
          style: textTheme.bodyLarge?.copyWith(height: 1.4),
        ),
      ],
    );
  }
}

class _SetupStep extends StatelessWidget {
  final UserProfileV1 draft;
  final ValueChanged<UserProfileV1> onChanged;

  const _SetupStep({super.key, required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        Text(
          'Set Your Defaults',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Text(
          'Set a lead side and a starting tempo so practice can begin quickly.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<HandednessV1>(
          initialValue: draft.handedness,
          decoration: const InputDecoration(
            labelText: 'Handedness',
            border: OutlineInputBorder(),
          ),
          items: HandednessV1.values
              .map(
                (HandednessV1 handedness) => DropdownMenuItem<HandednessV1>(
                  value: handedness,
                  child: Text(handedness.label),
                ),
              )
              .toList(growable: false),
          onChanged: (HandednessV1? value) {
            if (value == null) return;
            onChanged(draft.copyWith(handedness: value));
          },
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
                      '${draft.defaultBpm}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: draft.defaultBpm <= 30
                          ? null
                          : () => onChanged(
                              draft.copyWith(defaultBpm: draft.defaultBpm - 1),
                            ),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Expanded(
                      child: Slider(
                        value: draft.defaultBpm.toDouble(),
                        min: 30,
                        max: 260,
                        divisions: 230,
                        label: '${draft.defaultBpm} BPM',
                        onChanged: (double value) {
                          onChanged(draft.copyWith(defaultBpm: value.round()));
                        },
                      ),
                    ),
                    IconButton(
                      onPressed: draft.defaultBpm >= 260
                          ? null
                          : () => onChanged(
                              draft.copyWith(defaultBpm: draft.defaultBpm + 1),
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
          initialValue: draft.defaultTimerPreset,
          decoration: const InputDecoration(
            labelText: 'Default Timer',
            border: OutlineInputBorder(),
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
            onChanged(draft.copyWith(defaultTimerPreset: value));
          },
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Click Enabled by Default'),
          value: draft.clickEnabledByDefault,
          onChanged: (bool value) {
            onChanged(draft.copyWith(clickEnabledByDefault: value));
          },
        ),
      ],
    );
  }
}
