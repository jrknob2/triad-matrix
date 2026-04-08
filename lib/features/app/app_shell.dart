import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../state/app_controller.dart';
import '../matrix/matrix_screen.dart';
import '../library/combination_builder_screen.dart';
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
  int _matrixRequestVersion = 0;
  MatrixScreenRequest? _matrixRequest;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        final List<Widget> tabs = <Widget>[
          TodayScreen(
            key: ValueKey<String>('today_${widget.controller.resetVersion}'),
            controller: widget.controller,
            onOpenMatrix: _openMatrix,
            onOpenFocus: () => setState(() => _currentIndex = 2),
            onOpenItem: _openItemDetail,
            onPracticeItem: _openPracticeItem,
            onPracticeItemInMode: _openPracticeItemInMode,
            onBuildComboFromItems: _openCombinationBuilderFromItems,
          ),
          MatrixScreen(
            key: ValueKey<String>('matrix_${widget.controller.resetVersion}'),
            controller: widget.controller,
            request: _matrixRequest,
            onOpenItem: _openItemDetail,
            onPracticeItem: _openPracticeItem,
            onPracticeItemInMode: _openPracticeItemInMode,
            onBuildComboFromItems: _openCombinationBuilderFromItems,
          ),
          FocusScreen(
            key: ValueKey<String>('focus_${widget.controller.resetVersion}'),
            controller: widget.controller,
            onOpenItem: _openItemDetail,
            onPracticeItem: _openPracticeItem,
            onPracticeItemInMode: _openPracticeItemInMode,
          ),
          ProgressScreen(
            key: ValueKey<String>('progress_${widget.controller.resetVersion}'),
            controller: widget.controller,
            onOpenItem: _openItemDetail,
          ),
        ];

        final List<String> titles = <String>[
          'Coach',
          'Matrix',
          'Working On',
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
                label: 'Coach',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'Matrix',
              ),
              NavigationDestination(
                icon: Icon(Icons.backpack_outlined),
                selectedIcon: Icon(Icons.backpack),
                label: 'Focus',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: 'Progress',
              ),
            ],
          ),
        );
      },
    );
  }

  void _openMatrix({
    LearningLaneV1? lane,
    TriadMatrixFilterPaletteV1? palette,
    Set<TriadMatrixFilterV1>? filters,
  }) {
    setState(() {
      _matrixRequestVersion++;
      _matrixRequest = MatrixScreenRequest(
        version: _matrixRequestVersion,
        lane: lane,
        palette: palette,
        filters: filters ?? const <TriadMatrixFilterV1>{},
      );
      _currentIndex = 1;
    });
  }

  void _openPracticeItem(String itemId) {
    _openPracticeItemInMode(itemId, PracticeModeV1.singleSurface);
  }

  void _openPracticeItemInMode(String itemId, PracticeModeV1 mode) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeSessionScreen(
          controller: widget.controller,
          setup: widget.controller.buildSessionForItem(
            itemId,
            practiceMode: mode,
          ),
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
          onPracticeItemInMode: _openPracticeItemInMode,
          onBuildComboFromItem: _openCombinationBuilderFromItem,
        ),
      ),
    );
  }

  void _openCombinationBuilderFromItem(String itemId) {
    _openCombinationBuilderFromItems(<String>[itemId]);
  }

  void _openCombinationBuilderFromItems(List<String> itemIds) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CombinationBuilderScreen(
          controller: widget.controller,
          initialItemIds: itemIds,
        ),
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
