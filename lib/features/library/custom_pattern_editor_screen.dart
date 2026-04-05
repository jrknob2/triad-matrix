import 'package:flutter/material.dart';

import '../../state/app_controller.dart';

class CustomPatternEditorScreen extends StatefulWidget {
  final AppController controller;

  const CustomPatternEditorScreen({
    super.key,
    required this.controller,
  });

  @override
  State<CustomPatternEditorScreen> createState() =>
      _CustomPatternEditorScreenState();
}

class _CustomPatternEditorScreenState extends State<CustomPatternEditorScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _stickingController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
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
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Pattern Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
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
              title: const Text('Validation'),
              subtitle: Text(
                valid
                    ? 'Pattern is ready to save.'
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
    final String name = _nameController.text.trim().isEmpty
        ? 'Custom Pattern'
        : _nameController.text.trim();
    final List<String> tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);

    widget.controller.createCustomPattern(
      name: name,
      sticking: _stickingController.text.trim(),
      tags: tags,
    );

    Navigator.of(context).pop();
  }
}
