/// Keeps the home-screen widget current without opening the app.
///
/// About once an hour Android's WorkManager runs [backgroundCallback] in the
/// background: it fetches the statement from Wise, saves it to the cache (so the
/// app also opens on it) and redraws the widget. Offline, it redraws from the
/// cache instead, so "a day" still moves on after midnight. Android decides the
/// exact timing and may run it later while the phone dozes or battery saver is on.
library;

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'app_controller.dart';
import 'data/statement_cache.dart';
import 'data/token_store.dart';
import 'data/wise_api.dart';
import 'domain/pace.dart';
import 'home_screen_widget.dart';

const String _task = 'refresh-widget';

/// Asks Android to run the refresh about every hour. Android only; a failure here
/// never reaches the app.
Future<void> scheduleBackgroundRefresh() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await Workmanager().initialize(backgroundCallback);
    await Workmanager().registerPeriodicTask(
      _task,
      _task,
      frequency: const Duration(hours: 1),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  } on Object catch (e) {
    debugPrint('Background refresh not scheduled: $e');
  }
}

/// Where WorkManager starts the background task.
@pragma('vm:entry-point')
void backgroundCallback() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  Workmanager().executeTask((task, input) async {
    await refreshInBackground(
      tokens: const TokenStore(),
      cache: const StatementCache(),
      sourceFor: WiseApi.new,
      clock: DateTime.now,
      publish: updateHomeWidget,
    );
    return true; // the next run comes in an hour either way; no retries needed
  });
}

/// One background refresh. Does nothing until a token is saved.
Future<void> refreshInBackground({
  required TokenStore tokens,
  required StatementCache cache,
  required SourceFactory sourceFor,
  required DateTime Function() clock,
  required Future<void> Function(PayPeriod? period) publish,
}) async {
  final token = await tokens.read();
  if (token == null) return;
  final source = sourceFor(token);
  try {
    final statement = await source.fetchStatement();
    await cache.write(statement);
    await publish(payPeriod(statement, clock()));
  } on Object {
    // Offline, or Wise failed: the last statement still gives today's figure.
    final cached = await cache.read();
    if (cached != null) await publish(payPeriod(cached, clock()));
  } finally {
    source.close();
  }
}
