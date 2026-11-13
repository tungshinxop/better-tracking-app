import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../examples.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../navigation.dart';
import 'template_preview.dart';
import 'workout_editor_screen.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  bool _showExamples = true;

  void _startEmpty() {
    beginWorkout(context, Workout(id: '', name: 'Quick Workout'));
  }

  void _createTemplate() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkoutEditorScreen()));
  }

  void _openTemplate(Workout workout) {
    showTemplatePreview(context, workout: workout);
  }

  void _openExample(ExampleTemplate example) {
    final workout = example.materialize(context.read<AppStore>());
    showTemplatePreview(context, workout: workout, example: example);
  }

  Future<void> _onTemplateMenu(String action, Workout workout) async {
    final store = context.read<AppStore>();
    switch (action) {
      case 'start':
        beginWorkout(context, workout);
      case 'edit':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => WorkoutEditorScreen(workout: workout)));
      case 'duplicate':
        store.duplicateWorkout(workout);
      case 'delete':
        final ok = await confirmDialog(context,
            title: 'Delete ${workout.name}?',
            message: 'The template is removed. Logged history is kept.');
        if (ok) store.deleteWorkout(workout.id);
    }
  }

  void _onExampleMenu(String action, ExampleTemplate example) {
    final store = context.read<AppStore>();
    switch (action) {
      case 'preview':
        _openExample(example);
      case 'add':
        store.upsertWorkout(example.materialize(store, keepId: false));
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${example.name} added to My Templates')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final templates = store.workouts;

    return Scaffold(
      appBar: AppBar(title: const Text('Start Workout')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Text('Quick Start',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            onPressed: _startEmpty,
            child: const Text('Start an Empty Workout'),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              const Expanded(
                child: Text('Templates',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: _createTemplate,
                icon: const Icon(Icons.add),
                label: const Text('Template'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionHeader(title: 'My Templates (${templates.length})'),
          const SizedBox(height: 12),
          if (templates.isEmpty)
            const _EmptyTemplates()
          else
            _CardGrid(
              children: [
                for (final w in templates)
                  _TemplateCard(
                    title: w.name,
                    exerciseNames: [
                      for (final we in w.exercises)
                        store.exerciseById(we.exerciseId)?.name ?? 'Deleted exercise',
                    ],
                    lastPerformed: store.lastPerformed(w.id),
                    onTap: () => _openTemplate(w),
                    menuItems: const [
                      PopupMenuItem(value: 'start', child: Text('Start workout')),
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                    onMenu: (action) => _onTemplateMenu(action, w),
                  ),
              ],
            ),
          const SizedBox(height: 32),
          _SectionHeader(
            title: 'Example Templates (${kExampleTemplates.length})',
            trailing: IconButton(
              tooltip: _showExamples ? 'Hide examples' : 'Show examples',
              icon: Icon(_showExamples ? Icons.expand_less : Icons.expand_more),
              onPressed: () => setState(() => _showExamples = !_showExamples),
            ),
          ),
          if (_showExamples) ...[
            const SizedBox(height: 12),
            _CardGrid(
              children: [
                for (final e in kExampleTemplates)
                  _TemplateCard(
                    title: e.name,
                    exerciseNames: e.exerciseNames,
                    lastPerformed: store.lastPerformed(e.id),
                    onTap: () => _openExample(e),
                    menuItems: const [
                      PopupMenuItem(value: 'preview', child: Text('Preview')),
                      PopupMenuItem(value: 'add', child: Text('Add to My Templates')),
                    ],
                    onMenu: (action) => _onExampleMenu(action, e),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        ?trailing,
      ],
    );
  }
}

class _EmptyTemplates extends StatelessWidget {
  const _EmptyTemplates();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: const Text(
        'No templates yet. Tap "+ Template", add an example below, or save a finished workout as a template.',
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}

/// Two-column grid where both cards in a row share the taller card's height.
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const gap = 12.0;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: gap),
            Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
          ],
        ),
      ));
      if (i + 2 < children.length) rows.add(const SizedBox(height: gap));
    }
    return Column(children: rows);
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.title,
    required this.exerciseNames,
    required this.lastPerformed,
    required this.onTap,
    required this.menuItems,
    required this.onMenu,
  });

  final String title;
  final List<String> exerciseNames;
  final DateTime? lastPerformed;
  final VoidCallback onTap;
  final List<PopupMenuEntry<String>> menuItems;
  final ValueChanged<String> onMenu;

  @override
  Widget build(BuildContext context) {
    final summary = exerciseNames.isEmpty ? 'No exercises' : exerciseNames.join(', ');
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 6, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Template options',
                    icon: const Icon(Icons.more_horiz, color: AppColors.accent),
                    onSelected: onMenu,
                    itemBuilder: (_) => menuItems,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(summary,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, height: 1.3)),
              ),
              const Spacer(),
              if (lastPerformed case final last?) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        formatDate(last),
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
