import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'models.dart';
import 'rest_alerts.dart';
import 'store.dart';

class ActiveSet {
  ActiveSet({this.planned, this.previous, String weight = '', String reps = '', String rir = '', this.done = false})
      : weight = TextEditingController(text: weight),
        reps = TextEditingController(text: reps),
        rir = TextEditingController(text: rir);

  final PlannedSet? planned;
  final LoggedSet? previous;
  final TextEditingController weight;
  final TextEditingController reps;
  final TextEditingController rir;
  bool done;

  String get repsHint {
    final p = planned;
    if (p == null) return previous == null ? '' : '${previous!.reps}';
    return p.repsMin == p.repsMax ? '${p.repsMin}' : '${p.repsMin}-${p.repsMax}';
  }

  String get weightHint => previous == null ? 'kg' : formatWeight(previous!.weight);

  String get rirHint => '${planned?.rir ?? previous?.rir ?? ''}';

  LoggedSet? toLogged() {
    final w = parseWeight(weight.text);
    final r = int.tryParse(reps.text.trim());
    if (w == null || r == null || r <= 0) return null;
    return LoggedSet(weight: w, reps: r, rir: int.tryParse(rir.text.trim()) ?? planned?.rir ?? 0);
  }

  /// Fills empty fields from the last session / plan so a set can be ticked in one tap.
  void fillFromHints() {
    if (weight.text.trim().isEmpty) {
      final w = previous?.weight ?? planned?.weight;
      if (w != null) weight.text = formatWeight(w);
    }
    if (reps.text.trim().isEmpty) {
      final r = previous?.reps ?? planned?.repsMax;
      if (r != null) reps.text = '$r';
    }
    if (rir.text.trim().isEmpty) {
      final r = planned?.rir ?? previous?.rir;
      if (r != null) rir.text = '$r';
    }
  }

  void addListener(VoidCallback listener) {
    weight.addListener(listener);
    reps.addListener(listener);
    rir.addListener(listener);
  }

  void dispose() {
    weight.dispose();
    reps.dispose();
    rir.dispose();
  }

  Map<String, dynamic> toJson() => {
        'planned': planned?.toJson(),
        'previous': previous?.toJson(),
        'weight': weight.text,
        'reps': reps.text,
        'rir': rir.text,
        'done': done,
      };

  factory ActiveSet.fromJson(Map<String, dynamic> json) => ActiveSet(
        planned: json['planned'] == null
            ? null
            : PlannedSet.fromJson(Map<String, dynamic>.from(json['planned'])),
        previous: json['previous'] == null
            ? null
            : LoggedSet.fromJson(Map<String, dynamic>.from(json['previous'])),
        weight: json['weight'] as String? ?? '',
        reps: json['reps'] as String? ?? '',
        rir: json['rir'] as String? ?? '',
        done: json['done'] as bool? ?? false,
      );
}

class ActiveExercise {
  ActiveExercise(this.exercise, this.sets, {this.restSeconds = kDefaultRestSeconds});

  final Exercise exercise;
  final List<ActiveSet> sets;

  /// Rest after each set; 0 means no rest timer.
  int restSeconds;
}

class ActiveWorkout {
  ActiveWorkout({
    required this.workoutId,
    required this.name,
    required this.startedAt,
    required this.entries,
  });

  final String workoutId;
  final String name;
  final DateTime startedAt;
  final List<ActiveExercise> entries;
  DateTime? restEndsAt;
  int restTotal = kDefaultRestSeconds;

  int get doneSets => entries.fold(0, (sum, e) => sum + e.sets.where((s) => s.done).length);

  int get totalSets => entries.fold(0, (sum, e) => sum + e.sets.length);
}

typedef DraftFileProvider = Future<File?> Function();

Future<File?> defaultDraftFile() async {
  final main = await defaultStorageFile();
  return main == null ? null : File('${main.parent.path}/active_workout.json');
}

/// Holds the workout in progress so it survives navigation and app restarts.
class SessionController extends ChangeNotifier {
  SessionController(this.store,
      {DraftFileProvider? draftFile, this.alerts = const RestAlerts(), this.now = DateTime.now})
      : _draftFileProvider = draftFile ?? defaultDraftFile;

  /// A rest that ended longer ago than this (app was suspended) was already
  /// announced by the scheduled notification, so it is cleared silently.
  static const _lateAlertGrace = Duration(seconds: 3);

  final AppStore store;
  final RestAlerts alerts;

  /// Injectable clock so tests can fast-forward the rest timer.
  final DateTime Function() now;
  final DraftFileProvider _draftFileProvider;
  File? _draftFile;
  Timer? _ticker;
  Timer? _saveDebounce;
  Future<void>? _pendingWrite;

