import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';

/// Returns the saved [Exercise] when popped after saving.
class ExerciseFormScreen extends StatefulWidget {
  const ExerciseFormScreen({super.key, this.exercise, this.initialName});

  final Exercise? exercise;
  final String? initialName;

  @override
  State<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends State<ExerciseFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late final List<String> _muscles;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.exercise?.name ?? widget.initialName ?? '');
    _notes = TextEditingController(text: widget.exercise?.notes ?? '');
    _muscles = [...?widget.exercise?.muscles];
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter an exercise name.')));
      return;
    }
    final exercise = Exercise(
      id: widget.exercise?.id ?? newId(),
      name: name,
      muscles: _muscles,
      notes: _notes.text.trim(),
    );
    context.read<AppStore>().upsertExercise(exercise);
    Navigator.pop(context, exercise);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exercise == null ? 'New Exercise' : 'Edit Exercise'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            autofocus: widget.exercise == null,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Muscles worked',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Select primary muscles first.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final muscle in kMuscleGroups)
                FilterChip(
                  label: Text(muscle),
                  selected: _muscles.contains(muscle),
                  onSelected: (on) => setState(() {
                    on ? _muscles.add(muscle) : _muscles.remove(muscle);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _notes,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Notes (setup, cues, machine settings)',
              alignLabelWithHint: true,
              contentPadding: EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }
}
