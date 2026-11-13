import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'exercise_detail_screen.dart';
import 'exercise_form_screen.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final query = _query.trim().toLowerCase();
    final exercises = store.exercises
        .where((e) =>
            query.isEmpty ||
            e.name.toLowerCase().contains(query) ||
            e.muscles.any((m) => m.toLowerCase().contains(query)))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercises'),
        actions: [
          IconButton(
            tooltip: 'New exercise',
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ExerciseFormScreen())),
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
          Expanded(
            child: exercises.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off,
                    title: 'No exercises found',
                    message: 'Tap + to create a new exercise.',
                  )
                : ListView.builder(
                    itemCount: exercises.length,
                    itemBuilder: (context, i) {
                      final e = exercises[i];
                      final sessions = store.historyFor(e.id).length;
                      return ListTile(
                        leading: ExerciseThumbnail(e.name, size: 44),
                        title: Text(e.name),
                        subtitle: Text(
                          [
                            if (e.muscles.isNotEmpty) e.muscles.join(', '),
                            if (sessions > 0) '$sessions session${sessions == 1 ? '' : 's'}',
                          ].join(' · '),
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ExerciseDetailScreen(exerciseId: e.id)),
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
