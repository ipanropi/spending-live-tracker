/// Keeps the Android home-screen widget in step with the app.
///
/// The widget is one tile filling a 1×1 cell: what you can spend today, as big as
/// it fits ("30" over "/day"), coloured by pace. What's left ("RM 365") is only
/// read out by screen readers. The app
/// works the numbers out and hands them over; the widget only draws them
/// (`android/app/src/main/kotlin/.../SpendingWidget.kt`), so it changes whenever the
/// app loads or refreshes its data.
library;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'domain/format.dart';
import 'domain/pace.dart';

/// What the widget shows, keyed the way `SpendingWidget.kt` reads it.
///
/// Both amounts are whole ringgit, cut down rather than rounded, so the widget never
/// shows more than is there: RM 365.60 left is "RM 365".
Map<String, String> widgetData(PayPeriod? period) {
  final balance = period?.balanceCents;
  final perDay = period?.perDayCents;
  if (period == null || balance == null || perDay == null) {
    return const {'perDay': '–', 'left': 'Spending', 'state': 'unknown'};
  }
  return {
    'perDay': _whole(perDay),
    'left': '${balance < 0 ? '−' : ''}RM ${_whole(balance)}',
    'state': period.state.name,
  };
}

/// 123456 → "1,234", -2040 → "20" (the caller adds the sign).
String _whole(int cents) {
  final (_, number) = rmParts(cents);
  return number.substring(0, number.length - 3);
}

/// Sends [period]'s figures to the widget. Android only; elsewhere it does nothing.
/// The widget is a nicety, so a failure here never reaches the app.
Future<void> updateHomeWidget(PayPeriod? period) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    for (final MapEntry(:key, :value) in widgetData(period).entries) {
      await HomeWidget.saveWidgetData<String>(key, value);
    }
    await HomeWidget.updateWidget(qualifiedAndroidName: 'com.ipanropi.spending_tracker.SpendingWidget');
  } on Object catch (e) {
    debugPrint('Home-screen widget not updated: $e');
  }
}
