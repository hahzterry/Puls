import 'package:flutter/material.dart';

class PulsColors {
  static const ink = Color(0xFF05070A);
  static const panel = Color(0xFF0B1118);
  static const panelSoft = Color(0xFF101923);
  static const panelElevated = Color(0xFF151F2B);
  static const border = Color(0xFF253241);
  static const text = Color(0xFFF5F8FB);
  static const muted = Color(0xFF8A97A6);
  static const blue = Color(0xFF2F80FF);
  static const cyan = Color(0xFF24D1C7);
  static const green = Color(0xFF19C37D);
  static const coral = Color(0xFFFF5F6D);
  static const amber = Color(0xFFFFC857);
}

class PulsTheme {
  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: PulsColors.blue,
      brightness: Brightness.dark,
      surface: PulsColors.panel,
      primary: PulsColors.blue,
      secondary: PulsColors.cyan,
      error: PulsColors.coral,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: PulsColors.ink,
      colorScheme: colorScheme,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarThemeData(
        backgroundColor: PulsColors.ink,
        foregroundColor: PulsColors.text,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: PulsColors.panel,
        selectedItemColor: PulsColors.text,
        unselectedItemColor: PulsColors.muted,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: PulsColors.panel.withOpacity(0.96),
        indicatorColor: PulsColors.blue.withOpacity(0.18),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? PulsColors.text
                : PulsColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: PulsColors.panelSoft,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: PulsColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: PulsColors.border,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: PulsColors.panelSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: PulsColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: PulsColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: PulsColors.blue),
        ),
        hintStyle: const TextStyle(color: PulsColors.muted),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          color: PulsColors.text,
          fontSize: 34,
          fontWeight: FontWeight.w800,
          height: 1.02,
        ),
        headlineMedium: TextStyle(
          color: PulsColors.text,
          fontSize: 25,
          fontWeight: FontWeight.w800,
          height: 1.08,
        ),
        titleLarge: TextStyle(
          color: PulsColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: PulsColors.text,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: PulsColors.text,
          fontSize: 15,
          height: 1.35,
        ),
        bodyMedium: TextStyle(
          color: PulsColors.muted,
          fontSize: 13,
          height: 1.35,
        ),
        labelLarge: TextStyle(
          color: PulsColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
