import 'package:better_tracking/main.dart';
import 'package:better_tracking/models.dart';
import 'package:better_tracking/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<AppStore> _memoryStore() async {
  final store = AppStore(storageFile: () async => null);
  await store.load();
  return store;
}

void main() {
  test('estimated 1RM counts RIR as reps in reserve', () {
    final set = LoggedSet(weight: 100, reps: 8, rir: 2);
    expect(set.estimatedOneRepMax, closeTo(133.33, 0.01));
  });

  test('history is ordered oldest first and only includes logged exercise', () async {
    final store = await _memoryStore();
    final bench = store.exercises.firstWhere((e) => e.name == 'Bench Press');
    final squat = store.exercises.firstWhere((e) => e.name == 'Back Squat');

    Session session(DateTime date, String exerciseId, double weight) => Session(
          id: newId(),
          workoutId: 'w',
          workoutName: 'Test',
          date: date,
          durationSeconds: 60,
          logs: [
            ExerciseLog(exerciseId: exerciseId, sets: [LoggedSet(weight: weight, reps: 5, rir: 1)]),
          ],
        );

    store.addSession(session(DateTime(2026, 1, 10), bench.id, 90));
    store.addSession(session(DateTime(2026, 1, 3), bench.id, 80));
    store.addSession(session(DateTime(2026, 1, 5), squat.id, 120));

    final history = store.historyFor(bench.id);
    expect(history.map((h) => h.topWeight), [80, 90]);
    expect(store.lastSetsFor(bench.id).single.weight, 90);
  });

  testWidgets('shows seeded workouts as tabs and opens a session', (tester) async {
    final store = await _memoryStore();
    await tester.pumpWidget(BetterTrackingApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Push'), findsOneWidget);
    expect(find.text('Pull'), findsOneWidget);
    expect(find.text('Target Muscles'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);

    await tester.tap(find.text('Start Push'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('PREVIOUS'), findsWidgets);
    expect(find.text('Finish'), findsOneWidget);
  });

  testWidgets('phone-sized screens render without overflow', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = await _memoryStore();
    final bench = store.exercises.firstWhere((e) => e.name == 'Bench Press');
    for (var week = 0; week < 6; week++) {
      store.addSession(Session(
        id: newId(),
        workoutId: store.workouts.first.id,
        workoutName: 'Push',
        date: DateTime(2026, 9, 1).add(Duration(days: week * 7)),
        durationSeconds: 3600,
        logs: [
          ExerciseLog(exerciseId: bench.id, sets: [
            LoggedSet(weight: 80.0 + week * 2.5, reps: 8, rir: 2),
            LoggedSet(weight: 80.0 + week * 2.5, reps: 7, rir: 1),
          ]),
        ],
      ));
    }

    await tester.pumpWidget(BetterTrackingApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start Push'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('80×8'), findsNothing);
    expect(find.text('92.5×8'), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bench Press').first);
    await tester.pumpAndSettle();
    expect(find.text('Personal Records'), findsOneWidget);
    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('Est. 1RM'), findsWidgets);
    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();
  });
}
