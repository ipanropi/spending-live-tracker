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

  /// Spending faster than an even pace, or more than last month: a caution, not an alarm.
  static const warn = Color(0xFFFBBF24);

  /// Below zero. Red is kept for this, so it still means something when it shows.
  static const spend = Color(0xFFF87171);

  /// The square behind a category icon.
  static const tile = Color(0xFF242422);

  /// The tab bar and side rail.
  static const nav = Color(0xFF161615);
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

/// The type ramp. Big numbers come from [Spacing.heroSize];
/// everything else is one of these, so sizes stay consistent screen to screen.
abstract final class Styles {
  /// Screen and sheet titles.
  static const title = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Palette.text, height: 1.3);

  /// A screen's own title: Now, Activity, Spending.
  static const screenTitle = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Palette.text, height: 1.25);

  /// Section and card titles, and day headers in lists.
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

  /// Text set large enough (1.5× and up) that side-by-side rows should stack instead.
  bool get largeText => MediaQuery.textScalerOf(this).scale(10) >= 15;

  /// True when the user asked the system for less motion.
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);

  /// Side padding that keeps content at most [maxWidth] wide, centred.
  double sidePad(double maxWidth) => math.max(16, (_width - maxWidth) / 2);

  /// Size for a screen's headline number: scales with the screen, within limits.
  double get heroSize => (_width * 0.11).clamp(36, 48);
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
    // Filter chips: a quiet outline, filled when selected.
    chipTheme: const ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: corners,
        side: BorderSide(color: Palette.line),
      ),
      side: BorderSide(color: Palette.line),
      backgroundColor: Palette.bg,
      selectedColor: Palette.line,
      checkmarkColor: Palette.text,
      labelStyle: TextStyle(fontSize: 14, color: Palette.text),
      padding: EdgeInsets.symmetric(horizontal: Space.xs),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Palette.card,
      hintStyle: TextStyle(color: Palette.muted),
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
        borderSide: BorderSide(color: Palette.bar, width: 2),
      ),
    ),
    // Phones: a tab bar at the bottom, where thumbs reach. Wider windows: a rail on the left.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Palette.nav,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Palette.line,
      indicatorShape: _shape,
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
          color: states.contains(WidgetState.selected) ? Palette.text : Palette.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? Palette.text : Palette.muted),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Palette.nav,
      indicatorColor: Palette.line,
      indicatorShape: _shape,
      labelType: NavigationRailLabelType.all,
      selectedIconTheme: IconThemeData(color: Palette.text),
      unselectedIconTheme: IconThemeData(color: Palette.muted),
      selectedLabelTextStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Palette.text),
      unselectedLabelTextStyle: TextStyle(fontSize: 12, color: Palette.muted),
    ),
  );
}
