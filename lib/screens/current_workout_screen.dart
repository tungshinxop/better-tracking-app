import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../active_workout.dart';
import '../models.dart';
import '../navigation.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'exercise_detail_screen.dart';
import 'exercise_picker_screen.dart';

String clockLabel(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// The "Current" tab: the workout in progress, or an empty state.
class CurrentWorkoutScreen extends StatelessWidget {
  const CurrentWorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final workout = session.current;
    if (workout == null) return const _NoWorkout();
    return _ActiveWorkoutView(session: session, workout: workout);
  }
}

class _NoWorkout extends StatelessWidget {
  const _NoWorkout();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Current Workout')),
      body: EmptyState(
        icon: Icons.timer_outlined,
        title: 'No workout in progress',
        message: 'Start a template or an empty workout. It stays here until you finish it, '
            'even if you switch tabs or close the app.',
        action: Column(
          children: [
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent, foregroundColor: Colors.white),
              onPressed: () => beginWorkout(
                  Navigator.of(context).context, Workout(id: '', name: 'Quick Workout')),
              child: const Text('Start an Empty Workout'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.read<HomeTabs>().go(HomeTabs.workout),
              child: const Text('Choose a template'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveWorkoutView extends StatelessWidget {
  const _ActiveWorkoutView({required this.session, required this.workout});

  final SessionController session;
  final ActiveWorkout workout;

  void _toggle(BuildContext context, ActiveSet set) {
    if (!session.toggleDone(set)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter weight and reps first.')));
      return;
    }
    FocusScope.of(context).unfocus();
  }

  Future<void> _addExercises(BuildContext context) async {
    final ids = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => ExercisePickerScreen(
          alreadyAdded: workout.entries.map((e) => e.exercise.id).toSet(),
        ),
      ),
    );
    if (ids != null && ids.isNotEmpty) session.addExercises(ids);
  }

  Future<void> _discard(BuildContext context) async {
    final ok = await confirmDialog(context,
        title: 'Discard workout?',
        message: 'Sets logged in "${workout.name}" will be lost.',
        confirmLabel: 'Discard');
    if (!ok || !context.mounted) return;
    session.discard();
    context.read<HomeTabs>().go(HomeTabs.workout);
  }

  Future<void> _finish(BuildContext context) async {
    final store = context.read<AppStore>();
    final tabs = context.read<HomeTabs>();
    final messenger = ScaffoldMessenger.of(context);
    final navigatorContext = Navigator.of(context).context;

    if (workout.doneSets == 0) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Tick at least one set as done before finishing.')));
      return;
    }
    final undone = workout.totalSets - workout.doneSets;
    if (undone > 0) {
      final ok = await confirmDialog(context,
          title: 'Finish workout?',
          message: '$undone set${undone == 1 ? '' : 's'} not ticked will not be saved.',
          confirmLabel: 'Finish',
          destructive: false);
      if (!ok) return;
    }

    final isSavedTemplate = store.workoutById(workout.workoutId) != null;
    final restByExercise = {for (final e in workout.entries) e.exercise.id: e.restSeconds};
    final suggestedName = workout.workoutId.isEmpty ? '' : workout.name;
    final saved = session.finish();
    if (saved == null) return;

    String? templateName;
    if (!isSavedTemplate && navigatorContext.mounted) {
      templateName = await promptText(
        navigatorContext,
        title: 'Save as template?',
        message: 'Reuse this workout later with the same exercises and sets.',
        initial: suggestedName,
        label: 'Template name',
      );
      if (templateName != null && templateName.isNotEmpty) {
        store.saveSessionAsTemplate(saved, templateName, restByExercise: restByExercise);
      }
    }

    tabs.go(HomeTabs.workout);
    messenger.showSnackBar(SnackBar(
      content: Text(templateName != null && templateName.isNotEmpty
          ? 'Workout saved · ${saved.totalSets} sets · template "$templateName" created'
          : '${saved.workoutName} saved · ${saved.totalSets} sets'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final progress = workout.totalSets == 0 ? 0.0 : workout.doneSets / workout.totalSets;
    final rest = session.restRemaining;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(workout.name),
            Text(clockLabel(session.elapsed),
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => _finish(context), child: const Text('Finish')),
          PopupMenuButton<String>(
            tooltip: 'Workout options',
            onSelected: (_) => _discard(context),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'discard', child: Text('Discard workout')),
            ],
          ),
        ],
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
          children: [
            if (workout.entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                child: Text(
                  'Add your first exercise to start logging sets.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                ),
              ),
            for (final entry in workout.entries)
              _ExerciseLogCard(
                key: ObjectKey(entry),
                entry: entry,
                onToggle: (set) => _toggle(context, set),
                onAddSet: () => session.addSet(entry),
                onRemoveSet: (index) => session.removeSet(entry, index),
                onRemoveExercise: () => session.removeExercise(entry),
                onRestChanged: (seconds) => session.setRest(entry, seconds),
              ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _addExercises(context),
              icon: const Icon(Icons.add),
              label: const Text('Add exercise'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: rest > 0
          ? _RestBar(
              remaining: rest,
              total: workout.restTotal,
              label: clockLabel(Duration(seconds: rest)),
              nextUp: session.nextUpLabel(),
              onAdjust: session.adjustRest,
              onSkip: session.skipRest,
            )
          : null,
    );
  }
}

/// Slim bar above the tab bar that leads back to the workout in progress.
class ResumeWorkoutBar extends StatelessWidget {
  const ResumeWorkoutBar({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final workout = session.current;
    if (workout == null) return const SizedBox.shrink();
    final rest = session.restRemaining;
    return Material(
      color: AppColors.accent,
      child: InkWell(
        onTap: () => context.read<HomeTabs>().go(HomeTabs.current),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.fitness_center, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${workout.name} · ${clockLabel(session.elapsed)}'
                  '${rest > 0 ? ' · rest ${clockLabel(Duration(seconds: rest))}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              const Text('Resume',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestBar extends StatelessWidget {
  const _RestBar({
    required this.remaining,
    required this.total,
    required this.label,
    required this.nextUp,
    required this.onAdjust,
    required this.onSkip,
  });

  final int remaining;
  final int total;
  final String label;
  final String nextUp;
  final ValueChanged<int> onAdjust;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (remaining / total).clamp(0.0, 1.0);
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: AppColors.surfaceHigh,
              color: AppColors.accent,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 4,
                            backgroundColor: AppColors.surfaceHigh,
                            color: AppColors.accent,
                          ),
                        ),
                        const Icon(Icons.timer_outlined, size: 20, color: AppColors.accent),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Rest $label',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()])),
                        if (nextUp.isNotEmpty)
                          Text('Next: $nextUp',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  _RestButton(label: '-15', onPressed: () => onAdjust(-15)),
                  _RestButton(label: '+15', onPressed: () => onAdjust(15)),
                  _RestButton(label: 'Skip', onPressed: onSkip),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestButton extends StatelessWidget {
  const _RestButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 40),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _ExerciseLogCard extends StatelessWidget {
  const _ExerciseLogCard({
    super.key,
    required this.entry,
    required this.onToggle,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.onRemoveExercise,
    required this.onRestChanged,
  });

  final ActiveExercise entry;
  final ValueChanged<ActiveSet> onToggle;
  final VoidCallback onAddSet;
  final ValueChanged<int> onRemoveSet;
  final VoidCallback onRemoveExercise;
  final ValueChanged<int> onRestChanged;

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
                PopupMenuButton<String>(
                  tooltip: 'Exercise options',
                  onSelected: (_) => onRemoveExercise(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'remove', child: Text('Remove exercise')),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 52, top: 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: RestChip(seconds: entry.restSeconds, onChanged: onRestChanged),
              ),
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
  final ActiveSet set;
  final ValueChanged<ActiveSet> onToggle;

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
                controller: set.rir, hint: set.rirHint, enabled: !set.done),
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
