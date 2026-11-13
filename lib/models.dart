import 'dart:math';

final _random = Random();

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_random.nextInt(1 << 32).toRadixString(36)}';

const List<String> kMuscleGroups = [
  'Chest',
  'Front Delts',
  'Side Delts',
  'Rear Delts',
  'Triceps',
  'Biceps',
  'Forearms',
  'Lats',
  'Upper Back',
  'Lower Back',
  'Abs',
  'Glutes',
  'Quads',
  'Hamstrings',
  'Calves',
];

class Exercise {
  Exercise({
    required this.id,
    required this.name,
    List<String>? muscles,
    this.notes = '',
  }) : muscles = muscles ?? [];

  final String id;
  String name;
  List<String> muscles;
  String notes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'muscles': muscles,
        'notes': notes,
      };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: json['id'] as String,
        name: json['name'] as String,
        muscles: List<String>.from(json['muscles'] as List? ?? const []),
        notes: json['notes'] as String? ?? '',
      );
}

class PlannedSet {
  PlannedSet({this.repsMin = 8, this.repsMax = 12, this.rir = 2, this.weight});

  int repsMin;
  int repsMax;
  int rir;
  double? weight;

  String get repsLabel =>
      repsMin == repsMax ? '$repsMin reps' : '$repsMin–$repsMax reps';

  PlannedSet copy() =>
      PlannedSet(repsMin: repsMin, repsMax: repsMax, rir: rir, weight: weight);

  Map<String, dynamic> toJson() => {
        'repsMin': repsMin,
        'repsMax': repsMax,
        'rir': rir,
        'weight': weight,
      };

  factory PlannedSet.fromJson(Map<String, dynamic> json) => PlannedSet(
        repsMin: json['repsMin'] as int? ?? 8,
        repsMax: json['repsMax'] as int? ?? 12,
        rir: json['rir'] as int? ?? 2,
        weight: (json['weight'] as num?)?.toDouble(),
      );
}

class WorkoutExercise {
  WorkoutExercise({required this.exerciseId, List<PlannedSet>? sets})
      : sets = sets ?? [PlannedSet(), PlannedSet(), PlannedSet()];

  final String exerciseId;
  List<PlannedSet> sets;

  WorkoutExercise copy() => WorkoutExercise(
      exerciseId: exerciseId, sets: sets.map((s) => s.copy()).toList());

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) =>
      WorkoutExercise(
        exerciseId: json['exerciseId'] as String,
        sets: (json['sets'] as List? ?? const [])
            .map((s) => PlannedSet.fromJson(Map<String, dynamic>.from(s)))
            .toList(),
      );
}

class Workout {
  Workout({required this.id, required this.name, List<WorkoutExercise>? exercises})
      : exercises = exercises ?? [];

  final String id;
  String name;
  List<WorkoutExercise> exercises;

  int get totalSets => exercises.fold(0, (sum, e) => sum + e.sets.length);

  Workout copy() => Workout(
      id: id, name: name, exercises: exercises.map((e) => e.copy()).toList());

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory Workout.fromJson(Map<String, dynamic> json) => Workout(
        id: json['id'] as String,
        name: json['name'] as String,
        exercises: (json['exercises'] as List? ?? const [])
            .map((e) => WorkoutExercise.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class LoggedSet {
  LoggedSet({required this.weight, required this.reps, required this.rir});

  final double weight;
  final int reps;
  final int rir;

  double get volume => weight * reps;

  /// Epley estimate, counting reps in reserve as reps the lifter could still do.
  double get estimatedOneRepMax {
    final repsToFailure = reps + rir;
    if (repsToFailure <= 1) return weight;
    return weight * (1 + repsToFailure / 30);
  }

  Map<String, dynamic> toJson() => {'weight': weight, 'reps': reps, 'rir': rir};

  factory LoggedSet.fromJson(Map<String, dynamic> json) => LoggedSet(
        weight: (json['weight'] as num).toDouble(),
        reps: json['reps'] as int,
        rir: json['rir'] as int? ?? 0,
      );
}

class ExerciseLog {
  ExerciseLog({required this.exerciseId, required this.sets});

  final String exerciseId;
  final List<LoggedSet> sets;

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory ExerciseLog.fromJson(Map<String, dynamic> json) => ExerciseLog(
        exerciseId: json['exerciseId'] as String,
        sets: (json['sets'] as List? ?? const [])
            .map((s) => LoggedSet.fromJson(Map<String, dynamic>.from(s)))
            .toList(),
      );
}

class Session {
  Session({
    required this.id,
    required this.workoutId,
    required this.workoutName,
    required this.date,
    required this.durationSeconds,
    required this.logs,
  });

  final String id;
  final String workoutId;
  final String workoutName;
  final DateTime date;
  final int durationSeconds;
  final List<ExerciseLog> logs;

  int get totalSets => logs.fold(0, (sum, l) => sum + l.sets.length);

  double get totalVolume => logs.fold(
      0.0, (sum, l) => sum + l.sets.fold(0.0, (s, set) => s + set.volume));

  Map<String, dynamic> toJson() => {
        'id': id,
        'workoutId': workoutId,
        'workoutName': workoutName,
        'date': date.toIso8601String(),
        'durationSeconds': durationSeconds,
        'logs': logs.map((l) => l.toJson()).toList(),
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        id: json['id'] as String,
        workoutId: json['workoutId'] as String,
        workoutName: json['workoutName'] as String? ?? 'Workout',
        date: DateTime.parse(json['date'] as String),
        durationSeconds: json['durationSeconds'] as int? ?? 0,
        logs: (json['logs'] as List? ?? const [])
            .map((l) => ExerciseLog.fromJson(Map<String, dynamic>.from(l)))
            .toList(),
      );
}

class ExerciseHistoryEntry {
  ExerciseHistoryEntry(this.session, this.sets);

  final Session session;
  final List<LoggedSet> sets;

  DateTime get date => session.date;

  double get topWeight => sets.map((s) => s.weight).fold(0.0, max);

  double get bestEstimatedOneRepMax =>
      sets.map((s) => s.estimatedOneRepMax).fold(0.0, max);

  double get volume => sets.fold(0.0, (sum, s) => sum + s.volume);

  int get bestReps => sets.map((s) => s.reps).fold(0, max);
}

String formatWeight(double weight) {
  if (weight == weight.roundToDouble()) return weight.toStringAsFixed(0);
  return weight.toStringAsFixed(weight * 10 == (weight * 10).roundToDouble() ? 1 : 2);
}

double? parseWeight(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));
