import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'exercise_form_screen.dart';

/// Pops with the list of selected exercise ids.
class ExercisePickerScreen extends StatefulWidget {
  const ExercisePickerScreen({super.key, this.alreadyAdded = const {}});

  final Set<String> alreadyAdded;

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  final List<String> _selected = [];
  String _query = '';

  Future<void> _createExercise() async {
    final created = await Navigator.push<Exercise>(
      context,
      MaterialPageRoute(
          builder: (_) => ExerciseFormScreen(initialName: _query.trim())),
    );
    if (created != null) setState(() => _selected.add(created.id));
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final exercises = context
        .watch<AppStore>()
        .exercises
        .where((e) =>
            query.isEmpty ||
            e.name.toLowerCase().contains(query) ||
            e.muscles.any((m) => m.toLowerCase().contains(query)))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Exercises'),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected),
            child: Text(_selected.isEmpty ? 'Add' : 'Add (${_selected.length})'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search exercises or muscles',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.accent,
              child: Icon(Icons.add, color: Colors.white),
            ),
            title: Text(query.isEmpty ? 'Create new exercise' : 'Create "${_query.trim()}"'),
            onTap: _createExercise,
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: exercises.length,
              itemBuilder: (context, i) {
                final e = exercises[i];
                final inWorkout = widget.alreadyAdded.contains(e.id);
                return CheckboxListTile(
                  value: _selected.contains(e.id),
                  onChanged: (on) => setState(() {
                    on == true ? _selected.add(e.id) : _selected.remove(e.id);
                  }),
                  secondary: ExerciseThumbnail(e.name, size: 44),
                  title: Text(e.name),
                  subtitle: Text(
                    [
                      if (e.muscles.isNotEmpty) e.muscles.join(', '),
                      if (inWorkout) 'Already in workout',
                    ].join(' · '),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
