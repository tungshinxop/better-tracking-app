import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'exercise_detail_screen.dart';

const _defaultRestSeconds = 120;

class _SetEntry {
  _SetEntry({this.planned, this.previous, String weight = '', String rir = ''})
      : weight = TextEditingController(text: weight),
        reps = TextEditingController(),
        rir = TextEditingController(text: rir);

  final PlannedSet? planned;
  final LoggedSet? previous;
  final TextEditingController weight;
  final TextEditingController reps;
  final TextEditingController rir;
  bool done = false;

  String get repsHint {
    final p = planned;
    if (p == null) return previous == null ? '' : '${previous!.reps}';
    return p.repsMin == p.repsMax ? '${p.repsMin}' : '${p.repsMin}-${p.repsMax}';
  }

  String get weightHint => previous == null ? 'kg' : formatWeight(previous!.weight);

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

  void dispose() {
    weight.dispose();
    reps.dispose();
    rir.dispose();
  }
}

class _ExerciseEntry {
  _ExerciseEntry(this.exercise, this.sets);

  final Exercise exercise;
  final List<_SetEntry> sets;
}

class ActiveSessionScreen extends StatefulWidget {
  const ActiveSessionScreen({super.key, required this.workout});

  final Workout workout;

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  final DateTime _startedAt = DateTime.now();
  late final List<_ExerciseEntry> _entries;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  int _restRemaining = 0;
  int _restTotal = _defaultRestSeconds;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _entries = [
      for (final plan in widget.workout.exercises)
        if (store.exerciseById(plan.exerciseId) case final exercise?)
          _ExerciseEntry(exercise, _buildSets(plan, store.lastSetsFor(exercise.id))),
    ];
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  List<_SetEntry> _buildSets(WorkoutExercise plan, List<LoggedSet> previous) {
    return [
      for (var i = 0; i < plan.sets.length; i++)
        _SetEntry(
          planned: plan.sets[i],
          previous: i < previous.length ? previous[i] : null,
          weight: i < previous.length
              ? formatWeight(previous[i].weight)
              : (plan.sets[i].weight == null ? '' : formatWeight(plan.sets[i].weight!)),
          rir: '${plan.sets[i].rir}',
        ),
    ];
  }

  void _tick() {
    setState(() {
      _elapsed = DateTime.now().difference(_startedAt);
      if (_restRemaining > 0) {
        _restRemaining--;
        if (_restRemaining == 0) HapticFeedback.heavyImpact();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final e in _entries) {
      for (final s in e.sets) {
        s.dispose();
      }
    }
    super.dispose();
  }

  int get _doneSets =>
      _entries.fold(0, (sum, e) => sum + e.sets.where((s) => s.done).length);

  int get _totalSets => _entries.fold(0, (sum, e) => sum + e.sets.length);

  void _toggleDone(_SetEntry set) {
    if (set.done) {
      setState(() => set.done = false);
      return;
    }
    set.fillFromHints();
    if (set.toLogged() == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter weight and reps first.')));
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      set.done = true;
      _restTotal = _defaultRestSeconds;
      _restRemaining = _defaultRestSeconds;
    });
  }

  void _addSet(_ExerciseEntry entry) {
    final last = entry.sets.isEmpty ? null : entry.sets.last;
    setState(() {
      entry.sets.add(_SetEntry(
        planned: last?.planned,
        weight: last?.weight.text ?? '',
        rir: last?.rir.text ?? '',
      ));
    });
  }

  void _removeSet(_ExerciseEntry entry, int index) {
    setState(() => entry.sets.removeAt(index).dispose());
  }

  Future<void> _finish() async {
    final logs = <ExerciseLog>[];
    for (final e in _entries) {
      final sets = e.sets.where((s) => s.done).map((s) => s.toLogged()).whereType<LoggedSet>().toList();
      if (sets.isNotEmpty) logs.add(ExerciseLog(exerciseId: e.exercise.id, sets: sets));
    }
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tick at least one set as done before finishing.')));
      return;
    }
    final undone = _totalSets - _doneSets;
    if (undone > 0) {
      final ok = await confirmDialog(context,
          title: 'Finish workout?',
          message: '$undone set${undone == 1 ? '' : 's'} not ticked will not be saved.',
          confirmLabel: 'Finish',
          destructive: false);
      if (!ok || !mounted) return;
    }
    context.read<AppStore>().addSession(Session(
          id: newId(),
          workoutId: widget.workout.id,
          workoutName: widget.workout.name,
          date: _startedAt,
          durationSeconds: DateTime.now().difference(_startedAt).inSeconds,
          logs: logs,
        ));
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
        SnackBar(content: Text('${widget.workout.name} saved · ${logs.fold(0, (s, l) => s + l.sets.length)} sets')));
  }

  String _clock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalSets == 0 ? 0.0 : _doneSets / _totalSets;

    return PopScope(
      canPop: _doneSets == 0,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final ok = await confirmDialog(context,
            title: 'Discard workout?',
            message: 'Logged sets from this session will be lost.',
            confirmLabel: 'Discard');
        if (ok) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const CloseButton(),
          title: Column(
            children: [
              Text(widget.workout.name),
              Text(_clock(_elapsed),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          actions: [TextButton(onPressed: _finish, child: const Text('Finish'))],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AppColors.surfaceHigh,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
            itemCount: _entries.length,
            itemBuilder: (context, i) => _ExerciseLogCard(
              entry: _entries[i],
              onToggle: _toggleDone,
              onAddSet: () => _addSet(_entries[i]),
              onRemoveSet: (index) => _removeSet(_entries[i], index),
            ),
          ),
        ),
        bottomNavigationBar: _restRemaining > 0
            ? _RestBar(
                remaining: _restRemaining,
                total: _restTotal,
                label: _clock(Duration(seconds: _restRemaining)),
                onAdjust: (delta) => setState(() {
                  _restRemaining = (_restRemaining + delta).clamp(0, 3600);
                  _restTotal = (_restTotal + delta).clamp(1, 3600);
                }),
                onSkip: () => setState(() => _restRemaining = 0),
              )
            : null,
      ),
    );
  }
}

