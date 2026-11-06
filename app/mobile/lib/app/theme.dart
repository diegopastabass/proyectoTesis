/// Paleta Gruvbox (aqua como color principal) con patrones de iOS: fondo
/// agrupado con tarjetas encima, esquinas continuas, transiciones de iOS y
/// movimiento con resortes (ver `Motion`).
library;

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../core/nutrition/models.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.canvas,
    required this.card,
    required this.bg,
    required this.bgHard,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.borderStrong,
    required this.fg,
    required this.fgStrong,
    required this.muted,
    required this.faint,
    required this.primary,
    required this.primary2,
    required this.onPrimary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.chartLine,
  });

  static const dark = AppColors(
    canvas: Color(0xFF1D2021),
    card: Color(0xFF32302F),
    bg: Color(0xFF282828),
    bgHard: Color(0xFF1D2021),
    surface: Color(0xFF32302F),
    surface2: Color(0xFF3C3836),
    border: Color(0xFF504945),
    borderStrong: Color(0xFF665C54),
    fg: Color(0xFFEBDBB2),
    fgStrong: Color(0xFFFBF1C7),
    muted: Color(0xFFA89984),
    faint: Color(0xFF7C6F64),
    primary: Color(0xFF8EC07C),
    primary2: Color(0xFF83A598),
    onPrimary: Color(0xFF1D2021),
    success: Color(0xFFB8BB26),
    warning: Color(0xFFFABD2F),
    danger: Color(0xFFFB4934),
    kcal: Color(0xFFFE8019),
    protein: Color(0xFFD3869B),
    carbs: Color(0xFFFABD2F),
    fat: Color(0xFFB8BB26),
    fiber: Color(0xFF83A598),
    chartLine: Color(0xFF68A258),
  );

  static const light = AppColors(
    canvas: Color(0xFFF2E5BC),
    card: Color(0xFFF9F5D7),
    bg: Color(0xFFFBF1C7),
    // Pistas y pozos dentro de las tarjetas: más oscuro que la tarjeta, como en el tema oscuro.
    bgHard: Color(0xFFEDE0B6),
    surface: Color(0xFFF2E5BC),
    surface2: Color(0xFFEBDBB2),
    border: Color(0xFFD5C4A1),
    borderStrong: Color(0xFFBDAE93),
    fg: Color(0xFF3C3836),
    fgStrong: Color(0xFF282828),
    muted: Color(0xFF7C6F64),
    faint: Color(0xFFA89984),
    primary: Color(0xFF427B58),
    primary2: Color(0xFF076678),
    onPrimary: Color(0xFFFBF1C7),
    success: Color(0xFF79740E),
    warning: Color(0xFFB57614),
    danger: Color(0xFF9D0006),
    kcal: Color(0xFFAF3A03),
    protein: Color(0xFF8F3F71),
    carbs: Color(0xFFB57614),
    fat: Color(0xFF79740E),
    fiber: Color(0xFF076678),
    chartLine: Color(0xFF3F8A4F),
  );

  /// Fondo de las pantallas (como el fondo agrupado de iOS).
  final Color canvas;

  /// Tarjetas y listas sobre el fondo.
  final Color card;
  final Color bg;
  final Color bgHard;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color borderStrong;
  final Color fg;
  final Color fgStrong;
  final Color muted;
  final Color faint;
  final Color primary;
  final Color primary2;
  final Color onPrimary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color kcal;
  final Color protein;
  final Color carbs;
  final Color fat;
  final Color fiber;
  final Color chartLine;

  Color get primarySoft => primary.withValues(alpha: 0.14);

  LinearGradient get gradient => LinearGradient(colors: [primary, primary2], begin: Alignment.topLeft, end: Alignment.bottomRight);

  Color macro(MacroKey k) => switch (k) {
        MacroKey.kcal => kcal,
        MacroKey.protein => protein,
        MacroKey.carbs => carbs,
        MacroKey.fat => fat,
        MacroKey.fiber => fiber,
      };

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) => t < 0.5 || other is! AppColors ? this : other;
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

/// Esquinas continuas (squircle) de iOS.
OutlinedBorder smoothShape(double radius) => RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(radius));

/// Movimiento al estilo iOS (Designing Fluid Interfaces, WWDC 2018).
///
/// Los resortes se describen con los dos parámetros de Apple: amortiguación
/// (1 = sin rebote) y respuesta (segundos hasta llegar, más bajo = más ágil).
abstract final class Motion {
  /// Resorte de Apple en términos de Flutter (masa 1).
  static SpringDescription spring({double damping = 1, double response = 0.35}) => SpringDescription(
        mass: 1,
        stiffness: math.pow(2 * math.pi / response, 2).toDouble(),
        damping: 4 * math.pi * damping / response,
      );

  /// Interfaz en general: sin rebote, se asienta suave.
  static const standard = SpringCurve(damping: 1, response: 0.35, seconds: 0.5);

  /// Solo cuando el gesto trae impulso o es una celebración: un poco de rebote.
  static const bouncy = SpringCurve(damping: 0.75, response: 0.4, seconds: 0.7);

