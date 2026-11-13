import 'package:material_ui/material_ui.dart';

class AppColors {
  static const background = Color(0xFF1C1C1E);
  static const surface = Color(0xFF2A2A2D);
  static const surfaceHigh = Color(0xFF38383C);
  static const outline = Color(0xFF4A4A4F);
  static const accent = Color(0xFF2F6BFF);
  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFFB4B4BA);
  static const rirHigh = Color(0xFF34C759);
  static const rirMid = Color(0xFFFFB020);
  static const rirLow = Color(0xFFE5202E);
  static const success = Color(0xFF34C759);

  static Color forRir(int rir) {
    if (rir >= 4) return rirHigh;
    if (rir >= 2) return rirMid;
    return rirLow;
  }
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
      primary: AppColors.accent,
      surface: AppColors.background,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: AppColors.textPrimary,
      labelColor: AppColors.textPrimary,
      unselectedLabelColor: AppColors.textSecondary,
      dividerColor: AppColors.outline,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
      unselectedLabelStyle: TextStyle(fontSize: 17),
      tabAlignment: TabAlignment.start,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.textPrimary,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.surfaceHigh,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surfaceHigh,
      side: BorderSide.none,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.outline, thickness: 1),
  );
}
