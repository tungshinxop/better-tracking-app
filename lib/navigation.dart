import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'active_workout.dart';
import 'models.dart';

class HomeTabs extends ChangeNotifier {
  static const workout = 0;
  static const current = 1;
  static const exercises = 2;
  static const history = 3;

  int _index = workout;

  int get index => _index;

  void go(int index) {
    if (index == _index) return;
    _index = index;
    notifyListeners();
  }
}

/// Starts [workout] (or resumes the one in progress) and shows the Current tab.
/// Pass a context that stays mounted, such as `Navigator.of(context).context`.
Future<void> beginWorkout(BuildContext context, Workout workout) async {
  final session = context.read<SessionController>();
  final tabs = context.read<HomeTabs>();
  final navigator = Navigator.of(context);

  if (session.isActive) {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Workout in progress'),
        content: Text(
            'You are in the middle of "${session.current!.name}". '
            'Resume it, or discard it and start "${workout.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE5202E)),
            child: const Text('Discard & start'),
          ),
          TextButton(onPressed: () => Navigator.pop(context, 'resume'), child: const Text('Resume')),
        ],
      ),
    );
    if (choice == 'resume') {
      navigator.popUntil((route) => route.isFirst);
      tabs.go(HomeTabs.current);
      return;
    }
    if (choice != 'discard') return;
  }

  session.start(workout);
  navigator.popUntil((route) => route.isFirst);
  tabs.go(HomeTabs.current);
}
