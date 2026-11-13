import 'models.dart';
import 'store.dart';

class ExampleExercise {
  const ExampleExercise(this.name, this.muscles, this.sets, this.repsMin, this.repsMax, this.rir);

  final String name;
  final List<String> muscles;
  final int sets;
  final int repsMin;
  final int repsMax;
  final List<int> rir;
}

class ExampleTemplate {
  const ExampleTemplate(this.id, this.name, this.exercises);

  final String id;
  final String name;
  final List<ExampleExercise> exercises;

  List<String> get exerciseNames => exercises.map((e) => e.name).toList();

  /// Builds a [Workout] whose exercises exist in the store's library,
  /// creating any that are missing. [keepId] keeps the example id so sessions
  /// started directly from an example can be tracked.
  Workout materialize(AppStore store, {bool keepId = true}) {
    return Workout(
      id: keepId ? id : newId(),
      name: name,
      exercises: [
        for (final e in exercises)
          WorkoutExercise(
            exerciseId: store.ensureExercise(e.name, e.muscles).id,
            sets: List.generate(
              e.sets,
              (i) => PlannedSet(
                repsMin: e.repsMin,
                repsMax: e.repsMax,
                rir: e.rir[i < e.rir.length ? i : e.rir.length - 1],
              ),
            ),
          ),
      ],
    );
  }
}

const kExampleTemplates = <ExampleTemplate>[
  ExampleTemplate('example-full-body-a', 'Full Body A', [
    ExampleExercise('Back Squat', ['Quads', 'Glutes'], 3, 5, 7, [3, 2, 1]),
    ExampleExercise('Bench Press', ['Chest', 'Triceps', 'Front Delts'], 3, 6, 8, [3, 2, 1]),
    ExampleExercise('Barbell Row', ['Upper Back', 'Lats', 'Rear Delts'], 3, 8, 10, [2, 2, 1]),
    ExampleExercise('Lateral Raise', ['Side Delts'], 2, 12, 15, [1, 0]),
  ]),
  ExampleTemplate('example-full-body-b', 'Full Body B', [
    ExampleExercise('Deadlift', ['Hamstrings', 'Glutes', 'Lower Back', 'Upper Back'], 3, 4, 6, [3, 2, 2]),
    ExampleExercise('Overhead Press', ['Front Delts', 'Side Delts', 'Triceps'], 3, 6, 8, [2, 2, 1]),
    ExampleExercise('Weighted Chin-Up', ['Lats', 'Biceps'], 3, 6, 8, [2, 1, 1]),
    ExampleExercise('Cable Crunch', ['Abs'], 3, 10, 15, [1, 1, 0]),
  ]),
  ExampleTemplate('example-upper', 'Upper Body', [
    ExampleExercise('Bench Press', ['Chest', 'Triceps', 'Front Delts'], 4, 6, 8, [3, 2, 2, 1]),
    ExampleExercise('Barbell Row', ['Upper Back', 'Lats', 'Rear Delts'], 4, 8, 10, [2, 2, 1, 1]),
    ExampleExercise('Incline Dumbbell Press', ['Chest', 'Front Delts'], 3, 8, 12, [2, 1, 1]),
    ExampleExercise('Weighted Chin-Up', ['Lats', 'Biceps'], 3, 6, 10, [2, 1, 1]),
    ExampleExercise('Triceps Pushdown', ['Triceps'], 2, 10, 15, [1, 0]),
    ExampleExercise('Dumbbell Curl', ['Biceps', 'Forearms'], 2, 10, 15, [1, 0]),
  ]),
  ExampleTemplate('example-lower', 'Lower Body', [
    ExampleExercise('Back Squat', ['Quads', 'Glutes'], 4, 5, 8, [3, 2, 2, 1]),
    ExampleExercise('Romanian Deadlift', ['Hamstrings', 'Glutes', 'Lower Back'], 3, 8, 10, [2, 2, 1]),
    ExampleExercise('Leg Press', ['Quads', 'Glutes'], 3, 10, 15, [2, 1, 1]),
    ExampleExercise('Leg Curl', ['Hamstrings'], 3, 10, 12, [1, 1, 0]),
    ExampleExercise('Standing Calf Raise', ['Calves'], 4, 10, 15, [1, 1, 0, 0]),
  ]),
  ExampleTemplate('example-arms-shoulders', 'Arms & Shoulders', [
    ExampleExercise('Overhead Press', ['Front Delts', 'Side Delts', 'Triceps'], 3, 6, 10, [2, 2, 1]),
    ExampleExercise('Lateral Raise', ['Side Delts'], 4, 12, 20, [2, 1, 1, 0]),
    ExampleExercise('Close Grip Bench Press', ['Chest', 'Triceps', 'Front Delts'], 3, 8, 10, [2, 2, 1]),
    ExampleExercise('Dumbbell Curl', ['Biceps', 'Forearms'], 3, 10, 12, [2, 1, 0]),
    ExampleExercise('Triceps Pushdown', ['Triceps'], 3, 10, 15, [1, 1, 0]),
  ]),
];

ExampleTemplate? exampleById(String id) {
  for (final e in kExampleTemplates) {
    if (e.id == id) return e;
  }
  return null;
}
