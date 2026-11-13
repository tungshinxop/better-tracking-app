import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'exercise_form_screen.dart';

enum ProgressMetric {
  estimatedOneRepMax('Est. 1RM', 'kg'),
  topWeight('Top weight', 'kg'),
  volume('Volume', 'kg'),
  bestReps('Best reps', 'reps');

  const ProgressMetric(this.label, this.unit);

  final String label;
  final String unit;

  double valueOf(ExerciseHistoryEntry entry) => switch (this) {
        ProgressMetric.estimatedOneRepMax => entry.bestEstimatedOneRepMax,
        ProgressMetric.topWeight => entry.topWeight,
        ProgressMetric.volume => entry.volume,
        ProgressMetric.bestReps => entry.bestReps.toDouble(),
      };
}

class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final String exerciseId;

  Future<void> _delete(BuildContext context, Exercise exercise) async {
    final store = context.read<AppStore>();
    final navigator = Navigator.of(context);
    final ok = await confirmDialog(context,
        title: 'Delete ${exercise.name}?',
        message: 'It will be removed from all workouts. Logged sets stay in your history.');
    if (!ok) return;
    navigator.pop();
    store.deleteExercise(exercise.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final exercise = store.exerciseById(exerciseId);
    if (exercise == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Exercise not found')));
    }
    final history = store.historyFor(exerciseId);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(exercise.name),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ExerciseFormScreen(exercise: exercise)));
                }
                if (value == 'delete') _delete(context, exercise);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit exercise')),
                PopupMenuItem(value: 'delete', child: Text('Delete exercise')),
              ],
            ),
          ],
          bottom: const TabBar(
            isScrollable: false,
            tabAlignment: TabAlignment.fill,
            tabs: [Tab(text: 'Info'), Tab(text: 'Progress'), Tab(text: 'History')],
          ),
        ),
        body: TabBarView(
          children: [
            _InfoTab(exercise: exercise, history: history),
            _ProgressTab(history: history),
            _HistoryTab(history: history),
          ],
        ),
      ),
    );
  }
}

class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.exercise, required this.history});

  final Exercise exercise;
  final List<ExerciseHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    final workouts = context.watch<AppStore>().workoutsUsing(exercise.id);
    final allSets = history.expand((h) => h.sets).toList();
    LoggedSet? bestE1rm;
    LoggedSet? heaviest;
    for (final s in allSets) {
      if (bestE1rm == null || s.estimatedOneRepMax > bestE1rm.estimatedOneRepMax) bestE1rm = s;
      if (heaviest == null || s.weight > heaviest.weight ||
          (s.weight == heaviest.weight && s.reps > heaviest.reps)) {
        heaviest = s;
      }
    }
    final bestVolume = history.isEmpty ? 0.0 : history.map((h) => h.volume).reduce(max);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            ExerciseThumbnail(exercise.name, size: 84),
            const SizedBox(width: 16),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: exercise.muscles.isEmpty
                    ? [const Text('No muscles set', style: TextStyle(color: AppColors.textSecondary))]
                    : [
                        for (var i = 0; i < exercise.muscles.length; i++)
                          MuscleChip(exercise.muscles[i], outlined: i >= 2),
                      ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const SectionTitle('Personal Records'),
        const SizedBox(height: 12),
        if (allSets.isEmpty)
          const Text('Log this exercise in a workout to see records.',
              style: TextStyle(color: AppColors.textSecondary))
        else
          _TwoColumnGrid(
            children: [
              _StatTile(
                  label: 'Est. 1RM',
                  value: '${formatWeight(bestE1rm!.estimatedOneRepMax)} kg',
                  detail: '${formatWeight(bestE1rm.weight)} kg × ${bestE1rm.reps} @ RIR ${bestE1rm.rir}'),
              _StatTile(
                  label: 'Heaviest set',
                  value: '${formatWeight(heaviest!.weight)} kg',
                  detail: '× ${heaviest.reps} reps'),
              _StatTile(
                  label: 'Best session volume',
                  value: '${formatWeight(bestVolume)} kg',
                  detail: 'weight × reps'),
              _StatTile(
                  label: 'Sessions logged',
                  value: '${history.length}',
                  detail: '${allSets.length} sets total'),
            ],
          ),
        const SizedBox(height: 28),
        const SectionTitle('Used in'),
        const SizedBox(height: 8),
        if (workouts.isEmpty)
          const Text('Not part of any workout.',
              style: TextStyle(color: AppColors.textSecondary))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final w in workouts) MuscleChip(w.name)],
          ),
        if (exercise.notes.isNotEmpty) ...[
          const SizedBox(height: 28),
          const SectionTitle('Notes'),
          const SizedBox(height: 8),
          Text(exercise.notes, style: const TextStyle(fontSize: 15, height: 1.4)),
        ],
      ],
    );
  }
}

