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

abstract final class Styles {
  static const sectionTitle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Palette.text);
  static const rowName = TextStyle(fontSize: 15, color: Palette.text, height: 1.35);
  static const rowAmount = TextStyle(fontSize: 15, color: Palette.text, fontFeatures: tabular, height: 1.35);
  static const meta = TextStyle(fontSize: 13, color: Palette.muted, height: 1.35);
  static const desc = TextStyle(fontSize: 15, color: Palette.text2, height: 1.35);
  static const extra = TextStyle(fontSize: 14, color: Palette.muted, height: 1.35);
  static const body = TextStyle(fontSize: 15, color: Palette.text2, height: 1.45);
}

/// Spacing that adapts to the screen: a little tighter on small phones.
extension Spacing on BuildContext {
  double get _width => MediaQuery.sizeOf(this).width;

  /// Padding inside cards.
  double get pad => _width < 420 ? 18 : 22;

  /// Space between cards.
  double get gap => _width < 420 ? 14 : 16;

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
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: Palette.text2)),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Palette.input,
      labelStyle: TextStyle(color: Palette.muted),
      border: OutlineInputBorder(
        borderRadius: corners,
        borderSide: BorderSide(color: Palette.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: corners,
        borderSide: BorderSide(color: Palette.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: corners,
        borderSide: BorderSide(color: Palette.accent, width: 2),
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
