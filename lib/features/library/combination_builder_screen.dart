import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../app/app_formatters.dart';
import '../../state/app_controller.dart';

class CombinationBuilderScreen extends StatefulWidget {
  final AppController controller;
  final List<String> initialItemIds;

  const CombinationBuilderScreen({
    super.key,
    required this.controller,
    this.initialItemIds = const <String>[],
  });

  @override
  State<CombinationBuilderScreen> createState() =>
      _CombinationBuilderScreenState();
}

class _CombinationBuilderScreenState extends State<CombinationBuilderScreen> {
  final TextEditingController _nameController = TextEditingController();
  final List<String> _selectedItemIds = <String>[];
  ComboIntentTagV1 _intentTag = ComboIntentTagV1.coreSkills;

  @override
  void initState() {
    super.initState();
    _selectedItemIds.addAll(widget.initialItemIds);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<PracticeItemV1> sourceItems = widget.controller.sourceItemsForBuilder();

    return Scaffold(
      appBar: AppBar(title: const Text('Build Combo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Combo Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ComboIntentTagV1>(
            initialValue: _intentTag,
            decoration: const InputDecoration(
              labelText: 'Intent Tag',
              border: OutlineInputBorder(),
            ),
            items: ComboIntentTagV1.values
                .map(
                  (tag) => DropdownMenuItem<ComboIntentTagV1>(
                    value: tag,
                    child: Text(_labelForIntentTag(tag)),
                  ),
                )
                .toList(growable: false),
            onChanged: (ComboIntentTagV1? value) {
              if (value == null) return;
              setState(() => _intentTag = value);
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Selected Sequence',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_selectedItemIds.isEmpty)
                    const Text('Select source items below.')
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _selectedItemIds.length,
                      onReorder: _onReorder,
                      itemBuilder: (BuildContext context, int index) {
                        final String itemId = _selectedItemIds[index];
                        final PracticeItemV1 item = widget.controller.itemById(itemId);
                        return ListTile(
                          key: ValueKey<String>('selected_$itemId$index'),
                          title: Text(item.name),
                          subtitle: Text(item.sticking),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() => _selectedItemIds.removeAt(index));
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Source Items', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...sourceItems.map(
                    (item) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.name),
                      subtitle: Text('${item.family.label} · ${item.sticking}'),
                      value: _selectedItemIds.contains(item.id),
                      onChanged: (bool? checked) {
                        setState(() {
                          if (checked ?? false) {
                            _selectedItemIds.add(item.id);
                          } else {
                            _selectedItemIds.remove(item.id);
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _selectedItemIds.isEmpty ? null : _saveCombo,
            child: const Text('Save Combo'),
          ),
        ],
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final String item = _selectedItemIds.removeAt(oldIndex);
      _selectedItemIds.insert(newIndex, item);
    });
  }

  void _saveCombo() {
    final String rawName = _nameController.text.trim();
    final String name = rawName.isEmpty ? 'New Combo' : rawName;
    widget.controller.createCombination(
      name: name,
      itemIds: _selectedItemIds,
      intentTag: _intentTag,
    );
    Navigator.of(context).pop();
  }

  String _labelForIntentTag(ComboIntentTagV1 tag) {
    return switch (tag) {
      ComboIntentTagV1.coreSkills => 'Core Skills',
      ComboIntentTagV1.flow => 'Flow',
      ComboIntentTagV1.both => 'Both',
    };
  }
}
