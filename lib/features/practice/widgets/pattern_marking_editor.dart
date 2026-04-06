import 'package:flutter/material.dart';

import '../../../core/practice/practice_domain_v1.dart';
import '../../../state/app_controller.dart';

class PatternMarkingEditor extends StatelessWidget {
  final AppController? controller;
  final String? itemId;
  final List<String>? tokens;
  final List<PatternNoteMarkingV1>? markings;
  final ValueChanged<int>? onTapNote;
  final bool editable;

  const PatternMarkingEditor({
    super.key,
    this.controller,
    this.itemId,
    this.tokens,
    this.markings,
    this.onTapNote,
    this.editable = true,
  }) : assert(
         (controller != null && itemId != null) ||
             (tokens != null && markings != null),
         'Provide either controller+itemId or tokens+markings.',
       );

  @override
  Widget build(BuildContext context) {
    final List<String> resolvedTokens = _resolvedTokens;
    final List<PatternNoteMarkingV1> resolvedMarkings = _resolvedMarkings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List<Widget>.generate(resolvedTokens.length, (index) {
            final String token = resolvedTokens[index];
            final PatternNoteMarkingV1 marking = resolvedMarkings[index];
            return ActionChip(
              label: Text(_labelFor(token, marking)),
              avatar: Text('${index + 1}'),
              onPressed: editable
                  ? () {
                      _handleTap(index, token, marking);
                    }
                  : null,
              backgroundColor: _backgroundFor(marking),
              side: BorderSide(color: _borderFor(marking)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Text(
          editable
              ? 'Tap notes to cycle. Kicks skip accents.'
              : "Accent notes use a tick mark. Ghost notes use parentheses.",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  List<String> get _resolvedTokens {
    if (tokens != null) return tokens!;
    return controller!.noteTokensFor(itemId!);
  }

  List<PatternNoteMarkingV1> get _resolvedMarkings {
    if (markings != null) return markings!;
    return controller!.noteMarkingsFor(itemId!);
  }

  void _handleTap(int index, String token, PatternNoteMarkingV1 current) {
    final PatternNoteMarkingV1 next = _nextMarking(token, current);
    if (onTapNote != null) {
      onTapNote!(index);
      return;
    }

    controller!.setNoteMarking(
      itemId: itemId!,
      noteIndex: index,
      marking: next,
    );
  }

  String _labelFor(String token, PatternNoteMarkingV1 marking) {
    return switch (marking) {
      PatternNoteMarkingV1.normal => token,
      PatternNoteMarkingV1.accent => '^$token',
      PatternNoteMarkingV1.ghost => '($token)',
    };
  }

  PatternNoteMarkingV1 _nextMarking(
    String token,
    PatternNoteMarkingV1 current,
  ) {
    if (token == 'K') {
      return switch (current) {
        PatternNoteMarkingV1.normal => PatternNoteMarkingV1.ghost,
        PatternNoteMarkingV1.accent => PatternNoteMarkingV1.ghost,
        PatternNoteMarkingV1.ghost => PatternNoteMarkingV1.normal,
      };
    }

    return switch (current) {
      PatternNoteMarkingV1.normal => PatternNoteMarkingV1.accent,
      PatternNoteMarkingV1.accent => PatternNoteMarkingV1.ghost,
      PatternNoteMarkingV1.ghost => PatternNoteMarkingV1.normal,
    };
  }

  Color _backgroundFor(PatternNoteMarkingV1 marking) {
    return switch (marking) {
      PatternNoteMarkingV1.normal => const Color(0xFFF4EFE6),
      PatternNoteMarkingV1.accent => const Color(0xFFE7D6A8),
      PatternNoteMarkingV1.ghost => const Color(0xFFDCE5EE),
    };
  }

  Color _borderFor(PatternNoteMarkingV1 marking) {
    return switch (marking) {
      PatternNoteMarkingV1.normal => const Color(0x22000000),
      PatternNoteMarkingV1.accent => const Color(0xFF8E6B1F),
      PatternNoteMarkingV1.ghost => const Color(0xFF55718B),
    };
  }
}
