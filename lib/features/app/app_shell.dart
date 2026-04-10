import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../state/app_controller.dart';
import '../matrix/matrix_screen.dart';
import '../library/combination_builder_screen.dart';
import '../library/item_detail_screen.dart';
import '../practice/practice_screen.dart';
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
  final GlobalKey<NavigatorState> _shellNavigatorKey =
      GlobalKey<NavigatorState>();

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
            onOpenFocus: () => setState(() => _currentIndex = 3),
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
          PracticeScreen(
            key: ValueKey<String>('practice_${widget.controller.resetVersion}'),
            controller: widget.controller,
            onRepeatPreviousSession: _repeatPreviousSession,
            onPracticeWarmup: _openWarmupPractice,
            onStartWorkingOnSession: _openWorkingOnSelectionPractice,
            onOpenMatrix: () => setState(() => _currentIndex = 1),
            onOpenFocus: () => setState(() => _currentIndex = 3),
          ),
          FocusScreen(
            key: ValueKey<String>('focus_${widget.controller.resetVersion}'),
            controller: widget.controller,
            onOpenItem: _openItemDetail,
            onPracticeItemInMode: _openPracticeItemInMode,
            onOpenMatrix: () => setState(() => _currentIndex = 1),
          ),
          ProgressScreen(
            key: ValueKey<String>('progress_${widget.controller.resetVersion}'),
            controller: widget.controller,
            onOpenItem: _openItemDetail,
          ),
        ];

        return Scaffold(
          body: Navigator(
            key: _shellNavigatorKey,
            pages: <Page<void>>[
              MaterialPage<void>(
                key: ValueKey<int>(_currentIndex),
                child: Scaffold(
                  appBar: AppBar(
                    title: Text(_titles[_currentIndex]),
                    actions: <Widget>[
                      IconButton(
                        onPressed: _openSettings,
                        icon: const Icon(Icons.settings),
                        tooltip: 'Settings',
                      ),
                    ],
                  ),
                  body: IndexedStack(index: _currentIndex, children: tabs),
                ),
              ),
            ],
            onDidRemovePage: (_) {},
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFFE8DDD0),
              border: Border(top: BorderSide(color: Color(0x22000000))),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 18,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: NavigationBar(
              backgroundColor: const Color(0xFFE8DDD0),
              selectedIndex: _currentIndex,
              onDestinationSelected: (int index) {
                _shellNavigatorKey.currentState?.popUntil(
                  (route) => route.isFirst,
                );
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
                  icon: Icon(Icons.play_circle_outline_rounded),
                  selectedIcon: Icon(Icons.play_circle_rounded),
                  label: 'Practice',
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
          ),
        );
      },
    );
  }

  List<String> get _titles => const <String>[
    'Coach',
    'Triad Matrix',
    'Practice',
    'Working On',
    'Progress',
  ];

  void _openMatrix({LearningLaneV1? lane, Set<TriadMatrixFilterV1>? filters}) {
    setState(() {
      _matrixRequestVersion++;
      _matrixRequest = MatrixScreenRequest(
        version: _matrixRequestVersion,
        lane: lane,
        filters: filters ?? const <TriadMatrixFilterV1>{},
      );
      _currentIndex = 1;
    });
  }

  void _openPracticeItem(String itemId) {
    _openPracticeItemInMode(itemId, PracticeModeV1.singleSurface);
  }

  void _openPracticeItemInMode(String itemId, PracticeModeV1 mode) {
    _shellNavigatorKey.currentState?.push(
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

  void _openWorkingOnSelectionPractice(
    List<String> itemIds,
    PracticeModeV1 mode,
    int bpm,
    TimerPresetV1 timerPreset,
  ) {
    if (itemIds.isEmpty) return;
    final PracticeSessionSetupV1 setup = widget.controller
        .buildSessionForWorkingOnSelection(
          itemIds,
          practiceMode: mode,
          bpm: bpm,
          timerPreset: timerPreset,
        );
    _shellNavigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PracticeSessionScreen(controller: widget.controller, setup: setup),
      ),
    );
  }

  void _openWarmupPractice() {
    _shellNavigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeSessionScreen(
          controller: widget.controller,
          setup: widget.controller.buildWarmupSession(),
        ),
      ),
    );
  }

  void _repeatPreviousSession(PracticeSessionLogV1 session) {
    final PracticeSessionSetupV1? setup = widget.controller
        .buildSessionFromSessionOrNull(session);
    if (setup == null) return;
    _shellNavigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PracticeSessionScreen(controller: widget.controller, setup: setup),
      ),
    );
  }

  void _openItemDetail(String itemId) {
    _shellNavigatorKey.currentState?.push(
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
    _shellNavigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => CombinationBuilderScreen(
          controller: widget.controller,
          initialItemIds: itemIds,
        ),
      ),
    );
  }

  void _openSettings() {
    _shellNavigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => AppSettingsScreen(controller: widget.controller),
      ),
    );
  }
}
