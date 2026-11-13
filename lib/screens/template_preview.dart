import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../examples.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../navigation.dart';
import 'exercise_detail_screen.dart';
import 'workout_editor_screen.dart';

/// Opens a template as a popup card. For an example, [workout] is a
/// materialized copy that is not stored until the user taps Add.
Future<void> showTemplatePreview(
  BuildContext context, {
  required Workout workout,
  ExampleTemplate? example,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => _TemplatePreviewDialog(workout: workout, example: example),
  );
}

class _TemplatePreviewDialog extends StatelessWidget {
  const _TemplatePreviewDialog({required this.workout, this.example});

  final Workout workout;
  final ExampleTemplate? example;

  bool get _isExample => example != null;

  void _start(BuildContext context, Workout current) {
    final navigator = Navigator.of(context);
    navigator.pop();
    beginWorkout(navigator.context, current);
  }

  void _edit(BuildContext context, Workout current) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
        MaterialPageRoute(builder: (_) => WorkoutEditorScreen(workout: current)));
  }

  void _addToMyTemplates(BuildContext context) {
    final store = context.read<AppStore>();
    final messenger = ScaffoldMessenger.of(context);
    final saved = example!.materialize(store, keepId: false);
    store.upsertWorkout(saved);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text('${saved.name} added to My Templates')));
  }

  void _openExercise(BuildContext context, String exerciseId) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exerciseId: exerciseId)));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final current = _isExample ? workout : store.workoutById(workout.id);
    if (current == null) return const SizedBox.shrink();
    final last = store.lastPerformed(current.id);
    final rows = [
      for (final we in current.exercises)
        if (store.exerciseById(we.exerciseId) case final exercise?) (we, exercise),
    ];
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Close',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceHigh,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      current.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: _isExample
                        ? () => _addToMyTemplates(context)
                        : () => _edit(context, current),
                    child: Text(_isExample ? 'Add' : 'Edit',
                        style: const TextStyle(fontSize: 17)),
                  ),
                ],
              ),
              if (_isExample || last != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    [
                      if (_isExample) 'Example template',
                      if (last != null) 'Last Performed: ${formatLongDate(last)}',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: rows.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Text('No exercises in this template yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: rows.length,
                        itemBuilder: (context, i) {
                          final (plan, exercise) = rows[i];
                          return _ExerciseRow(
                            sets: plan.sets.length,
                            exercise: exercise,
                            onInfo: () => _openExercise(context, exercise.id),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                ),
                onPressed: rows.isEmpty ? null : () => _start(context, current),
                child: const Text('Start Workout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.sets, required this.exercise, required this.onInfo});

  final int sets;
  final Exercise exercise;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          ExerciseThumbnail(exercise.name, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$sets × ${exercise.name}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                if (exercise.muscles.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(exercise.muscles.first,
                      style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'About ${exercise.name}',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.accent.withValues(alpha: 0.15),
              foregroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.question_mark, size: 20),
            onPressed: onInfo,
          ),
        ],
      ),
    );
  }
}
