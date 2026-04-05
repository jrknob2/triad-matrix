import 'package:flutter/material.dart';

import '../../state/app_controller.dart';

class CustomPatternEditorScreen extends StatefulWidget {
  final AppController controller;

  const CustomPatternEditorScreen({super.key, required this.controller});

  @override
  State<CustomPatternEditorScreen> createState() =>
      _CustomPatternEditorScreenState();
}

class _CustomPatternEditorScreenState extends State<CustomPatternEditorScreen> {
  final TextEditingController _stickingController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  @override
  void dispose() {
    _stickingController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String sticking = _stickingController.text.trim();
    final bool valid = sticking.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Custom Pattern')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextField(
            controller: _stickingController,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Sticking',
              hintText: 'Example: R K L R L',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tagsController,
            decoration: const InputDecoration(
              labelText: 'Tags',
              hintText: 'Comma-separated',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Pattern'),
              subtitle: Text(
                valid
                    ? 'This sticking becomes the saved pattern name. Duplicate stickings collapse to one pattern.'
                    : 'Enter a sticking pattern to continue.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: valid ? _save : null,
            child: const Text('Save Pattern'),
          ),
        ],
      ),
    );
  }

  void _save() {
    final List<String> tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);

    widget.controller.createCustomPattern(
      sticking: _stickingController.text.trim(),
      tags: tags,
    );

    Navigator.of(context).pop();
  }
}
