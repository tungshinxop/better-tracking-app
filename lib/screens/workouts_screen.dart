import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'active_session_screen.dart';
import 'exercise_detail_screen.dart';
import 'workout_editor_screen.dart';

const _minutesPerSet = 2.75;

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  int _selected = 0;

  Future<void> _createWorkout() async {
    final store = context.read<AppStore>();
    final created = await Navigator.push<Workout>(
      context,
      MaterialPageRoute(builder: (_) => const WorkoutEditorScreen()),
    );
    if (created != null) {
      setState(() => _selected = store.workouts.indexWhere((w) => w.id == created.id));
    }
  }

  Future<void> _editWorkout(Workout workout) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WorkoutEditorScreen(workout: workout)),
    );
  }

  Future<void> _deleteWorkout(Workout workout) async {
    final store = context.read<AppStore>();
    final ok = await confirmDialog(context,
        title: 'Delete ${workout.name}?',
        message: 'The workout plan is removed. Logged history is kept.');
    if (!ok) return;
    store.deleteWorkout(workout.id);
    setState(() => _selected = 0);
  }

  @override
  Widget build(BuildContext context) {
    final workouts = context.watch<AppStore>().workouts;

    if (workouts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Program')),
        body: EmptyState(
          icon: Icons.fitness_center,
          title: 'No workouts yet',
          message: 'Create a workout and add exercises with planned sets, reps and RIR.',
          action: FilledButton(
              onPressed: _createWorkout, child: const Text('Create workout')),
        ),
      );
    }

    final selected = _selected.clamp(0, workouts.length - 1);
    final workout = workouts[selected];

    return DefaultTabController(
      key: ValueKey('tabs-${workouts.length}'),
      length: workouts.length,
      initialIndex: selected,
      child: Builder(builder: (context) {
        final controller = DefaultTabController.of(context);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Program'),
            actions: [
              IconButton(
                  tooltip: 'New workout',
                  icon: const Icon(Icons.add),
                  onPressed: _createWorkout),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _editWorkout(workout);
                  if (value == 'delete') _deleteWorkout(workout);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit workout')),
                  PopupMenuItem(value: 'delete', child: Text('Delete workout')),
                ],
              ),
            ],
            bottom: TabBar(
              isScrollable: true,
              onTap: (i) => setState(() => _selected = i),
              tabs: [for (final w in workouts) Tab(text: w.name)],
            ),
          ),
          body: TabBarView(
            children: [
              for (final w in workouts)
                _WorkoutOverview(workout: w, onEdit: () => _editWorkout(w)),
            ],
          ),
          bottomNavigationBar: _StartBar(
            controller: controller,
            workouts: workouts,
            onIndexChanged: (i) => _selected = i,
          ),
        );
      }),
    );
  }
}

class _StartBar extends StatefulWidget {
  const _StartBar({
    required this.controller,
    required this.workouts,
    required this.onIndexChanged,
  });

  final TabController controller;
  final List<Workout> workouts;
  final ValueChanged<int> onIndexChanged;

  @override
  State<_StartBar> createState() => _StartBarState();
}

class _StartBarState extends State<_StartBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTab);
  }

  @override
  void didUpdateWidget(covariant _StartBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTab);
      widget.controller.addListener(_onTab);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() {
    widget.onIndexChanged(widget.controller.index);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.controller.index.clamp(0, widget.workouts.length - 1);
    final workout = widget.workouts[index];
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: FilledButton(
        onPressed: workout.exercises.isEmpty
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => ActiveSessionScreen(workout: workout)),
                ),
        child: Text('Start ${workout.name}'),
      ),
    );
  }
}

class _WorkoutOverview extends StatelessWidget {
  const _WorkoutOverview({required this.workout, required this.onEdit});

  final Workout workout;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final entries = [
      for (final we in workout.exercises)
        if (store.exerciseById(we.exerciseId) case final exercise?) (we, exercise),
    ];

    if (entries.isEmpty) {
      return EmptyState(
        icon: Icons.playlist_add,
        title: 'No exercises',
        message: 'Add exercises to ${workout.name} to plan your sets.',
        action: FilledButton(onPressed: onEdit, child: const Text('Add exercises')),
      );
    }

    final muscleStats = <String, ({int exercises, int sets})>{};
    for (final (we, exercise) in entries) {
      for (final muscle in exercise.muscles) {
        final current = muscleStats[muscle] ?? (exercises: 0, sets: 0);
        muscleStats[muscle] =
            (exercises: current.exercises + 1, sets: current.sets + we.sets.length);
      }
    }
    final sortedMuscles = muscleStats.entries.toList()
      ..sort((a, b) => b.value.sets.compareTo(a.value.sets));

    final estimated = Duration(minutes: (workout.totalSets * _minutesPerSet).round());

    return ListView(
      padding: const EdgeInsets.only(top: 20, bottom: 24),
      children: [
        if (sortedMuscles.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SectionTitle('Target Muscles'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 108,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: sortedMuscles.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _MuscleCard(
                muscle: sortedMuscles[i].key,
                exercises: sortedMuscles[i].value.exercises,
                sets: sortedMuscles[i].value.sets,
              ),
            ),
          ),
          const SizedBox(height: 28),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SectionTitle(
            '${entries.length} Exercise${entries.length == 1 ? '' : 's'}',
            subtitle: 'Estimated workout time is ${formatDuration(estimated)}',
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < entries.length; i++) ...[
          _PlannedExerciseTile(plan: entries[i].$1, exercise: entries[i].$2),
          if (i < entries.length - 1)
            const Divider(indent: 108, endIndent: 0, height: 1),
        ],
      ],
    );
  }
}

class _MuscleCard extends StatelessWidget {
  const _MuscleCard({
    required this.muscle,
    required this.exercises,
    required this.sets,
  });

  final String muscle;
  final int exercises;
  final int sets;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.accessibility_new, color: AppColors.accent, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(muscle,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('$exercises exercise${exercises == 1 ? '' : 's'}',
                      style: const TextStyle(color: AppColors.textSecondary)),
                  Text('$sets sets', style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannedExerciseTile extends StatelessWidget {
  const _PlannedExerciseTile({required this.plan, required this.exercise});

  final WorkoutExercise plan;
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ExerciseDetailScreen(exerciseId: exercise.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: ExerciseThumbnail(exercise.name, size: 72),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(exercise.name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w500)),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (var i = 0; i < plan.sets.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SetNumberBubble(i + 1),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              plan.sets[i].weight == null
                                  ? plan.sets[i].repsLabel
                                  : '${plan.sets[i].repsLabel} · ${formatWeight(plan.sets[i].weight!)} kg',
                              style: const TextStyle(
                                  fontSize: 16, color: AppColors.textSecondary),
                            ),
                          ),
                          RirBadge(plan.sets[i].rir),
                        ],
                      ),
                    ),
                  if (exercise.muscles.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < exercise.muscles.length; i++)
                          MuscleChip(exercise.muscles[i], outlined: i >= 2),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
