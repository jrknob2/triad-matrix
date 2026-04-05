import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../state/app_controller.dart';

class LibraryScreen extends StatefulWidget {
  final AppController controller;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;
  final VoidCallback onBuildCombo;
  final VoidCallback onCreateCustomPattern;

  const LibraryScreen({
    super.key,
    required this.controller,
    required this.onOpenItem,
    required this.onPracticeItem,
    required this.onBuildCombo,
    required this.onCreateCustomPattern,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  MaterialFamilyV1 _family = MaterialFamilyV1.triad;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        final items = widget.controller.itemsByFamily(_family);

        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: <Widget>[
                  SegmentedButton<MaterialFamilyV1>(
                    segments: const <ButtonSegment<MaterialFamilyV1>>[
                      ButtonSegment(
                        value: MaterialFamilyV1.triad,
                        label: Text('Triads'),
                      ),
                      ButtonSegment(
                        value: MaterialFamilyV1.fiveNote,
                        label: Text('5s'),
                      ),
                      ButtonSegment(
                        value: MaterialFamilyV1.custom,
                        label: Text('Custom'),
                      ),
                      ButtonSegment(
                        value: MaterialFamilyV1.combo,
                        label: Text('Combos'),
                      ),
                    ],
                    selected: <MaterialFamilyV1>{_family},
                    onSelectionChanged: (Set<MaterialFamilyV1> selection) {
                      setState(() => _family = selection.first);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onBuildCombo,
                          child: const Text('Build Combo'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: widget.onCreateCustomPattern,
                          child: const Text('New Custom'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (BuildContext context, int index) {
                  final item = items[index];
                  final competency = widget.controller.competencyFor(item.id);
                  final totalTime = widget.controller.totalTime(itemId: item.id);
                  final inRoutine = widget.controller.isInRoutine(item.id);

                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(item.name),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${item.sticking}\n'
                          '${competency.label} · ${formatDuration(totalTime)}'
                          '${inRoutine ? ' · In Routine' : ''}',
                        ),
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (String value) {
                          switch (value) {
                            case 'practice':
                              widget.onPracticeItem(item.id);
                              break;
                            case 'routine':
                              widget.controller.toggleRoutineItem(item.id);
                              break;
                            case 'detail':
                              widget.onOpenItem(item.id);
                              break;
                          }
                        },
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'practice',
                            child: Text('Practice Now'),
                          ),
                          PopupMenuItem<String>(
                            value: 'routine',
                            child: Text(inRoutine ? 'Remove from Routine' : 'Add to Routine'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'detail',
                            child: Text('Open Detail'),
                          ),
                        ],
                      ),
                      onTap: () => widget.onOpenItem(item.id),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