class _RestBar extends StatelessWidget {
  const _RestBar({
    required this.remaining,
    required this.total,
    required this.label,
    required this.onAdjust,
    required this.onSkip,
  });

  final int remaining;
  final int total;
  final String label;
  final ValueChanged<int> onAdjust;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: total == 0 ? 0 : remaining / total,
              minHeight: 3,
              backgroundColor: AppColors.surfaceHigh,
              color: AppColors.accent,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text('Rest $label',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(onPressed: () => onAdjust(-15), child: const Text('-15s')),
                  TextButton(onPressed: () => onAdjust(15), child: const Text('+15s')),
                  TextButton(onPressed: onSkip, child: const Text('Skip')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseLogCard extends StatelessWidget {
  const _ExerciseLogCard({
    required this.entry,
    required this.onToggle,
    required this.onAddSet,
    required this.onRemoveSet,
  });

  final _ExerciseEntry entry;
  final ValueChanged<_SetEntry> onToggle;
  final VoidCallback onAddSet;
  final ValueChanged<int> onRemoveSet;

  @override
  Widget build(BuildContext context) {
    final exercise = entry.exercise;
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExerciseThumbnail(exercise.name, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(exercise.name,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  tooltip: 'Exercise info',
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ExerciseDetailScreen(exerciseId: exercise.id)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const _LogHeader(),
            for (var i = 0; i < entry.sets.length; i++)
              Dismissible(
                key: ObjectKey(entry.sets[i]),
                direction: entry.sets.length > 1
                    ? DismissDirection.endToStart
                    : DismissDirection.none,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: AppColors.rirLow,
                  child: const Icon(Icons.delete_outline),
                ),
                onDismissed: (_) => onRemoveSet(i),
                child: _SetRow(number: i + 1, set: entry.sets[i], onToggle: onToggle),
              ),
            TextButton.icon(
              onPressed: onAddSet,
              icon: const Icon(Icons.add),
              label: const Text('Add set'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogHeader extends StatelessWidget {
  const _LogHeader();

  static const _style = TextStyle(
      fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600);

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text('SET', style: _style)),
          Expanded(flex: 4, child: Text('PREVIOUS', style: _style)),
          Expanded(flex: 4, child: Center(child: Text('KG', style: _style))),
          SizedBox(width: 6),
          Expanded(flex: 3, child: Center(child: Text('REPS', style: _style))),
          SizedBox(width: 6),
          Expanded(flex: 3, child: Center(child: Text('RIR', style: _style))),
          SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({required this.number, required this.set, required this.onToggle});

  final int number;
  final _SetEntry set;
  final ValueChanged<_SetEntry> onToggle;

  @override
  Widget build(BuildContext context) {
    final prev = set.previous;
    return Container(
      color: set.done ? AppColors.success.withValues(alpha: 0.12) : null,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 36, child: SetNumberBubble(number, done: set.done)),
          Expanded(
            flex: 4,
            child: Text(
              prev == null ? '—' : '${formatWeight(prev.weight)}×${prev.reps}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 4,
            child: _LogField(
                controller: set.weight, hint: set.weightHint, decimal: true, enabled: !set.done),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: _LogField(controller: set.reps, hint: set.repsHint, enabled: !set.done),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: _LogField(
                controller: set.rir, hint: '${set.planned?.rir ?? ''}', enabled: !set.done),
          ),
          SizedBox(
            width: 48,
            child: IconButton(
              tooltip: set.done ? 'Undo' : 'Mark set done',
              onPressed: () => onToggle(set),
              icon: Icon(
                set.done ? Icons.check_circle : Icons.check_circle_outline,
                color: set.done ? AppColors.success : AppColors.textSecondary,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogField extends StatelessWidget {
  const _LogField({
    required this.controller,
    required this.hint,
    required this.enabled,
    this.decimal = false,
  });

  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(decimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]')),
      ],
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.outline),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        fillColor: AppColors.surfaceHigh,
      ),
    );
  }
}
