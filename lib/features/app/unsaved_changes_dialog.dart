import 'package:flutter/material.dart';

import 'drumcabulary_theme.dart';

enum UnsavedChangesDecision { save, discard, keepEditing }

Future<UnsavedChangesDecision?> showUnsavedChangesDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String saveLabel,
  bool canSave = true,
}) {
  return showDialog<UnsavedChangesDecision>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: DrumcabularyTheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: DrumcabularyTheme.line),
        ),
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          OutlinedButton(
            onPressed: () =>
                Navigator.of(context).pop(UnsavedChangesDecision.keepEditing),
            child: const Text('Keep Editing'),
          ),
          OutlinedButton(
            onPressed: () =>
                Navigator.of(context).pop(UnsavedChangesDecision.discard),
            child: const Text('Discard'),
          ),
          if (canSave)
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(UnsavedChangesDecision.save),
              child: Text(saveLabel),
            ),
        ],
      );
    },
  );
}