class _TwoColumnGrid extends StatelessWidget {
  const _TwoColumnGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const gap = 12.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final c in children) SizedBox(width: width, child: c)],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.detail});

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ),
          Text(detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ProgressTab extends StatefulWidget {
  const _ProgressTab({required this.history});

  final List<ExerciseHistoryEntry> history;

  @override
  State<_ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<_ProgressTab> {
  ProgressMetric _metric = ProgressMetric.estimatedOneRepMax;

  @override
  Widget build(BuildContext context) {
    final history = widget.history;
    if (history.isEmpty) {
      return const EmptyState(
        icon: Icons.show_chart,
        title: 'No progress yet',
        message: 'Complete a workout with this exercise to start your progression graph.',
      );
    }

    final values = history.map(_metric.valueOf).toList();
    final first = values.first;
    final last = values.last;
    final change = last - first;
    final percent = first == 0 ? 0.0 : change / first * 100;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<ProgressMetric>(
            showSelectedIcon: false,
            segments: [
              for (final m in ProgressMetric.values)
                ButtonSegment(value: m, label: Text(m.label)),
            ],
            selected: {_metric},
            onSelectionChanged: (s) => setState(() => _metric = s.first),
          ),
        ),
        const SizedBox(height: 24),
        Text('${_formatValue(last)} ${_metric.unit}',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          history.length < 2
              ? 'Latest session'
              : '${change >= 0 ? '+' : ''}${_formatValue(change)} ${_metric.unit} '
                  '(${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%) since ${formatDate(history.first.date)}',
          style: TextStyle(
            color: history.length < 2
                ? AppColors.textSecondary
                : (change >= 0 ? AppColors.success : AppColors.rirLow),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(height: 260, child: _ProgressChart(history: history, values: values, metric: _metric)),
        const SizedBox(height: 12),
        if (_metric == ProgressMetric.estimatedOneRepMax)
          const Text(
            'Estimated 1RM uses the Epley formula and counts your RIR as extra reps: '
            'weight × (1 + (reps + RIR) / 30).',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
      ],
    );
  }

  String _formatValue(double v) =>
      _metric == ProgressMetric.bestReps ? v.toStringAsFixed(0) : formatWeight(double.parse(v.toStringAsFixed(1)));
}

class _ProgressChart extends StatelessWidget {
  const _ProgressChart({required this.history, required this.values, required this.metric});

  final List<ExerciseHistoryEntry> history;
  final List<double> values;
  final ProgressMetric metric;

  @override
  Widget build(BuildContext context) {
    final minY = values.reduce(min);
    final maxY = values.reduce(max);
    final padding = max((maxY - minY) * 0.15, maxY == 0 ? 1.0 : maxY * 0.05);
    final labelEvery = max(1, (history.length / 4).ceil());

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: max(1, history.length - 1).toDouble(),
        minY: max(0, minY - padding),
        maxY: maxY + padding,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.surfaceHigh, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max) return const SizedBox.shrink();
                return Text(value.toStringAsFixed(0),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (value != i.toDouble() || i < 0 || i >= history.length) {
                  return const SizedBox.shrink();
                }
                if (i % labelEvery != 0 && i != history.length - 1) {
                  return const SizedBox.shrink();
                }
                final d = history[i].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${d.day}/${d.month}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceHigh,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  '${spot.y.toStringAsFixed(metric == ProgressMetric.bestReps ? 0 : 1)} ${metric.unit}\n'
                  '${formatDate(history[spot.x.round()].date)}',
                  const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
            ],
            isCurved: true,
            preventCurveOverShooting: true,
            color: AppColors.accent,
            barWidth: 3,
            dotData: FlDotData(
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 4,
                color: AppColors.accent,
                strokeWidth: 2,
                strokeColor: AppColors.background,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.accent.withValues(alpha: 0.35),
                  AppColors.accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.history});

  final List<ExerciseHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: 'No history',
        message: 'Sets you log for this exercise will appear here.',
      );
    }
    final entries = history.reversed.toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final entry = entries[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(formatDate(entry.date),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  Text(entry.session.workoutName,
                      style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 8),
              for (var s = 0; s < entry.sets.length; s++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SetNumberBubble(s + 1),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${formatWeight(entry.sets[s].weight)} kg × ${entry.sets[s].reps}',
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      Text('e1RM ${entry.sets[s].estimatedOneRepMax.toStringAsFixed(1)}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(width: 10),
                      RirBadge(entry.sets[s].rir, size: 26),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
