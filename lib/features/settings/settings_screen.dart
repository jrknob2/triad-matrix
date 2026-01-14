// lib/features/settings/settings_screen.dart
//
// Triad Trainer — Settings Screen (v1)
//
// MVP intent:
// - A dedicated screen reachable from PracticeScreen via the gear icon.
// - Keep this screen UI-only for now (no persistence layer yet).
// - Wire in real state later (controller/service) once the UX is settled.
//
// NOTE:
// This file is intentionally standalone and does not assume Provider/Riverpod.
// If/when we want settings to affect practice behavior, we’ll pass the
// PracticeController in (or introduce a SettingsController) in a deliberate step.

import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            Text(
              'Phase 1 (MVP)',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'These are placeholders while we finalize the practice UX. '
              'Next step is to wire these to the PracticeController (or a SettingsController) '
              'and persist them.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // ------------------------------ Practice ------------------------------
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Practice', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    const _ToggleTile(
                      title: 'Show kit diagram',
                      subtitle: 'Display the pad/kit graphic above the pattern card.',
                      initial: true,
                    ),
                    const _ToggleTile(
                      title: 'Show voice row',
                      subtitle: 'Render a minimal voice row under the pattern (kit mode only).',
                      initial: false,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ------------------------------ Generator -----------------------------
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Generator', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    const _ToggleTile(
                      title: 'Infinite repeat (Training)',
                      subtitle: 'Training mode can repeat indefinitely for internalization.',
                      initial: true,
                    ),
                    const _ToggleTile(
                      title: 'Strict “Flow” continuity',
                      subtitle: 'Favor longer phrases and fewer hard stops in Flow mode.',
                      initial: true,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ------------------------------ UI -----------------------------------
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('UI', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    const _StepperTile(
                      title: 'Default BPM',
                      subtitle: 'Initial tempo when the app opens.',
                      initial: 92,
                      min: 30,
                      max: 260,
                      step: 1,
                    ),
                    const SizedBox(height: 8),
                    const _ToggleTile(
                      title: 'Click enabled by default',
                      subtitle: 'Start with the click toggle on.',
                      initial: true,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            FilledButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.check),
              label: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Simple local-only tiles (no external state yet)                             */
/* -------------------------------------------------------------------------- */

class _ToggleTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool initial;

  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.initial,
  });

  @override
  State<_ToggleTile> createState() => _ToggleTileState();
}

class _ToggleTileState extends State<_ToggleTile> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(widget.title),
      subtitle: Text(widget.subtitle),
      value: _value,
      onChanged: (bool v) => setState(() => _value = v),
    );
  }
}

class _StepperTile extends StatefulWidget {
  final String title;
  final String subtitle;

  final int initial;
  final int min;
  final int max;
  final int step;

  const _StepperTile({
    required this.title,
    required this.subtitle,
    required this.initial,
    required this.min,
    required this.max,
    required this.step,
  });

  @override
  State<_StepperTile> createState() => _StepperTileState();
}

class _StepperTileState extends State<_StepperTile> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial.clamp(widget.min, widget.max);
  }

  void _bump(int delta) {
    final int next = (_value + delta).clamp(widget.min, widget.max);
    if (next == _value) return;
    setState(() => _value = next);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(widget.title),
      subtitle: Text(widget.subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: 'Decrease',
            icon: const Icon(Icons.remove),
            onPressed: () => _bump(-widget.step),
          ),
          Text(
            '$_value',
            style: theme.textTheme.titleMedium,
          ),
          IconButton(
            tooltip: 'Increase',
            icon: const Icon(Icons.add),
            onPressed: () => _bump(widget.step),
          ),
        ],
      ),
    );
  }
}
