import 'package:flutter/material.dart';

import '../../../core/practice/practice_domain_v1.dart';
import '../../../state/app_controller.dart';

class PatternMarkingEditor extends StatelessWidget {
  final AppController controller;
  final String itemId;
  final bool editable;

  const PatternMarkingEditor({
    super.key,
    required this.controller,
    required this.itemId,
    this.editable = true,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> tokens = controller.noteTokensFor(itemId);
    final List<PatternNoteMarkingV1> markings = controller.noteMarkingsFor(
      itemId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List<Widget>.generate(tokens.length, (index) {
            final PatternNoteMarkingV1 marking = markings[index];
            return ActionChip(
              label: Text(_labelFor(tokens[index], marking)),
              avatar: Text('${index + 1}'),
              onPressed: editable
                  ? () {
                      controller.setNoteMarking(
                        itemId: itemId,
                        noteIndex: index,
                        marking: _nextMarking(marking),
                      );
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
              ? "Tap notes to cycle Normal -> Accent (') -> Ghost (( ))."
              : "Accent notes use a tick mark. Ghost notes use parentheses.",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String _labelFor(String token, PatternNoteMarkingV1 marking) {
    return switch (marking) {
      PatternNoteMarkingV1.normal => token,
      PatternNoteMarkingV1.accent => "$token'",
      PatternNoteMarkingV1.ghost => '($token)',
    };
  }

  PatternNoteMarkingV1 _nextMarking(PatternNoteMarkingV1 current) {
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
