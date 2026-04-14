import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traid_trainer/core/practice/practice_domain_v1.dart';
import 'package:traid_trainer/features/practice/session_summary_screen.dart';
import 'package:traid_trainer/state/app_controller.dart';

import 'helpers/fake_app_state_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Play It Again returns a fresh practice setup', (
    WidgetTester tester,
  ) async {
    final FakeAppStateStore store = FakeAppStateStore();
    final AppController controller = await AppController.createForTesting(
      store,
    );
    final String itemId = controller.recommendedStartingTriadItemIds.first;
    final PracticeSessionSetupV1 setup = controller.buildSessionForItem(
      itemId,
      bpm: 92,
    );
    final PracticeSessionLogV1 session = controller.completeSession(
      setup,
      const Duration(minutes: 5),
      practicedItemIds: <String>[itemId],
      endingBpmByItemId: <String, int>{itemId: 138},
      selfReportControl: SelfReportControlV1.high,
      selfReportTension: SelfReportTensionV1.none,
    );

    late Future<PracticeSessionSetupV1?> resultFuture;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    resultFuture = Navigator.of(context)
                        .push<PracticeSessionSetupV1>(
                          MaterialPageRoute<PracticeSessionSetupV1>(
                            builder: (_) => SessionSummaryScreen(
                              controller: controller,
                              sessionId: session.id,
                            ),
                          ),
                        );
                  },
                  child: const Text('Open Summary'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open Summary'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Play It Again'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Play It Again'), findsOneWidget);

    await tester.tap(find.text('Play It Again'));
    await tester.pumpAndSettle();

    final PracticeSessionSetupV1? replaySetup = await resultFuture;
    expect(replaySetup, isNotNull);
    expect(replaySetup!.practiceItemIds, <String>[itemId]);
    expect(replaySetup.practiceMode, session.practiceMode);
    expect(replaySetup.bpm, 138);
  });
}
