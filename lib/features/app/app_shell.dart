import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../home/home_screen.dart';
import '../library/combination_builder_screen.dart';
import '../library/custom_pattern_editor_screen.dart';
import '../library/item_detail_screen.dart';
import '../library/library_screen.dart';
import '../practice/practice_setup_screen.dart';
import '../progress/progress_screen.dart';
import '../routine/routine_screen.dart';
import '../settings/app_settings_screen.dart';

class AppShell extends StatefulWidget {
  final AppController controller;

  const AppShell({
    super.key,
    required this.controller,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = <Widget>[
      HomeScreen(
        controller: widget.controller,
        onStartPractice: _openSetup,
        onGeneratePractice: _openGeneratedSetup,
        onContinueRoutine: () => setState(() => _currentIndex = 2),
        onOpenItem: _openItemDetail,
      ),
      LibraryScreen(
        controller: widget.controller,
        onOpenItem: _openItemDetail,
        onPracticeItem: _openSetupForItem,
        onBuildCombo: _openCombinationBuilder,
        onCreateCustomPattern: _openCustomPatternEditor,
      ),
      RoutineScreen(
        controller: widget.controller,
        onOpenItem: _openItemDetail,
        onPracticeItem: _openSetupForItem,
      ),
      ProgressScreen(
        controller: widget.controller,
        onOpenItem: _openItemDetail,
      ),
    ];

    final List<String> titles = <String>[
      'Triad Trainer',
      'Library',
      'Routine',
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
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() => _currentIndex = index);
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.playlist_add_check_outlined),
            selectedIcon: Icon(Icons.playlist_add_check),
            label: 'Routine',
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

  void _openSetup() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeSetupScreen(controller: widget.controller),
      ),
    );
  }

  void _openGeneratedSetup() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeSetupScreen(
          controller: widget.controller,
          generated: true,
        ),
      ),
    );
  }

  void _openSetupForItem(String itemId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeSetupScreen(
          controller: widget.controller,
          initialItemId: itemId,
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
          onPracticeItem: _openSetupForItem,
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
        builder: (_) => CustomPatternEditorScreen(controller: widget.controller),
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
