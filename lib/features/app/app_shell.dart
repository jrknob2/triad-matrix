import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../state/app_controller.dart';
import 'app_viewport.dart';
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
    final bool isTablet = AppViewport.isTablet(context);
    final bool extendedRail = AppViewport.useExtendedRail(context);

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

        final Widget shellContent = Navigator(
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
        );

        if (isTablet) {
          return Scaffold(
            body: Row(
              children: <Widget>[
                NavigationRail(
                  selectedIndex: _currentIndex,
                  extended: extendedRail,
                  onDestinationSelected: _selectTab,
                  leading: const SizedBox(height: 8),
                  destinations: const <NavigationRailDestination>[
                    NavigationRailDestination(
                      icon: Icon(Icons.wb_sunny_outlined),
                      selectedIcon: Icon(Icons.wb_sunny),
                      label: Text('Coach'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.grid_view_outlined),
                      selectedIcon: Icon(Icons.grid_view_rounded),
                      label: Text('Matrix'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.play_circle_outline_rounded),
                      selectedIcon: Icon(Icons.play_circle_rounded),
                      label: Text('Practice'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.backpack_outlined),
                      selectedIcon: Icon(Icons.backpack),
                      label: Text('Focus'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.bar_chart_outlined),
                      selectedIcon: Icon(Icons.bar_chart),
                      label: Text('Progress'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: shellContent),
              ],
            ),
          );
        }

        return Scaffold(
          body: shellContent,
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
              onDestinationSelected: _selectTab,
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
    _openPracticeSession(
      widget.controller.buildSessionForItem(itemId, practiceMode: mode),
    );
  }

  void _openWorkingOnSelectionPractice(
    List<String> itemIds,
    PracticeModeV1 mode,
  ) {
    if (itemIds.isEmpty) return;
    _openPracticeSession(
      widget.controller.buildSessionForWorkingOnSelection(
        itemIds,
        practiceMode: mode,
      ),
    );
  }

  void _openWarmupPractice() {
    _openPracticeSession(widget.controller.buildWarmupSession());
  }

  void _repeatPreviousSession(PracticeSessionLogV1 session) {
    final PracticeSessionSetupV1? setup = widget.controller
        .buildSessionFromSessionOrNull(session);
    if (setup == null) return;
    _openPracticeSession(setup);
  }

  void _selectTab(int index) {
    _shellNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    setState(() => _currentIndex = index);
  }

  void _openPracticeSession(PracticeSessionSetupV1 setup) {
    final Route<void> route = MaterialPageRoute<void>(
      builder: (_) =>
          PracticeSessionScreen(controller: widget.controller, setup: setup),
      fullscreenDialog: AppViewport.isTablet(context),
    );
    if (AppViewport.isTablet(context)) {
      Navigator.of(context).push(route);
    } else {
      _shellNavigatorKey.currentState?.push(route);
    }
  }

  void _openItemDetail(String itemId) {
    _shellNavigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => ItemDetailScreen(
          controller: widget.controller,
          itemId: itemId,
          onPracticeItemInMode: _openPracticeItemInMode,
          onOpenInMatrix: _openMatrixForItemEdit,
        ),
      ),
    );
  }

  Future<List<String>?> _openMatrixForItemEdit(String itemId) {
    final List<String> selectedItemIds = widget.controller
        .matrixSelectionItemIdsForItem(itemId);
    return _shellNavigatorKey.currentState!.push<List<String>>(
      MaterialPageRoute<List<String>>(
        builder: (BuildContext routeContext) => Scaffold(
          appBar: AppBar(title: const Text('Triad Matrix')),
          body: MatrixScreen(
            controller: widget.controller,
            request: MatrixScreenRequest(
              version: 1,
              lane: null,
              filters: const <TriadMatrixFilterV1>{},
              selectedItemIds: selectedItemIds,
              editingItemId: itemId,
            ),
            onOpenItem: _openItemDetail,
            onPracticeItem: _openPracticeItem,
            onPracticeItemInMode: _openPracticeItemInMode,
            onBuildComboFromItems: _openCombinationBuilderFromItems,
            onFinishEditing: (List<String> itemIds) {
              Navigator.of(routeContext).pop(itemIds);
            },
          ),
        ),
      ),
    );
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
