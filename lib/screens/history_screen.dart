import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<AppStore>().sessions;
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: sessions.isEmpty
          ? const EmptyState(
              icon: Icons.history,
              title: 'No workouts logged',
              message: 'Finished workouts show up here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _SessionCard(session: sessions[i]),
            ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => SessionDetailScreen(session: session))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.workoutName,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      '${formatDate(session.date)} · ${formatDuration(Duration(seconds: session.durationSeconds))}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${session.totalSets} sets',
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text('${formatWeight(session.totalVolume)} kg',
                      style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    return Scaffold(
      appBar: AppBar(
        title: Text(session.workoutName),
        actions: [
          IconButton(
            tooltip: 'Save as template',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final name = await promptText(context,
                  title: 'Save as template',
                  initial: session.workoutName,
                  label: 'Template name',
                  message: 'Creates a template with these exercises and the sets you logged.');
              if (name == null || name.isEmpty) return;
              store.saveSessionAsTemplate(session, name);
              messenger.showSnackBar(SnackBar(content: Text('Template "$name" created')));
            },
          ),
          IconButton(
            tooltip: 'Delete session',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final ok = await confirmDialog(context,
                  title: 'Delete this session?',
                  message: 'Its sets will be removed from your progression graphs.');
              if (!ok) return;
              store.deleteSession(session.id);
              navigator.pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${formatDate(session.date)} · ${formatDuration(Duration(seconds: session.durationSeconds))} · '
            '${session.totalSets} sets · ${formatWeight(session.totalVolume)} kg',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          for (final log in session.logs) ...[
            Text(store.exerciseById(log.exerciseId)?.name ?? 'Deleted exercise',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            for (var i = 0; i < log.sets.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SetNumberBubble(i + 1, done: true),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text('${formatWeight(log.sets[i].weight)} kg × ${log.sets[i].reps} reps')),
                    RirBadge(log.sets[i].rir, size: 26),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
