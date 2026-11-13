import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'exercise_picker_screen.dart';

class WorkoutEditorScreen extends StatefulWidget {
  const WorkoutEditorScreen({super.key, this.workout});

  final Workout? workout;

  @override
  State<WorkoutEditorScreen> createState() => _WorkoutEditorScreenState();
}

class _WorkoutEditorScreenState extends State<WorkoutEditorScreen> {
  late final Workout _draft;
  late final TextEditingController _name;
  bool _dirty = false;

  bool get _isNew => widget.workout == null;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _draft = widget.workout?.copy() ??
        Workout(id: newId(), name: _suggestName(store.workouts.length));
    _name = TextEditingController(text: _draft.name);
  }

  String _suggestName(int count) =>
      'Workout ${String.fromCharCode('A'.codeUnitAt(0) + (count % 26))}';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _addExercises() async {
    final ids = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => ExercisePickerScreen(
          alreadyAdded: _draft.exercises.map((e) => e.exerciseId).toSet(),
        ),
      ),
    );
    if (ids == null || ids.isEmpty) return;
    setState(() {
      _draft.exercises.addAll(ids.map((id) => WorkoutExercise(exerciseId: id)));
      _dirty = true;
    });
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Give the workout a name.')));
      return;
    }
    for (final we in _draft.exercises) {
      for (final s in we.sets) {
        if (s.repsMax < s.repsMin) {
          final tmp = s.repsMin;
          s.repsMin = s.repsMax;
          s.repsMax = tmp;
        }
      }
    }
    _draft.name = name;
    context.read<AppStore>().upsertWorkout(_draft);
    Navigator.pop(context, _draft);
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return confirmDialog(context,
        title: 'Discard changes?',
        message: 'Your edits to this workout will be lost.',
        confirmLabel: 'Discard');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'New Workout' : 'Edit Workout'),
          actions: [TextButton(onPressed: _save, child: const Text('Save'))],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addExercises,
          icon: const Icon(Icons.add),
          label: const Text('Add exercise'),
        ),
        body: ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          header: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: TextField(
              controller: _name,
              onChanged: (_) => _markDirty(),
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 20),
              decoration: const InputDecoration(
                labelText: 'Workout name',
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),
          itemCount: _draft.exercises.length,
          onReorderItem: (oldIndex, newIndex) {
            setState(() {
              _draft.exercises.insert(newIndex, _draft.exercises.removeAt(oldIndex));
              _dirty = true;
            });
          },
          itemBuilder: (context, index) {
            final plan = _draft.exercises[index];
            final exercise = store.exerciseById(plan.exerciseId);
            return _ExercisePlanCard(
              key: ObjectKey(plan),
              index: index,
              plan: plan,
              exerciseName: exercise?.name ?? 'Deleted exercise',
              onChanged: () => setState(() => _dirty = true),
              onRemove: () => setState(() {
                _draft.exercises.removeAt(index);
                _dirty = true;
              }),
            );
          },
        ),
      ),
    );
  }
}

class _ExercisePlanCard extends StatelessWidget {
  const _ExercisePlanCard({
    super.key,
    required this.index,
    required this.plan,
    required this.exerciseName,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final WorkoutExercise plan;
  final String exerciseName;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.drag_indicator, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(exerciseName,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  tooltip: 'Remove exercise',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onRemove,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 2, bottom: 4),
              child: RestChip(
                seconds: plan.restSeconds,
                onChanged: (seconds) {
                  plan.restSeconds = seconds;
                  onChanged();
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 8, 4),
              child: Row(
                children: [
                  SizedBox(width: 38, child: _Header('SET')),
                  Expanded(flex: 5, child: _Header('REPS')),
                  SizedBox(width: 8),
                  Expanded(flex: 3, child: _Header('RIR')),
                  SizedBox(width: 8),
                  Expanded(flex: 4, child: _Header('KG (opt.)')),
                  SizedBox(width: 40),
                ],
              ),
            ),
            for (var i = 0; i < plan.sets.length; i++)
              _PlannedSetRow(
                key: ObjectKey(plan.sets[i]),
                number: i + 1,
                set: plan.sets[i],
                onChanged: onChanged,
                onRemove: plan.sets.length > 1
                    ? () {
                        plan.sets.removeAt(i);
                        onChanged();
                      }
                    : null,
              ),
            TextButton.icon(
              onPressed: () {
                plan.sets.add(plan.sets.isEmpty ? PlannedSet() : plan.sets.last.copy());
                onChanged();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add set'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600));
}

class _PlannedSetRow extends StatelessWidget {
  const _PlannedSetRow({
    super.key,
    required this.number,
    required this.set,
    required this.onChanged,
    required this.onRemove,
  });

  final int number;
  final PlannedSet set;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 4),
      child: Row(
        children: [
          SizedBox(width: 38, child: SetNumberBubble(number)),
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Expanded(
                  child: _NumberField(
                    initial: '${set.repsMin}',
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null) set.repsMin = n;
                      onChanged();
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('–'),
                ),
                Expanded(
                  child: _NumberField(
                    initial: '${set.repsMax}',
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null) set.repsMax = n;
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: _NumberField(
              initial: '${set.rir}',
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null) set.rir = n;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: _NumberField(
              initial: set.weight == null ? '' : formatWeight(set.weight!),
              decimal: true,
              hint: '—',
              onChanged: (v) {
                set.weight = parseWeight(v);
                onChanged();
              },
            ),
          ),
          SizedBox(
            width: 40,
            child: onRemove == null
                ? null
                : IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: onRemove,
                  ),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.initial,
    required this.onChanged,
    this.decimal = false,
    this.hint,
  });

  final String initial;
  final ValueChanged<String> onChanged;
  final bool decimal;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initial,
      onChanged: onChanged,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(decimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]')),
      ],
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        fillColor: AppColors.surfaceHigh,
      ),
    );
  }
}
