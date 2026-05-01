import 'package:flutter/material.dart';

import '../../../core/practice/practice_domain_v1.dart';
import '../../../features/app/app_formatters.dart';
import '../../../features/app/drumcabulary_ui.dart';
import '../../../state/app_controller.dart';

class VoiceAssignmentEditor extends StatelessWidget {
  final AppController? controller;
  final String? itemId;
  final List<String>? tokens;
  final List<DrumVoiceV1>? voices;
  final ValueChanged<int>? onTapNote;
  final bool editable;
  final bool showHelpText;

  const VoiceAssignmentEditor({
    super.key,
    this.controller,
    this.itemId,
    this.tokens,
    this.voices,
    this.onTapNote,
    this.editable = true,
    this.showHelpText = true,
  }) : assert(
         (controller != null && itemId != null) ||
             (tokens != null && voices != null),
         'Provide either controller+itemId or tokens+voices.',
       );

  @override
  Widget build(BuildContext context) {
    final List<String> resolvedTokens = _resolvedTokens;
    final List<DrumVoiceV1> resolvedVoices = _resolvedVoices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List<Widget>.generate(resolvedTokens.length, (index) {
            final String token = resolvedTokens[index];
            final DrumVoiceV1 voice = resolvedVoices[index];
            return DrumIndexedPill(
              indexLabel: '${index + 1}',
              label: Text('$token:${voice.shortLabel}'),
              onPressed: editable && _allowsAuthoredVoice(token)
                  ? () {
                      _handleTap(index, token, voice);
                    }
                  : null,
              backgroundColor: _backgroundFor(voice),
              borderColor: _borderFor(voice),
            );
          }),
        ),
        if (showHelpText) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            editable
                ? 'Tap R/L notes to change voices. Fixed tokens keep their playback voices.'
                : 'Voice labels show the flow path across the kit.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  List<String> get _resolvedTokens {
    if (tokens != null) return tokens!;
    return controller!.noteTokensFor(itemId!);
  }

  List<DrumVoiceV1> get _resolvedVoices {
    if (voices != null) return voices!;
    return controller!.noteVoicesFor(itemId!);
  }

  void _handleTap(int index, String token, DrumVoiceV1 current) {
    final DrumVoiceV1 next = _nextVoice(token, current);
    if (onTapNote != null) {
      onTapNote!(index);
      return;
    }

    controller!.setNoteVoice(itemId: itemId!, noteIndex: index, voice: next);
  }

  DrumVoiceV1 _nextVoice(String token, DrumVoiceV1 current) {
    if (token == 'K') return DrumVoiceV1.kick;
    if (!_allowsAuthoredVoice(token)) return DrumVoiceV1.snare;

    const List<DrumVoiceV1> cycle = <DrumVoiceV1>[
      DrumVoiceV1.snare,
      DrumVoiceV1.rackTom,
      DrumVoiceV1.tom2,
      DrumVoiceV1.floorTom,
      DrumVoiceV1.hihat,
    ];

    final int index = cycle.indexOf(current);
    if (index < 0) return cycle.first;
    return cycle[(index + 1) % cycle.length];
  }

  bool _allowsAuthoredVoice(String token) {
    return PatternTokenV1.fromSymbol(token).allowsAuthoredVoice;
  }

  Color _backgroundFor(DrumVoiceV1 voice) {
    return switch (voice) {
      DrumVoiceV1.snare => const Color(0xFFF4EFE6),
      DrumVoiceV1.rackTom => const Color(0xFFE8EFE0),
      DrumVoiceV1.tom2 => const Color(0xFFE3EBDD),
      DrumVoiceV1.floorTom => const Color(0xFFE3E0EF),
      DrumVoiceV1.hihat => const Color(0xFFE1EDF2),
      DrumVoiceV1.kick => const Color(0xFFE9E2D7),
    };
  }

  Color _borderFor(DrumVoiceV1 voice) {
    return switch (voice) {
      DrumVoiceV1.snare => const Color(0x22000000),
      DrumVoiceV1.rackTom => const Color(0xFF5F7A44),
      DrumVoiceV1.tom2 => const Color(0xFF6D7F36),
      DrumVoiceV1.floorTom => const Color(0xFF6A5B97),
      DrumVoiceV1.hihat => const Color(0xFF4D7A8B),
      DrumVoiceV1.kick => const Color(0xFF8B6D4D),
    };
  }
}
