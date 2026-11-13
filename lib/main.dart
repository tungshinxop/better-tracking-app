import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'active_workout.dart';
import 'navigation.dart';
import 'rest_alerts.dart';
import 'screens/current_workout_screen.dart';
import 'screens/exercises_screen.dart';
import 'screens/history_screen.dart';
import 'screens/workouts_screen.dart';
import 'store.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  final session = SessionController(store, alerts: NotificationRestAlerts());
  store.load().then((_) => session.restore());
  runApp(BetterTrackingApp(store: store, session: session));
}

class BetterTrackingApp extends StatelessWidget {
  const BetterTrackingApp({super.key, required this.store, required this.session});

  final AppStore store;
  final SessionController session;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider(create: (_) => HomeTabs()),
      ],
      child: MaterialApp(
        title: 'Better Tracking',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const HomeShell(),
      ),
    );
  }
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final loaded = context.select<AppStore, bool>((s) => s.loaded);
    if (!loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final tabs = context.watch<HomeTabs>();
    final active = context.select<SessionController, bool>((s) => s.isActive);

    return Scaffold(
      body: IndexedStack(
        index: tabs.index,
        children: const [
          WorkoutsScreen(),
          CurrentWorkoutScreen(),
          ExercisesScreen(),
          HistoryScreen(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active && tabs.index != HomeTabs.current) const ResumeWorkoutBar(),
          NavigationBar(
            selectedIndex: tabs.index,
            onDestinationSelected: tabs.go,
            destinations: [
              const NavigationDestination(
                  icon: Icon(Icons.fitness_center_outlined),
                  selectedIcon: Icon(Icons.fitness_center),
                  label: 'Workout'),
              NavigationDestination(
                  icon: Badge(
                      isLabelVisible: active,
                      backgroundColor: AppColors.success,
                      child: const Icon(Icons.timer_outlined)),
                  selectedIcon: Badge(
                      isLabelVisible: active,
                      backgroundColor: AppColors.success,
                      child: const Icon(Icons.timer)),
                  label: 'Current'),
              const NavigationDestination(
                  icon: Icon(Icons.list_alt_outlined),
                  selectedIcon: Icon(Icons.list_alt),
                  label: 'Exercises'),
              const NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: 'History'),
            ],
          ),
        ],
      ),
    );
  }
}
