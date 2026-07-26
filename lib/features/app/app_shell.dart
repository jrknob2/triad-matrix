import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../state/app_controller.dart';
import 'drumcabulary_theme.dart';
import '../coach/lesson_detail_screen.dart';
import '../coach/lesson_plan.dart';
import '../coach/lesson_plan_loader.dart';
import '../coach/lesson_progress.dart';
import '../hardware/hardware_capabilities.dart';
import '../hardware/hardware_status_header.dart';
import '../library/pattern_screen.dart';
import '../matrix/matrix_screen.dart';
import '../practice/practice_session_screen.dart';
import '../progress/practice_insights_screen.dart';
import '../settings/app_settings_screen.dart';
import '../settings/hardware_midi_settings_screen.dart';
import '../toolkit/toolkit_screen.dart';
import '../today/today_screen.dart';

class AppShell extends StatefulWidget {
  final AppController controller;

  const AppShell({super.key, required this.controller});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  String? _initialExploreSkillId;

  void _selectDestination(int index) {
    setState(() {
      _selectedIndex = index;
      _initialExploreSkillId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final _ShellDestination destination = _destinationFor(widget.controller);
    return _DrumAppNavigationShell(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _selectDestination,
      header: destination.header,
      body: destination.body,
    );
  }

  _ShellDestination _destinationFor(AppController controller) {
    return switch (_selectedIndex) {
      0 => _ShellDestination(
        header: _ShellHeaderContent(
          title: _greeting(controller.profile.studentName),
          subtitle: 'Ready when you are.',
        ),
        body: TodayScreen(
          controller: controller,
          onOpenExplore: () => _selectDestination(1),
          onOpenInsights: () => _selectDestination(2),
          onOpenSettings: () => _selectDestination(4),
          onOpenDevices: _openDevices,
        ),
      ),
      1 => _ShellDestination(
        header: const _ShellHeaderContent(
          title: 'What are you working on today?',
          subtitle:
              'Search lessons and exercises or filter by what matters to you.',
        ),
        body: ExploreLessonsScreen(initialSkillId: _initialExploreSkillId),
      ),
      2 => _ShellDestination(
        header: const _ShellHeaderContent(
          title: 'Practice Insights',
          subtitle: 'Practice time and completion by skill.',
        ),
        body: PracticeInsightsScreen(
          onOpenSkill: _openSkillInExplore,
          onOpenLesson: (String lessonId) =>
              unawaited(_openLessonFromInsights(lessonId)),
          onOpenExercise: (String lessonId, String exerciseId) => unawaited(
            _openLessonFromInsights(lessonId, initialExerciseId: exerciseId),
          ),
        ),
      ),
      3 => _ShellDestination(
        header: const _ShellHeaderContent(
          title: 'Author',
          subtitle: 'Capture MIDI patterns and manage practice material.',
        ),
        body: FocusScreen(
          controller: controller,
          onOpenItem: (String itemId) => _openPattern(controller, itemId),
          onPracticeItemInMode: (String itemId, PracticeModeV1 mode) =>
              _practiceItemInMode(controller, itemId, mode),
          onCreateNewItem: () => _createNewPattern(controller),
          onOpenMatrix: () => _openMatrix(controller),
        ),
      ),
      4 => _ShellDestination(
        header: const _ShellHeaderContent(
          title: 'Settings',
          subtitle: 'Preferences, appearance, and hardware setup.',
        ),
        body: AppSettingsScreen(controller: controller),
      ),
      _ => const _ShellDestination(
        header: _ShellHeaderContent(title: '', subtitle: ''),
        body: SizedBox.shrink(),
      ),
    };
  }

  void _openDevices() {
    unawaited(showHardwareConnectionDialog(context));
  }

  void _openSkillInExplore(String skillId) {
    setState(() {
      _initialExploreSkillId = skillId;
      _selectedIndex = 1;
    });
  }

  Future<void> _openLessonFromInsights(
    String lessonId, {
    String? initialExerciseId,
  }) async {
    final LessonContentLibrary library = await LessonPlanLoader.loadContent();
    final Lesson? lesson = library.lessonsById[lessonId];
    if (lesson == null || !mounted) return;

    final LessonProgressService progressService = LessonProgressService(
      const FileLessonProgressStore(),
    );
    await progressService.load();
    await progressService.openLesson(lesson.id);
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => LessonDetailScreen(
          lesson: lesson,
          initialExerciseId: initialExerciseId,
          progressService: progressService,
        ),
      ),
    );
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

class _ShellDestination {
  final _ShellHeaderContent header;
  final Widget body;

  const _ShellDestination({required this.header, required this.body});
}

class _ShellHeaderContent {
  final String title;
  final String subtitle;

  const _ShellHeaderContent({required this.title, required this.subtitle});
}

class _DrumAppNavigationShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final _ShellHeaderContent header;
  final Widget body;

  const _DrumAppNavigationShell({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.header,
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
                Expanded(
                  child: _ShellContentFrame(header: header, child: body),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          body: _ShellContentFrame(header: header, child: body),
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
  final _ShellHeaderContent header;
  final Widget child;

  const _ShellContentFrame({required this.header, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: DrumcabularyTheme.edgeBackground,
      child: Column(
        children: <Widget>[
          SafeArea(bottom: false, child: _ShellHeader(content: header)),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ShellHeader extends StatelessWidget {
  final _ShellHeaderContent content;

  const _ShellHeader({required this.content});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              content.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: DrumcabularyTheme.edgeTextPrimary,
                fontWeight: FontWeight.w700,
                height: 1.05,
              ),
            ),
            if (content.subtitle.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                content.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: DrumcabularyTheme.edgeTextSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ],
        );

        final Widget? hardwareControls =
            HardwareCapabilities.supportsDesktopHardware
            ? const HardwareStatusHeaderControls()
            : null;
        final bool compact = constraints.maxWidth < 720;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    titleBlock,
                    if (hardwareControls != null) ...<Widget>[
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: hardwareControls,
                      ),
                    ],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(child: titleBlock),
                    if (hardwareControls != null) ...<Widget>[
                      const SizedBox(width: 24),
                      Flexible(
                        flex: 0,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: hardwareControls,
                        ),
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

String _greeting(String studentName) {
  final int hour = DateTime.now().hour;
  final String period = hour < 12
      ? 'Good Morning'
      : hour < 18
      ? 'Good Afternoon'
      : 'Good Evening';
  final String name = studentName.trim();
  return name.isEmpty ? period : '$period $name';
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
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
