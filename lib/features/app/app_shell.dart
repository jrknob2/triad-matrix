import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../state/app_controller.dart';
import '../hardware/hardware_status_header.dart';
import '../library/pattern_screen.dart';
import '../matrix/matrix_screen.dart';
import '../practice/practice_session_screen.dart';
import '../progress/practice_insights_screen.dart';
import '../settings/app_settings_screen.dart';
import '../settings/hardware_midi_settings_screen.dart';
import '../toolkit/toolkit_screen.dart';
import '../today/today_screen.dart';
import 'startup_splash_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final Future<AppController> _controllerFuture = AppController.create();
  int _selectedIndex = 0;

  void _selectDestination(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppController>(
      future: _controllerFuture,
      builder: (BuildContext context, AsyncSnapshot<AppController> snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Coach')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load app settings: ${snapshot.error}'),
              ),
            ),
          );
        }
        final AppController? controller = snapshot.data;
        if (controller == null) {
          return const StartupSplashScreen();
        }
        return _DrumAppNavigationShell(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _selectDestination,
          body: _destinationFor(controller),
        );
      },
    );
  }

  Widget _destinationFor(AppController controller) {
    return switch (_selectedIndex) {
      0 => TodayScreen(
        controller: controller,
        onOpenExplore: () => _selectDestination(1),
        onOpenInsights: () => _selectDestination(2),
        onOpenSettings: () => _selectDestination(4),
        onOpenDevices: _openDevices,
      ),
      1 => const ExploreLessonsScreen(),
      2 => const PracticeInsightsScreen(),
      3 => FocusScreen(
        controller: controller,
        onOpenItem: (String itemId) => _openPattern(controller, itemId),
        onPracticeItemInMode: (String itemId, PracticeModeV1 mode) =>
            _practiceItemInMode(controller, itemId, mode),
        onCreateNewItem: () => _createNewPattern(controller),
        onOpenMatrix: () => _openMatrix(controller),
      ),
      4 => AppSettingsScreen(controller: controller),
      _ => const SizedBox.shrink(),
    };
  }

  void _openDevices() {
    unawaited(showHardwareConnectionDialog(context));
  }

  void _openPattern(AppController controller, String itemId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            PatternScreen(controller: controller, itemId: itemId),
      ),
    );
  }

  void _createNewPattern(AppController controller) {
    final String itemId = controller.createBlankDraftPracticeItem();
    _openPattern(controller, itemId);
  }

  void _practiceItemInMode(
    AppController controller,
    String itemId,
    PracticeModeV1 mode,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => PracticeSessionScreen(
          controller: controller,
          setup: controller.buildSessionForItem(itemId, practiceMode: mode),
        ),
      ),
    );
  }

  void _openMatrix(AppController controller) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MatrixScreen(
          controller: controller,
          request: null,
          onOpenItem: (String itemId) => _openPattern(controller, itemId),
          onPreviewSelection:
              (List<String> itemIds, PracticeModeV1 practiceMode) {
                if (itemIds.isEmpty) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => PracticeSessionScreen(
                      controller: controller,
                      setup: controller.buildMatrixPreviewSession(
                        itemIds,
                        practiceMode: practiceMode,
                      ),
                    ),
                  ),
                );
              },
        ),
      ),
    );
  }
}

class _DrumAppNavigationShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;

  const _DrumAppNavigationShell({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
  });

  static const List<NavigationDestination> _bottomDestinations =
      <NavigationDestination>[
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore_rounded),
          label: 'Explore',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart_rounded),
          label: 'Insights',
        ),
        NavigationDestination(
          icon: Icon(Icons.edit_outlined),
          selectedIcon: Icon(Icons.edit_rounded),
          label: 'Author',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: 'Settings',
        ),
      ];

  static const List<NavigationRailDestination> _railDestinations =
      <NavigationRailDestination>[
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore_rounded),
          label: Text('Explore'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart_rounded),
          label: Text('Insights'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.edit_outlined),
          selectedIcon: Icon(Icons.edit_rounded),
          label: Text('Author'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: Text('Settings'),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth >= 860) {
          return Scaffold(
            body: Row(
              children: <Widget>[
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.fromLTRB(12, 24, 12, 20),
                    child: _BrandMark(),
                  ),
                  destinations: _railDestinations,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _ShellContentFrame(child: body)),
              ],
            ),
          );
        }
        return Scaffold(
          body: _ShellContentFrame(child: body),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: _bottomDestinations,
          ),
        );
      },
    );
  }
}

class _ShellContentFrame extends StatelessWidget {
  final Widget child;

  const _ShellContentFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return HardwareStatusHeaderOverlay(child: child);
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                1.24,
                0,
                0,
                0,
                18,
                0,
                1.24,
                0,
                0,
                18,
                0,
                0,
                1.24,
                0,
                18,
                0,
                0,
                0,
                1,
                0,
              ]),
              child: Image.asset(
                'assets/icons/app_icon_splash.png',
                width: 78,
                height: 78,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'DRUMCABULARY',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