  ActiveWorkout? current;

  bool get isActive => current != null;

  Duration get elapsed =>
      current == null ? Duration.zero : now().difference(current!.startedAt);

  int get restRemaining {
    final ends = current?.restEndsAt;
    if (ends == null) return 0;
    final left = ends.difference(now()).inMilliseconds;
    return left <= 0 ? 0 : (left / 1000).ceil();
  }

  Future<void> restore() async {
    _draftFile = await _draftFileProvider();
    final file = _draftFile;
    if (file == null || !await file.exists()) return;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final entries = <ActiveExercise>[];
      for (final raw in json['entries'] as List? ?? const []) {
        final map = Map<String, dynamic>.from(raw);
        final exercise = store.exerciseById(map['exerciseId'] as String);
        if (exercise == null) continue;
        entries.add(ActiveExercise(
          exercise,
          [
            for (final s in map['sets'] as List? ?? const [])
              ActiveSet.fromJson(Map<String, dynamic>.from(s)),
          ],
          restSeconds: map['restSeconds'] as int? ?? kDefaultRestSeconds,
        ));
      }
      final workout = ActiveWorkout(
        workoutId: json['workoutId'] as String? ?? '',
        name: json['name'] as String? ?? 'Workout',
        startedAt: DateTime.parse(json['startedAt'] as String),
        entries: entries,
      )
        ..restTotal = json['restTotal'] as int? ?? kDefaultRestSeconds
        ..restEndsAt = json['restEndsAt'] == null ? null : DateTime.parse(json['restEndsAt'] as String);
      _activate(workout, save: false);
    } catch (error) {
      debugPrint('Could not restore workout in progress: $error');
    }
  }

  void start(Workout workout) {
    _clear();
    final entries = <ActiveExercise>[];
    for (final plan in workout.exercises) {
      final exercise = store.exerciseById(plan.exerciseId);
      if (exercise == null) continue;
      final previous = store.lastSetsFor(exercise.id);
      entries.add(ActiveExercise(exercise, [
        for (var i = 0; i < plan.sets.length; i++)
          ActiveSet(
            planned: plan.sets[i],
            previous: i < previous.length ? previous[i] : null,
            weight: i < previous.length
                ? formatWeight(previous[i].weight)
                : (plan.sets[i].weight == null ? '' : formatWeight(plan.sets[i].weight!)),
            rir: '${plan.sets[i].rir}',
          ),
      ], restSeconds: plan.restSeconds));
    }
    _activate(ActiveWorkout(
      workoutId: workout.id,
      name: workout.name,
      startedAt: now(),
      entries: entries,
    ));
  }

  void _activate(ActiveWorkout workout, {bool save = true}) {
    current = workout;
    for (final e in workout.entries) {
      for (final s in e.sets) {
        s.addListener(_scheduleSave);
      }
    }
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (save) _saveNow();
    notifyListeners();
  }

  void _tick() {
    final workout = current;
    if (workout == null) return;
    final ends = workout.restEndsAt;
    if (ends != null && restRemaining == 0) {
      workout.restEndsAt = null;
      if (now().difference(ends) <= _lateAlertGrace) {
        HapticFeedback.vibrate();
        alerts.fireNow(nextUpLabel());
      }
      _saveNow();
    }
    notifyListeners();
  }

  void addExercises(List<String> ids) {
    final workout = current;
    if (workout == null) return;
    for (final id in ids) {
      final exercise = store.exerciseById(id);
      if (exercise == null) continue;
      final previous = store.lastSetsFor(id);
      final count = previous.isEmpty ? 3 : previous.length;
      final sets = [
        for (var i = 0; i < count; i++)
          ActiveSet(
            previous: i < previous.length ? previous[i] : null,
            weight: i < previous.length ? formatWeight(previous[i].weight) : '',
            rir: i < previous.length ? '${previous[i].rir}' : '',
          )..addListener(_scheduleSave),
      ];
      workout.entries.add(ActiveExercise(exercise, sets));
    }
    _changed();
  }

  void removeExercise(ActiveExercise entry) {
    current?.entries.remove(entry);
    for (final s in entry.sets) {
      s.dispose();
    }
    _changed();
  }

  void setRest(ActiveExercise entry, int seconds) {
    entry.restSeconds = seconds.clamp(0, 3600);
    _changed();
  }

  /// "Bench Press · set 3" for the first set not ticked yet, or '' when all are done.
  String nextUpLabel() {
    for (final e in current?.entries ?? const <ActiveExercise>[]) {
      final i = e.sets.indexWhere((s) => !s.done);
      if (i >= 0) return '${e.exercise.name} · set ${i + 1}';
    }
    return '';
  }

  void addSet(ActiveExercise entry) {
    final last = entry.sets.isEmpty ? null : entry.sets.last;
    entry.sets.add(ActiveSet(
      planned: last?.planned,
      weight: last?.weight.text ?? '',
      rir: last?.rir.text ?? '',
    )..addListener(_scheduleSave));
    _changed();
  }

  void removeSet(ActiveExercise entry, int index) {
    entry.sets.removeAt(index).dispose();
    _changed();
  }

  /// Returns false when the set can't be completed because weight/reps are missing.
  bool toggleDone(ActiveSet set) {
    final workout = current;
    if (workout == null) return false;
    if (set.done) {
      set.done = false;
      _changed();
      return true;
    }
    set.fillFromHints();
    if (set.toLogged() == null) return false;
    HapticFeedback.selectionClick();
    set.done = true;
    final rest = workout.entries
            .where((e) => e.sets.contains(set))
            .map((e) => e.restSeconds)
            .firstOrNull ??
        kDefaultRestSeconds;
    if (rest > 0 && workout.doneSets < workout.totalSets) {
      _startRest(workout, rest);
    } else {
      _stopRest(workout);
    }
    _changed();
    return true;
  }

  void _startRest(ActiveWorkout workout, int seconds) {
    workout.restTotal = seconds;
    final ends = now().add(Duration(seconds: seconds));
    workout.restEndsAt = ends;
    alerts.schedule(ends, nextUpLabel());
  }

  void _stopRest(ActiveWorkout workout) {
    if (workout.restEndsAt == null) return;
    workout.restEndsAt = null;
    alerts.cancel();
  }

  void adjustRest(int deltaSeconds) {
    final workout = current;
    final ends = workout?.restEndsAt;
    if (workout == null || ends == null) return;
    final newEnd = ends.add(Duration(seconds: deltaSeconds));
    workout.restTotal = (workout.restTotal + deltaSeconds).clamp(1, 3600);
    if (newEnd.isBefore(now())) {
      _stopRest(workout);
    } else {
      workout.restEndsAt = newEnd;
      alerts.schedule(newEnd, nextUpLabel());
    }
    _changed();
  }

  void skipRest() {
    final workout = current;
    if (workout != null) _stopRest(workout);
    _changed();
  }

  /// Saves completed sets as a [Session] and ends the workout. Returns null if nothing was ticked.
  Session? finish() {
    final workout = current;
    if (workout == null) return null;
    final logs = <ExerciseLog>[];
    for (final e in workout.entries) {
      final sets = e.sets.where((s) => s.done).map((s) => s.toLogged()).whereType<LoggedSet>().toList();
      if (sets.isNotEmpty) logs.add(ExerciseLog(exerciseId: e.exercise.id, sets: sets));
    }
    if (logs.isEmpty) return null;
    final session = Session(
      id: newId(),
      workoutId: workout.workoutId,
      workoutName: workout.name,
      date: workout.startedAt,
      durationSeconds: elapsed.inSeconds,
      logs: logs,
    );
    store.addSession(session);
    discard();
    return session;
  }

  void discard() {
    _clear();
    _saveNow();
    notifyListeners();
  }

  void _clear() {
    _ticker?.cancel();
    _ticker = null;
    final workout = current;
    current = null;
    if (workout == null) return;
    if (workout.restEndsAt != null) alerts.cancel();
    // Dispose after the frame so widgets still holding the controllers can unmount first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final e in workout.entries) {
        for (final s in e.sets) {
          s.dispose();
        }
      }
    });
  }

  void _changed() {
    notifyListeners();
    _saveNow();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), _saveNow);
  }

  void _saveNow() {
    _saveDebounce?.cancel();
    final file = _draftFile;
    if (file == null) return;
    final workout = current;
    final contents = workout == null
        ? null
        : jsonEncode({
            'workoutId': workout.workoutId,
            'name': workout.name,
            'startedAt': workout.startedAt.toIso8601String(),
            'restTotal': workout.restTotal,
            'restEndsAt': workout.restEndsAt?.toIso8601String(),
            'entries': [
              for (final e in workout.entries)
                {
                  'exerciseId': e.exercise.id,
                  'restSeconds': e.restSeconds,
                  'sets': e.sets.map((s) => s.toJson()).toList(),
                },
            ],
          });
    _pendingWrite = (_pendingWrite ?? Future<void>.value()).then((_) async {
      if (contents == null) {
        if (await file.exists()) await file.delete();
        return;
      }
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(contents, flush: true);
      await temp.rename(file.path);
    }).catchError((Object error) {
      debugPrint('Failed to save workout in progress: $error');
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _saveDebounce?.cancel();
    super.dispose();
  }
}
