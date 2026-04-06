import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../matrix/matrix_screen.dart';
import '../library/combination_builder_screen.dart';
import '../library/custom_pattern_editor_screen.dart';
import '../library/item_detail_screen.dart';
import '../practice/practice_session_screen.dart';
import '../progress/progress_screen.dart';
import '../settings/app_settings_screen.dart';
import '../today/today_screen.dart';
import '../toolkit/toolkit_screen.dart';

class AppShell extends StatefulWidget {
  final AppController controller;

  const AppShell({super.key, required this.controller});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = <Widget>[
      TodayScreen(
        controller: widget.controller,
        onOpenMatrix: () => setState(() => _currentIndex = 1),
        onOpenItem: _openItemDetail,
        onPracticeItem: _openPracticeItem,
      ),
      MatrixScreen(
        controller: widget.controller,
        onOpenItem: _openItemDetail,
        onPracticeItem: _openPracticeItem,
        onBuildComboFromItem: _openCombinationBuilderFromItem,
      ),
      ToolkitScreen(
        controller: widget.controller,
        onOpenItem: _openItemDetail,
        onPracticeItem: _openPracticeItem,
        onBuildCombo: _openCombinationBuilder,
        onCreateCustomPattern: _openCustomPatternEditor,
      ),
      ProgressScreen(
        controller: widget.controller,
        onOpenItem: _openItemDetail,
      ),
    ];

    final List<String> titles = <String>[
      'Today',
      'Matrix',
      'Toolkit',
      'Progress',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        actions: <Widget>[
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() => _currentIndex = index);
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Matrix',
          ),
          NavigationDestination(
            icon: Icon(Icons.backpack_outlined),
            selectedIcon: Icon(Icons.backpack),
            label: 'Toolkit',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Progress',
          ),
        ],
      ),
    );
  }

  void _openPracticeItem(String itemId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeSessionScreen(
          controller: widget.controller,
          setup: widget.controller.buildSessionForItem(itemId),
        ),
      ),
    );
  }

  void _openItemDetail(String itemId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ItemDetailScreen(
          controller: widget.controller,
          itemId: itemId,
          onPracticeItem: _openPracticeItem,
          onBuildComboFromItem: _openCombinationBuilderFromItem,
        ),
      ),
    );
  }

  void _openCombinationBuilder() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CombinationBuilderScreen(controller: widget.controller),
      ),
    );
  }

  void _openCombinationBuilderFromItem(String itemId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CombinationBuilderScreen(
          controller: widget.controller,
          initialItemIds: <String>[itemId],
        ),
      ),
    );
  }

  void _openCustomPatternEditor() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CustomPatternEditorScreen(controller: widget.controller),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppSettingsScreen(controller: widget.controller),
      ),
    );
  }
}
