import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import 'dashboard_page.dart';
import 'setup_page.dart';
import 'theme.dart';
import 'widgets.dart';

const SystemUiOverlayStyle _systemBars = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarContrastEnforced: false,
);

class SpendingApp extends StatefulWidget {
  const SpendingApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<SpendingApp> createState() => _SpendingAppState();
}

class _SpendingAppState extends State<SpendingApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    widget.controller.start();
    // Coming back to the app shows fresh numbers, without polling in the background.
    _lifecycle = AppLifecycleListener(onResume: widget.controller.refreshIfStale);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: widget.controller,
      child: MaterialApp(
        title: 'Spending Tracker',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        // Light status and navigation bar icons over the dark app, drawn edge to edge.
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(value: _systemBars, child: child!),
        home: const _Home(),
      ),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    return switch (AppScope.of(context).phase) {
      Phase.starting => const Scaffold(), // a blank dark frame for the few ms it takes to read the token
      Phase.needsToken => const SetupPage(),
      Phase.ready => const DashboardPage(),
    };
  }
}
