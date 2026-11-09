import 'dart:async';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../data/wise_api.dart';
import '../domain/format.dart';
import 'settings_sheet.dart';
import 'setup_page.dart';
import 'theme.dart';
import 'widgets.dart';

/// How fresh the numbers are: "Updated just now", "Updated 5 min ago". Ticks on by itself.
class UpdatedLabel extends StatefulWidget {
  const UpdatedLabel({super.key});

  @override
  State<UpdatedLabel> createState() => _UpdatedLabelState();
}

class _UpdatedLabelState extends State<UpdatedLabel> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return Semantics(liveRegion: true, child: Text(_status(c), style: Styles.meta));
  }

  static String _status(AppController c) {
    if (c.refreshing) return 'Updating…';
    final fetched = c.statement?.fetchedAt;
    if (fetched == null) return c.error != null ? 'Not updated yet' : '';
    return updatedLabel(fetched, now: c.now);
  }
}

/// ↻, with a spinner while it works. Pull to refresh and F5 do the same.
class RefreshButton extends StatelessWidget {
  const RefreshButton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return IconButton(
      tooltip: 'Update (F5)',
      onPressed: c.refreshing ? null : c.refresh,
      icon: c.refreshing
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.refresh),
    );
  }
}

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) =>
      IconButton(tooltip: 'Settings', onPressed: () => showSettingsSheet(context), icon: const Icon(Icons.tune));
}

/// A failed update: what happened, why, and what you're looking at meanwhile, with
/// the fix as a button. Shown on every tab, so it's seen wherever you pulled to refresh.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final error = c.error;
    if (error == null) return const SizedBox.shrink();
    final fetched = c.statement?.fetchedAt;
    final badToken = error.kind == WiseErrorKind.badToken;
    return Padding(
      padding: const EdgeInsets.only(top: Space.m),
      child: Notice(
        title: switch (error.kind) {
          WiseErrorKind.badToken => 'Token not accepted',
          WiseErrorKind.offline => "Couldn't reach Wise",
          WiseErrorKind.blocked => 'Wise blocked the request',
          WiseErrorKind.noBalance => 'No MYR balance found',
          WiseErrorKind.other => "Couldn't update",
        },
        lines: [
          error.message,
          if (fetched != null) 'Showing saved data from ${whenLabel(fetched, now: c.now)}',
        ],
        action: badToken ? 'Update token' : 'Try again',
        onAction: badToken ? () => openSetup(context, replacing: true) : c.refresh,
      ),
    );
  }
}

/// A tab's scrolling body: pull to refresh, the content centred at a readable width,
/// and room at the bottom.
class TabScroll extends StatelessWidget {
  const TabScroll({super.key, required this.slivers, this.maxWidth = 1200});

  final List<Widget> slivers;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return RefreshIndicator(
      onRefresh: c.refresh,
      color: Palette.accent,
      backgroundColor: Palette.card,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          for (final sliver in slivers)
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: context.sidePad(maxWidth)),
              sliver: sliver,
            ),
          const SliverToBoxAdapter(child: SizedBox(height: Space.xxl)),
        ],
      ),
    );
  }
}
