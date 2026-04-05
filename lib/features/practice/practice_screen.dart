// lib/features/practice/practice_screen.dart
//
// Triad Trainer — Practice Screen (v1)
//
// Responsibilities:
// - Layout + wiring only.
// - Compose modular widgets (PatternCard, KitDiagram, etc.).
// - Talk to PracticeController for state + intents.
// - No domain models, no generator math, no painters.
//
// Notes:
// - This screen uses ChangeNotifier directly via AnimatedBuilder to avoid
//   assuming Provider/Riverpod is in use.

import 'package:flutter/material.dart';

import '../../core/instrument/instrument_context_v1.dart';
import '../../core/pattern/pattern_engine.dart' as pe;
import '../../core/practice/practice_models.dart';
import '../../state/practice_controller.dart';
import '../settings/settings_screen.dart';
import 'widgets/kit_diagram.dart';
import 'widgets/pattern_card.dart';
import 'widgets/triad_picker.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late final PracticeController _c;

  @override
  void initState() {
    super.initState();
    _c = PracticeController();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  Future<void> _openTriadPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      enableDrag: false, // FIX: sheet cannot be dragged up/down
      builder: (BuildContext sheetCtx) {
        final double screenH = MediaQuery.of(sheetCtx).size.height;
        final double topPad = MediaQuery.of(sheetCtx).padding.top;
        final double botPad = MediaQuery.of(sheetCtx).padding.bottom;

        // Make the sheet effectively full-screen but still a bottom sheet.
        // This gives us stable 1/3 + 2/3 regions.
        final double sheetH = (screenH - topPad - botPad) * 0.94;

        return SafeArea(
          child: SizedBox(
            height: sheetH,
            child: AnimatedBuilder(
              animation: _c,
              builder: (BuildContext context, _) {
                final ColorScheme cs = Theme.of(context).colorScheme;

                final bool padMode = _c.instrument == InstrumentContextV1.pad;

                bool isKickTriad(String id) => id.toUpperCase().contains('K');

                bool isEnabled(String id) {
                  if (!padMode) return true;
                  // Rule: Pad = kick triads disabled.
                  return !isKickTriad(id);
                }

                void toggle(String id) {
                  if (!isEnabled(id)) return;
                  _c.toggleSelectedCellId(id);
                }

                void clear() => _c.setSelectedCellIds(const <String>[]);

                void done() {
                  // Session log is explicit: only on Done.
                  _c.logSessionOnDone();
                  Navigator.of(sheetCtx).pop();
                }

                final List<PracticeSessionLogEntryV1> recents = _c.recentSessions;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Column(
                    children: <Widget>[
                      // Top region (approx 1/3): Recents list (scrollable, clipped)
                      Expanded(
                        flex: 1,
                        child: _RecentsPanel(
                          entries: recents,
                          onTap: (PracticeSessionLogEntryV1 e) {
                            _c.restoreRecent(e);
                            Navigator.of(sheetCtx).pop();
                          },
                          onClear: _c.clearRecentSessions,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Bottom region (approx 2/3): Matrix (fixed size; scales down to fit)
                      Expanded(
                        flex: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: cs.outlineVariant),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: <Widget>[
                                if (padMode) ...<Widget>[
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Pad: kick triads disabled.',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],

                                // FIX: The matrix area is NOT scrollable.
                                // We scale the entire picker down (if needed) to fit
                                // this fixed bottom region.
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (BuildContext context, BoxConstraints c) {
                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.topCenter,
                                          child: SizedBox(
                                            width: c.maxWidth,
                                            height: c.maxHeight,
                                            child: TriadPicker(
                                              selectedCellIds: _c.selectedCellIds,
                                              onToggleCellId: toggle,
                                              onClear: _c.selectedCellIds.isEmpty ? null : clear,
                                              onDone: done,
                                              subtitle: 'Tap to select. Tap again to remove.',
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Map<DrumSurfaceV1, String> _defaultVoiceLabels() {
    return const <DrumSurfaceV1, String>{
      DrumSurfaceV1.snare: 'S',
      DrumSurfaceV1.tom1: '1',
      DrumSurfaceV1.tom2: '2',
      DrumSurfaceV1.floorTom: 'F',
      DrumSurfaceV1.hiHat: 'H',
      DrumSurfaceV1.ride: 'R',
      DrumSurfaceV1.kick: 'K',
    };
  }

  List<KitSurfaceSpec> _instrumentSurfaces({
    required InstrumentContextV1 instrument,
    required KitPresetV1 kit,
    required Map<DrumSurfaceV1, String> labels,
  }) {
    String requireLabel(DrumSurfaceV1 s) {
      final String? raw = labels[s];
      final String label = (raw ?? '').trim();
      assert(
        label.isNotEmpty,
        'voiceLabels must include a non-empty label for $s when rendering KitDiagram.',
      );
      return label;
    }

    KitSurfaceKind kindFor(DrumSurfaceV1 s) {
      return switch (s) {
        DrumSurfaceV1.snare => KitSurfaceKind.snare,
        DrumSurfaceV1.tom1 => KitSurfaceKind.tom1,
        DrumSurfaceV1.tom2 => KitSurfaceKind.tom2,
        DrumSurfaceV1.floorTom => KitSurfaceKind.floorTom,
        DrumSurfaceV1.hiHat => KitSurfaceKind.hiHat,
        DrumSurfaceV1.ride => KitSurfaceKind.ride,
        DrumSurfaceV1.kick => KitSurfaceKind.kick,
      };
    }

    if (instrument == InstrumentContextV1.pad) {
      return <KitSurfaceSpec>[
        KitSurfaceSpec(
          id: 'pad',
          label: requireLabel(DrumSurfaceV1.snare),
          kind: KitSurfaceKind.snare,
        ),
      ];
    }

    final List<DrumSurfaceV1> order = <DrumSurfaceV1>[
      DrumSurfaceV1.hiHat,
      DrumSurfaceV1.ride,
      DrumSurfaceV1.tom1,
      DrumSurfaceV1.tom2,
      DrumSurfaceV1.snare,
      DrumSurfaceV1.floorTom,
      DrumSurfaceV1.kick,
    ];

    final Set<DrumSurfaceV1> enabled = kit.surfaces().toSet();
    final List<KitSurfaceSpec> out = <KitSurfaceSpec>[];

    for (final DrumSurfaceV1 s in order) {
      if (!enabled.contains(s)) continue;
      out.add(
        KitSurfaceSpec(
          id: s.name,
          label: requireLabel(s),
          kind: kindFor(s),
        ),
      );
    }

    if (!enabled.contains(DrumSurfaceV1.kick)) {
      out.add(
        KitSurfaceSpec(
          id: DrumSurfaceV1.kick.name,
          label: requireLabel(DrumSurfaceV1.kick),
          kind: KitSurfaceKind.kick,
        ),
      );
    }

    return out;
  }

  String _instrumentCaption(InstrumentContextV1 instrument, KitPresetV1 kit) {
    return switch (instrument) {
      InstrumentContextV1.pad => 'Pad (hands only)',
      InstrumentContextV1.padKick => 'Pad + kick',
      InstrumentContextV1.kit =>
        'Kit (${kit.pieces}-piece, ${kit.leftHanded ? 'left' : 'right'}-handed)',
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, _) {
        // IMPORTANT: qualify our Pattern type to avoid collision with sky_engine Pattern.
        final pe.Pattern? p = _c.pattern;

        final String timerLabel = _formatTimer(_c.timer);
        final Map<DrumSurfaceV1, String> labels = _defaultVoiceLabels();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Triad Trainer'),
            actions: <Widget>[
              IconButton(
                onPressed: _openSettings,
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: DropdownButtonFormField<InstrumentContextV1>(
                          initialValue: _c.instrument,
                          items: <InstrumentContextV1>[
                            InstrumentContextV1.pad,
                            InstrumentContextV1.kit,
                          ]
                              .map(
                                (i) => DropdownMenuItem(
                                  value: i,
                                  child: Text(
                                    switch (i) {
                                      InstrumentContextV1.pad => 'Pad',
                                      InstrumentContextV1.kit => 'Kit',
                                      InstrumentContextV1.padKick => 'Pad + Kick',
                                    },
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (v) {
                            if (v != null) _c.setInstrument(v);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Instrument',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: <Widget>[
                      FilledButton.tonalIcon(
                        onPressed: _openTriadPicker,
                        icon: const Icon(Icons.grid_view),
                        label: const Text('Pick'),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _c.toggleTimerRunning,
                        icon: Icon(_c.timer.running ? Icons.pause : Icons.play_arrow),
                        tooltip: _c.timer.running ? 'Pause timer' : 'Start timer',
                      ),
                      const SizedBox(width: 6),
                      Text(timerLabel),
                      IconButton(
                        icon: const Icon(Icons.restart_alt),
                        tooltip: 'Reset timer',
                        onPressed: _c.resetTimer,
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: KitDiagram(
                      title: _instrumentCaption(_c.instrument, _c.kit),
                      surfaces: _instrumentSurfaces(
                        instrument: _c.instrument,
                        kit: _c.kit,
                        labels: labels,
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: PatternCard(
                          pattern: p,
                          focus: _c.focus,
                          instrument: _c.instrument,
                          kit: _c.kit,
                          voiceLabels: labels,
                          showKitDiagram: false,
                          showVoiceRow: false,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTimer(PracticeTimerState t) {
    String mmss(Duration d) {
      final int m = d.inMinutes;
      final int s = d.inSeconds % 60;
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    if (t.target == null) return mmss(t.elapsed);
    return '${mmss(t.elapsed)} / ${mmss(t.target!)}';
  }
}

/* -------------------------------------------------------------------------- */
/* Recents panel (scrollable + clipped)                                       */
/* -------------------------------------------------------------------------- */

class _RecentsPanel extends StatelessWidget {
  final List<PracticeSessionLogEntryV1> entries;
  final ValueChanged<PracticeSessionLogEntryV1> onTap;
  final VoidCallback onClear;

  const _RecentsPanel({
    required this.entries,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Card(
      elevation: 1,
      clipBehavior: Clip.hardEdge, // FIX: hard-clip ink/overscroll to card bounds
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Text('Recents', style: theme.textTheme.titleSmall),
                const Spacer(),
                TextButton.icon(
                  onPressed: entries.isEmpty ? null : onClear,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 6),

            Expanded(
              child: entries.isEmpty
                  ? Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        'No recents yet.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int i) {
                        final PracticeSessionLogEntryV1 e = entries[i];
                        return InkWell(
                          onTap: () => onTap(e),
                          child: Ink(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cs.outlineVariant),
                              color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    e.selectedCellIds.join(' \u2192 '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Menlo',
                                      fontFamilyFallback: <String>[
                                        'SF Mono',
                                        'Courier New',
                                        'monospace'
                                      ],
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(_fmtDuration(e.duration)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtDuration(Duration d) {
    final int m = d.inMinutes;
    final int s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
