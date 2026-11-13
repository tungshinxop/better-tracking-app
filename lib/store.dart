import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

typedef StorageFileProvider = Future<File?> Function();

Future<File?> defaultStorageFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/better_tracking_data.json');
}

class AppStore extends ChangeNotifier {
  AppStore({StorageFileProvider? storageFile})
      : _storageFile = storageFile ?? defaultStorageFile;

  final StorageFileProvider _storageFile;
  File? _file;
  Future<void> _pendingWrite = Future.value();

  final List<Exercise> exercises = [];
  final List<Workout> workouts = [];
  final List<Session> sessions = [];
  bool loaded = false;

  Future<void> load() async {
    _file = await _storageFile();
    final file = _file;
    if (file != null && await file.exists()) {
      try {
        _readJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
      } catch (error) {
        debugPrint('Failed to read saved data, keeping a backup: $error');
        await file.copy('${file.path}.corrupt');
        _seed();
      }
    } else {
      _seed();
      _save();
    }
    loaded = true;
    notifyListeners();
  }

  void _readJson(Map<String, dynamic> json) {
    exercises
      ..clear()
      ..addAll((json['exercises'] as List? ?? const [])
          .map((e) => Exercise.fromJson(Map<String, dynamic>.from(e))));
    workouts
      ..clear()
      ..addAll((json['workouts'] as List? ?? const [])
          .map((w) => Workout.fromJson(Map<String, dynamic>.from(w))));
    sessions
      ..clear()
      ..addAll((json['sessions'] as List? ?? const [])
          .map((s) => Session.fromJson(Map<String, dynamic>.from(s))));
    sessions.sort((a, b) => b.date.compareTo(a.date));
  }

