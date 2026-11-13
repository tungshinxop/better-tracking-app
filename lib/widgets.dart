import 'package:material_ui/material_ui.dart';

import 'theme.dart';

class RirBadge extends StatelessWidget {
  const RirBadge(this.rir, {super.key, this.size = 30});

  final int rir;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forRir(rir);
    return Tooltip(
      message: '$rir reps in reserve',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(
          '$rir',
          style: TextStyle(
            color: color == AppColors.rirMid ? Colors.black : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: size * 0.5,
          ),
        ),
      ),
    );
  }
}

class SetNumberBubble extends StatelessWidget {
  const SetNumberBubble(this.number, {super.key, this.done = false});

  final int number;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? AppColors.success : AppColors.surfaceHigh,
        shape: BoxShape.circle,
      ),
      child: Text('$number',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
    );
  }
}

class MuscleChip extends StatelessWidget {
  const MuscleChip(this.label, {super.key, this.outlined = false});

  final String label;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(6),
        border: outlined ? Border.all(color: AppColors.outline) : null,
      ),
      child: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }
}

class ExerciseThumbnail extends StatelessWidget {
  const ExerciseThumbnail(this.name, {super.key, this.size = 64});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final hue = (name.hashCode % 360).abs().toDouble();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, hue, 0.45, 0.32).toColor(),
            HSLColor.fromAHSL(1, (hue + 40) % 360, 0.45, 0.22).toColor(),
          ],
        ),
      ),
      child: Text(initials,
          style: TextStyle(fontSize: size * 0.32, fontWeight: FontWeight.w600)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.subtitle});

  final String text;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!,
              style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
        ],
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: destructive
              ? TextButton.styleFrom(foregroundColor: AppColors.rirLow)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

String formatDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  if (hours > 0) return '$hours hr $minutes min';
  return '$minutes min';
}

String formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
