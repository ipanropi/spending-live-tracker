import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app_controller.dart';
import 'src/data/fake_source.dart';
import 'src/data/wise_api.dart';
import 'src/home_screen_widget.dart';
import 'src/ui/app.dart';

/// Builds with `--dart-define=FAKE_DATA=true` show made-up data and skip the
/// token screen, for screenshots. The compiler drops the fake code otherwise.
const bool _fakeData = bool.fromEnvironment('FAKE_DATA');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the status and navigation bars; the layout already pads for them.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final controller = AppController(
    sourceFor: _fakeData ? (_) => FakeSource() : WiseApi.new,
    skipToken: _fakeData,
    onPeriod: updateHomeWidget,
  );
  runApp(SpendingApp(controller: controller));
}
