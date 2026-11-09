import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The app's colours: dark only, with colour kept for the numbers that matter.
abstract final class Palette {
  static const bg = Color(0xFF111110);
  static const card = Color(0xFF1A1A19);
  static const input = Color(0xFF222220);
  static const line = Color(0xFF2F2F2C);
  static const text = Color(0xFFF0EFEC);
  static const text2 = Color(0xFFC3C2B7);
  static const muted = Color(0xFFA09F97);
  static const accent = Color(0xFF2563EB);
  static const bar = Color(0xFF3987E5);
  static const good = Color(0xFF4ADE80);
  static const spend = Color(0xFFF87171);
  static const errorBg = Color(0xFF2A1515);
  static const errorLine = Color(0xFF5C2424);
  static const errorText = Color(0xFFFCA5A5);
}

/// 4px corners everywhere: rounded, but not bubbly.
const BorderRadius corners = BorderRadius.all(Radius.circular(4));
const RoundedRectangleBorder _shape = RoundedRectangleBorder(borderRadius: corners);

/// Numbers line up in columns.
const List<FontFeature> tabular = [FontFeature.tabularFigures()];

/// One spacing scale on a 4-point grid, so gaps line up and repeat.
abstract final class Space {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// The type ramp. Big numbers come from [Spacing.heroSize] and [Spacing.statSize];
/// everything else is one of these, so sizes stay consistent screen to screen.
abstract final class Styles {
  /// Screen and sheet titles.
  static const title = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Palette.text, height: 1.3);

  /// Section headings, a level above card titles: the month picker.
  static const section = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Palette.text, height: 1.25);

  /// Card titles, and day headers in lists.
  static const sectionTitle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Palette.text, height: 1.3);

  static const rowName = TextStyle(fontSize: 15, color: Palette.text, height: 1.35);
  static const rowAmount = TextStyle(fontSize: 15, color: Palette.text, fontFeatures: tabular, height: 1.35);

  /// Secondary lines under a row: when, category, how often.
  static const meta = TextStyle(fontSize: 13, color: Palette.muted, height: 1.35);

  /// The phrase under an overview number.
  static const desc = TextStyle(fontSize: 15, color: Palette.text2, height: 1.35);

  /// Extra detail under that phrase.
  static const extra = TextStyle(fontSize: 14, color: Palette.muted, height: 1.35);

  static const body = TextStyle(fontSize: 15, color: Palette.text2, height: 1.45);
}

/// Spacing that adapts to the screen: a little tighter on small phones, roomier on computers.
extension Spacing on BuildContext {
  double get _width => MediaQuery.sizeOf(this).width;

  /// Padding inside cards.
  double get pad => _width < 380 ? Space.l : (_width < 600 ? 20 : Space.xl);

  /// Space between cards.
  double get gap => _width < 380 ? Space.m : Space.l;

  /// True when the user asked the system for less motion.
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);

  /// Side padding that keeps content at most [maxWidth] wide, centred.
  double sidePad(double maxWidth) => math.max(16, (_width - maxWidth) / 2);

  /// Size for the big "left" number: scales with the screen, within limits.
  double get heroSize => (_width * 0.11).clamp(36, 48);

  /// Size for the other overview numbers.
  double get statSize => (_width * 0.062).clamp(22, 30);
}

ThemeData buildTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  const scheme = ColorScheme.dark(
    primary: Palette.accent,
    onPrimary: Colors.white,
    secondary: Palette.bar,
    onSecondary: Colors.white,
    surface: Palette.card,
    onSurface: Palette.text,
    onSurfaceVariant: Palette.muted,
    surfaceContainerLowest: Palette.bg,
    surfaceContainerLow: Palette.card,
    surfaceContainer: Palette.card,
    surfaceContainerHigh: Palette.input,
    surfaceContainerHighest: Palette.input,
    outline: Palette.line,
    outlineVariant: Palette.line,
    error: Palette.spend,
    onError: Palette.bg,
  );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.bg,
    canvasColor: Palette.bg,
    textTheme: base.textTheme.apply(bodyColor: Palette.text, displayColor: Palette.text),
    dividerTheme: const DividerThemeData(color: Palette.line, thickness: 1, space: 1),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.bg,
      foregroundColor: Palette.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: _shape,
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: _shape, foregroundColor: Palette.text),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: _shape,
        foregroundColor: Palette.text,
        side: const BorderSide(color: Palette.line),
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Palette.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: corners,
        side: BorderSide(color: Palette.line),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(4))),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Palette.card,
      surfaceTintColor: Colors.transparent,
      shape: _shape,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Palette.bar),
  );
}