  Map<String, dynamic> _toJson() => {
        'version': 1,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'workouts': workouts.map((w) => w.toJson()).toList(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };

  void _save() {
    final file = _file;
    if (file == null) return;
    final contents = jsonEncode(_toJson());
    _pendingWrite = _pendingWrite.then((_) async {
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(contents, flush: true);
      await temp.rename(file.path);
    }).catchError((Object error) {
      debugPrint('Failed to save data: $error');
    });
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  Exercise? exerciseById(String id) {
    for (final e in exercises) {
      if (e.id == id) return e;
    }
    return null;
  }

  Workout? workoutById(String id) {
    for (final w in workouts) {
      if (w.id == id) return w;
    }
    return null;
  }

  void upsertExercise(Exercise exercise) {
    final index = exercises.indexWhere((e) => e.id == exercise.id);
    if (index >= 0) {
      exercises[index] = exercise;
    } else {
      exercises.add(exercise);
    }
    exercises.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _changed();
  }

  void deleteExercise(String id) {
    exercises.removeWhere((e) => e.id == id);
    for (final w in workouts) {
      w.exercises.removeWhere((we) => we.exerciseId == id);
    }
    _changed();
  }

  void upsertWorkout(Workout workout) {
    final index = workouts.indexWhere((w) => w.id == workout.id);
    if (index >= 0) {
      workouts[index] = workout;
    } else {
      workouts.add(workout);
    }
    _changed();
  }

  void deleteWorkout(String id) {
    workouts.removeWhere((w) => w.id == id);
    _changed();
  }

  void addSession(Session session) {
    sessions.insert(0, session);
    sessions.sort((a, b) => b.date.compareTo(a.date));
    _changed();
  }

  void deleteSession(String id) {
    sessions.removeWhere((s) => s.id == id);
    _changed();
  }

  /// Oldest first, only sessions where the exercise has logged sets.
  List<ExerciseHistoryEntry> historyFor(String exerciseId) {
    final entries = <ExerciseHistoryEntry>[];
    for (final session in sessions) {
      final sets = session.logs
          .where((l) => l.exerciseId == exerciseId)
          .expand((l) => l.sets)
          .toList();
      if (sets.isNotEmpty) entries.add(ExerciseHistoryEntry(session, sets));
    }
    entries.sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }

  List<LoggedSet> lastSetsFor(String exerciseId) {
    final history = historyFor(exerciseId);
    return history.isEmpty ? const [] : history.last.sets;
  }

  List<Workout> workoutsUsing(String exerciseId) => workouts
      .where((w) => w.exercises.any((e) => e.exerciseId == exerciseId))
      .toList();

  void _seed() {
    exercises.clear();
    workouts.clear();
    sessions.clear();

    Exercise add(String name, List<String> muscles) {
      final e = Exercise(id: newId(), name: name, muscles: muscles);
      exercises.add(e);
      return e;
    }

    final bench = add('Bench Press', ['Chest', 'Triceps', 'Front Delts']);
    final closeGrip = add('Close Grip Bench Press', ['Chest', 'Triceps', 'Front Delts']);
    final incline = add('Incline Dumbbell Press', ['Chest', 'Front Delts']);
    final ohp = add('Overhead Press', ['Front Delts', 'Side Delts', 'Triceps']);
    final lateral = add('Lateral Raise', ['Side Delts']);
    final pushdown = add('Triceps Pushdown', ['Triceps']);
    final chinUp = add('Weighted Chin-Up', ['Lats', 'Biceps']);
    final row = add('Barbell Row', ['Upper Back', 'Lats', 'Rear Delts']);
    final curl = add('Dumbbell Curl', ['Biceps', 'Forearms']);
    final squat = add('Back Squat', ['Quads', 'Glutes']);
    final rdl = add('Romanian Deadlift', ['Hamstrings', 'Glutes', 'Lower Back']);
    final legPress = add('Leg Press', ['Quads', 'Glutes']);
    final legCurl = add('Leg Curl', ['Hamstrings']);
    final calf = add('Standing Calf Raise', ['Calves']);
    add('Deadlift', ['Hamstrings', 'Glutes', 'Lower Back', 'Upper Back']);
    add('Cable Crunch', ['Abs']);
    exercises.sort((a, b) => a.name.compareTo(b.name));

    List<PlannedSet> sets(int count, int min, int max, List<int> rir) =>
        List.generate(count, (i) => PlannedSet(repsMin: min, repsMax: max, rir: rir[i]));

    workouts.addAll([
      Workout(id: newId(), name: 'Push', exercises: [
        WorkoutExercise(exerciseId: bench.id, sets: sets(4, 6, 8, [3, 2, 2, 1])),
        WorkoutExercise(exerciseId: incline.id, sets: sets(3, 8, 10, [2, 2, 1])),
        WorkoutExercise(exerciseId: ohp.id, sets: sets(3, 8, 10, [2, 2, 1])),
        WorkoutExercise(exerciseId: lateral.id, sets: sets(3, 12, 15, [2, 1, 0])),
        WorkoutExercise(exerciseId: pushdown.id, sets: sets(3, 10, 12, [2, 1, 0])),
      ]),
      Workout(id: newId(), name: 'Pull', exercises: [
        WorkoutExercise(exerciseId: chinUp.id, sets: sets(4, 6, 8, [2, 2, 1, 1])),
        WorkoutExercise(exerciseId: row.id, sets: sets(4, 8, 10, [3, 2, 2, 1])),
        WorkoutExercise(exerciseId: closeGrip.id, sets: sets(3, 11, 13, [3, 2, 1])),
        WorkoutExercise(exerciseId: curl.id, sets: sets(3, 10, 12, [2, 1, 0])),
      ]),
      Workout(id: newId(), name: 'Legs', exercises: [
        WorkoutExercise(exerciseId: squat.id, sets: sets(4, 5, 7, [3, 2, 2, 1])),
        WorkoutExercise(exerciseId: rdl.id, sets: sets(3, 8, 10, [2, 2, 1])),
        WorkoutExercise(exerciseId: legPress.id, sets: sets(3, 10, 12, [2, 1, 1])),
        WorkoutExercise(exerciseId: legCurl.id, sets: sets(3, 10, 12, [2, 1, 0])),
        WorkoutExercise(exerciseId: calf.id, sets: sets(4, 12, 15, [2, 1, 1, 0])),
      ]),
    ]);
  }
}
