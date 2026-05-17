import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

class PulsColors {
  static const blue = Color(0xFF2F80FF);
  static const cyan = Color(0xFF24D1C7);
  static const green = Color(0xFF19C37D);
  static const coral = Color(0xFFFF5F6D);
  static const amber = Color(0xFFFFC857);
}

@immutable
class PulsThemeColors extends ThemeExtension<PulsThemeColors> {
  const PulsThemeColors({
    required this.ink,
    required this.panel,
    required this.panelSoft,
    required this.panelElevated,
    required this.border,
    required this.text,
    required this.muted,
  });

  final Color ink;
  final Color panel;
  final Color panelSoft;
  final Color panelElevated;
  final Color border;
  final Color text;
  final Color muted;

  @override
  PulsThemeColors copyWith({
    Color? ink,
    Color? panel,
    Color? panelSoft,
    Color? panelElevated,
    Color? border,
    Color? text,
    Color? muted,
  }) {
    return PulsThemeColors(
      ink: ink ?? this.ink,
      panel: panel ?? this.panel,
      panelSoft: panelSoft ?? this.panelSoft,
      panelElevated: panelElevated ?? this.panelElevated,
      border: border ?? this.border,
      text: text ?? this.text,
      muted: muted ?? this.muted,
    );
  }

  @override
  PulsThemeColors lerp(ThemeExtension<PulsThemeColors>? other, double t) {
    if (other is! PulsThemeColors) {
      return this;
    }

    return PulsThemeColors(
      ink: Color.lerp(ink, other.ink, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      panelSoft: Color.lerp(panelSoft, other.panelSoft, t)!,
      panelElevated: Color.lerp(panelElevated, other.panelElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }
}

extension PulsThemeX on BuildContext {
  PulsThemeColors get puls {
    return Theme.of(this).extension<PulsThemeColors>()!;
  }
}

class PulsTheme {
  static const _darkTokens = PulsThemeColors(
    ink: Color(0xFF05070A),
    panel: Color(0xFF0B1118),
    panelSoft: Color(0xFF101923),
    panelElevated: Color(0xFF151F2B),
    border: Color(0xFF253241),
    text: Color(0xFFF5F8FB),
    muted: Color(0xFF8A97A6),
  );

  static const _lightTokens = PulsThemeColors(
    ink: Color(0xFFF5F7FB),
    panel: Color(0xFFFFFFFF),
    panelSoft: Color(0xFFF0F4F9),
    panelElevated: Color(0xFFE8EFF8),
    border: Color(0xFFD5DEEA),
    text: Color(0xFF09111F),
    muted: Color(0xFF607086),
  );

  static ThemeData dark() {
    return _build(
      FlexThemeData.dark(
        scheme: FlexScheme.blue,
        useMaterial3: true,
        subThemesData: const FlexSubThemesData(defaultRadius: 8),
        fontFamily: 'Roboto',
      ),
      _darkTokens,
    );
  }

  static ThemeData light() {
    return _build(
      FlexThemeData.light(
        scheme: FlexScheme.blue,
        useMaterial3: true,
        subThemesData: const FlexSubThemesData(defaultRadius: 8),
        fontFamily: 'Roboto',
      ),
      _lightTokens,
    );
  }

  static ThemeData _build(ThemeData base, PulsThemeColors tokens) {
    return base.copyWith(
      scaffoldBackgroundColor: tokens.ink,
      extensions: <ThemeExtension<dynamic>>[tokens],
      appBarTheme: AppBarThemeData(
        backgroundColor: tokens.ink,
        foregroundColor: tokens.text,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.panel.withValues(alpha: 0.96),
        indicatorColor: PulsColors.blue.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? tokens.text
                : tokens.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.panelSoft,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: tokens.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: tokens.border, thickness: 1),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: tokens.panelSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: PulsColors.blue),
        ),
        hintStyle: TextStyle(color: tokens.muted),
      ),
      textTheme: TextTheme(
        displaySmall: TextStyle(
          color: tokens.text,
          fontSize: 34,
          fontWeight: FontWeight.w800,
          height: 1.02,
        ),
        headlineMedium: TextStyle(
          color: tokens.text,
          fontSize: 25,
          fontWeight: FontWeight.w800,
          height: 1.08,
        ),
        titleLarge: TextStyle(
          color: tokens.text,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: tokens.text,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: tokens.text,
          fontSize: 15,
          height: 1.35,
        ),
        bodyMedium: TextStyle(
          color: tokens.muted,
          fontSize: 13,
          height: 1.35,
        ),
        labelLarge: TextStyle(
          color: tokens.text,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