  static const fast = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 320);
  static const standardDuration = Duration(milliseconds: 500);
  static const bouncyDuration = Duration(milliseconds: 700);

  /// "Reducir movimiento" de iOS: sin desplazamientos ni rebotes, solo fundidos.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Curva que sigue un resorte; para animaciones implícitas (AnimatedContainer…).
/// `seconds` debe coincidir con la duración de la animación.
class SpringCurve extends Curve {
  const SpringCurve({this.damping = 1, this.response = 0.35, this.seconds = 0.5});

  final double damping;
  final double response;
  final double seconds;

  @override
  double transformInternal(double t) => SpringSimulation(Motion.spring(damping: damping, response: response), 0, 1, 0).x(t * seconds);
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    secondary: c.primary2,
    onSecondary: c.onPrimary,
    error: c.danger,
    onError: c.onPrimary,
    surface: c.bg,
    onSurface: c.fg,
    surfaceContainerLowest: c.bgHard,
    surfaceContainerLow: c.surface,
    surfaceContainer: c.surface,
    surfaceContainerHigh: c.surface2,
    surfaceContainerHighest: c.surface2,
    onSurfaceVariant: c.muted,
    outline: c.border,
    outlineVariant: c.border,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  final field = OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none);
  final text = base.textTheme.apply(bodyColor: c.fg, displayColor: c.fgStrong);
  // Tracking según el tamaño: negativo en títulos grandes, casi cero en el texto.
  TextStyle? track(TextStyle? s, double spacing, [FontWeight? weight]) => s?.copyWith(letterSpacing: spacing, fontWeight: weight);
  const buttonText = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2);
  return base.copyWith(
    scaffoldBackgroundColor: c.canvas,
    extensions: [c],
    // Sin la onda de Material: en iOS lo que se toca se ilumina o se achica.
    splashFactory: NoSplash.splashFactory,
    highlightColor: c.fg.withValues(alpha: 0.06),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      // Deslizamiento de iOS y gesto para volver desde el borde, en todas las plataformas.
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
    }),
    cupertinoOverrideTheme: CupertinoThemeData(primaryColor: c.primary, brightness: brightness, scaffoldBackgroundColor: c.canvas),
    dividerTheme: DividerThemeData(color: c.border.withValues(alpha: 0.6), space: 1, thickness: 0.5),
    textTheme: text.copyWith(
      displaySmall: track(text.displaySmall, -0.8, FontWeight.w700),
      headlineMedium: track(text.headlineMedium, -0.6, FontWeight.w700),
      headlineSmall: track(text.headlineSmall, -0.5, FontWeight.w700),
      titleLarge: track(text.titleLarge, -0.4, FontWeight.w600),
      titleMedium: track(text.titleMedium, -0.3, FontWeight.w600),
      bodyLarge: track(text.bodyLarge, -0.2),
      bodyMedium: track(text.bodyMedium, -0.1),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.canvas,
      foregroundColor: c.fgStrong,
      // Explícito: con fondo transparente, Flutter deduce íconos claros y no se leen en el tema claro.
      systemOverlayStyle: brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: c.fgStrong),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface2.withValues(alpha: 0.7),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: field,
      enabledBorder: field,
      focusedBorder: field.copyWith(borderSide: BorderSide(color: c.primary, width: 1.5)),
      errorBorder: field.copyWith(borderSide: BorderSide(color: c.danger)),
      hintStyle: TextStyle(color: c.faint),
      labelStyle: TextStyle(color: c.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        minimumSize: const Size(64, 46),
        shape: smoothShape(14),
        textStyle: buttonText,
        animationDuration: Motion.fast,
      ),
    ),
    // Botón secundario de iOS: relleno gris y texto de color, sin borde.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.fgStrong,
        backgroundColor: c.surface2.withValues(alpha: 0.8),
        side: BorderSide.none,
        minimumSize: const Size(64, 46),
        shape: smoothShape(14),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.primary, textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surface2.withValues(alpha: 0.6),
      selectedColor: c.primary,
      side: BorderSide.none,
      labelStyle: TextStyle(color: c.fg, fontSize: 13),
      secondaryLabelStyle: TextStyle(color: c.onPrimary, fontSize: 13, fontWeight: FontWeight.w600),
      shape: const StadiumBorder(),
      showCheckmark: false,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.surface2,
      contentTextStyle: TextStyle(color: c.fgStrong, fontSize: 14, fontWeight: FontWeight.w500),
      shape: smoothShape(16),
      elevation: 6,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.canvas,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: c.borderStrong,
      dragHandleSize: const Size(36, 5),
      shape: const RoundedSuperellipseBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dialogTheme: DialogThemeData(backgroundColor: c.card, surfaceTintColor: Colors.transparent, shape: smoothShape(22)),
    sliderTheme: SliderThemeData(activeTrackColor: c.primary, thumbColor: Colors.white, inactiveTrackColor: c.surface2, trackHeight: 4),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary : c.surface2),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    listTileTheme: ListTileThemeData(iconColor: c.muted, textColor: c.fg),
  );
}
