import 'dart:io';

import 'package:better_tracking/active_workout.dart';
import 'package:better_tracking/main.dart';
import 'package:better_tracking/models.dart';
import 'package:better_tracking/rest_alerts.dart';
import 'package:better_tracking/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<AppStore> _memoryStore() async {
  final store = AppStore(storageFile: () async => null);
  await store.load();
  return store;
}

Widget _app(AppStore store) {
  final session = SessionController(store, draftFile: () async => null);
  addTearDown(session.dispose);
  return BetterTrackingApp(store: store, session: session);
}

class _FakeAlerts extends RestAlerts {
  final events = <String>[];

  @override
  Future<void> schedule(DateTime endsAt, String nextUp) async => events.add('schedule:$nextUp');

  @override
  Future<void> fireNow(String nextUp) async => events.add('fire:$nextUp');

  @override
  Future<void> cancel() async => events.add('cancel');
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

  Session benchSession(AppStore store, String workoutId, DateTime date, double weight) {
    final bench = store.exercises.firstWhere((e) => e.name == 'Bench Press');
    return Session(
      id: newId(),
      workoutId: workoutId,
      workoutName: 'Push',
      date: date,
      durationSeconds: 3600,
      logs: [
        ExerciseLog(exerciseId: bench.id, sets: [
          LoggedSet(weight: weight, reps: 8, rir: 2),
          LoggedSet(weight: weight, reps: 7, rir: 1),
        ]),
      ],
    );
  }

  testWidgets('template grid opens a preview and starts a session', (tester) async {
    final store = await _memoryStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.text('Start an Empty Workout'), findsOneWidget);
    expect(find.text('My Templates (3)'), findsOneWidget);
    expect(find.text('Never done'), findsNothing);
    await tester.scrollUntilVisible(find.text('Example Templates (5)'), 200);
    await tester.scrollUntilVisible(find.text('Push'), -200);

    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Never'), findsNothing);
    expect(find.textContaining('Last Performed'), findsNothing);
    expect(find.text('4 × Bench Press'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Start Workout'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('PREVIOUS'), findsWidgets);
    expect(find.text('Finish'), findsOneWidget);
  });

  testWidgets('example template can be added to My Templates', (tester) async {
    final store = await _memoryStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Arms & Shoulders'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lower Body'));
    await tester.pumpAndSettle();
    expect(find.text('Example template'), findsOneWidget);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(store.workouts.map((w) => w.name), contains('Lower Body'));
  });

  testWidgets('empty workout can be saved as a template', (tester) async {
    final store = await _memoryStore();
    store.addSession(benchSession(store, 'old', DateTime(2026, 10, 1), 85));
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start an Empty Workout'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.text('Add exercise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bench Press'));
    await tester.pump();
    await tester.tap(find.text('Add (1)'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('85×8'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.check_circle_outline).first);
    await tester.pump();
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.text('Finish').last);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('Save as template?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'My Bench Day');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    final template = store.workouts.firstWhere((w) => w.name == 'My Bench Day');
    expect(template.exercises.single.sets.single.weight, 85);
    expect(find.text('My Templates (4)'), findsOneWidget);
  });

  testWidgets('phone-sized screens render without overflow', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = await _memoryStore();
    final push = store.workouts.firstWhere((w) => w.name == 'Push');
    for (var week = 0; week < 6; week++) {
      store.addSession(benchSession(
          store, push.id, DateTime(2026, 9, 1).add(Duration(days: week * 7)), 80.0 + week * 2.5));
    }

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    expect(find.text('Oct 6, 2026'), findsOneWidget);

    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();
    expect(find.text('Last Performed: 6 October 2026'), findsOneWidget);
    await tester.tap(find.byTooltip('About Bench Press'));
    await tester.pumpAndSettle();
    expect(find.text('Personal Records'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Start Workout'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('92.5×8'), findsOneWidget);
    await tester.tap(find.text('Exercises'));
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

  testWidgets('workout keeps running across tabs and can be resumed', (tester) async {
    final store = await _memoryStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Start Workout'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('PREVIOUS'), findsWidgets);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Resume'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('PREVIOUS'), findsWidgets);

    await tester.tap(find.text('Workout'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.text('Pull'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Start Workout'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Workout in progress'), findsOneWidget);
    await tester.tap(find.text('Resume').last);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Bench Press'), findsOneWidget);
  });

  testWidgets('workout in progress is restored after restart', (tester) async {
    final dir = await tester.runAsync(() => Directory.systemTemp.createTemp('bt_draft'));
    final file = File('${dir!.path}/active_workout.json');
    final store = await _memoryStore();
    final push = store.workouts.firstWhere((w) => w.name == 'Push');

    final first = SessionController(store, draftFile: () async => file);
    await tester.runAsync(() async {
      await first.restore();
      first.start(push);
      final set = first.current!.entries.first.sets.first;
      set.weight.text = '100';
      set.reps.text = '6';
      expect(first.toggleDone(set), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      first.dispose();
    });

    final second = SessionController(store, draftFile: () async => file);
    await tester.runAsync(second.restore);
    expect(second.isActive, isTrue);
    expect(second.current!.name, 'Push');
    final restored = second.current!.entries.first.sets.first;
    expect(restored.done, isTrue);
    expect(restored.weight.text, '100');
    expect(restored.reps.text, '6');
    expect(second.restRemaining, greaterThan(0));

    await tester.runAsync(() async {
      final session = second.finish();
      expect(session!.logs.single.sets.single.weight, 100);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(await file.exists(), isFalse);
      second.dispose();
    });
    await tester.runAsync(() => dir.delete(recursive: true));
  });

  testWidgets('rest timer uses the exercise rest, counts down and alerts', (tester) async {
    final store = await _memoryStore();
    final push = store.workouts.firstWhere((w) => w.name == 'Push');
    push.exercises.first.restSeconds = 3;
    push.exercises[1].restSeconds = 0;
    final alerts = _FakeAlerts();
    var clock = DateTime(2026, 11, 13, 10);
    final session = SessionController(store,
        draftFile: () async => null, alerts: alerts, now: () => clock);
    addTearDown(session.dispose);
    await tester.pumpWidget(BetterTrackingApp(store: store, session: session));
    await tester.pumpAndSettle();

    session.start(push);
    final bench = session.current!.entries.first;
    bench.sets.first
      ..weight.text = '80'
      ..reps.text = '8';
    expect(session.toggleDone(bench.sets.first), isTrue);
    expect(session.restRemaining, 3);
    expect(alerts.events, ['schedule:Bench Press · set 2']);

    clock = clock.add(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    expect(session.restRemaining, 0);
    expect(alerts.events.last, 'fire:Bench Press · set 2');

    final incline = session.current!.entries[1];
    incline.sets.first
      ..weight.text = '60'
      ..reps.text = '10';
    session.toggleDone(incline.sets.first);
    expect(session.restRemaining, 0, reason: 'rest is off for this exercise');

    session.setRest(incline, 90);
    session.toggleDone(incline.sets[1]..weight.text = '60'..reps.text = '10');
    expect(session.restRemaining, 90);
    session.skipRest();
    expect(session.restRemaining, 0);
    expect(alerts.events.last, 'cancel');
    session.discard();
    await tester.pump();
  });

  testWidgets('rest chip changes the template rest time', (tester) async {
    final store = await _memoryStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rest 2:00').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1:30'));
    await tester.pumpAndSettle();
    expect(find.text('Rest 1:30'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.workouts.firstWhere((w) => w.name == 'Push').exercises.first.restSeconds, 90);
  });
}
