import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../data/wise_api.dart';
import '../domain/format.dart';
import '../domain/models.dart';
import '../domain/summary.dart';
import 'detail_pages.dart';
import 'settings_sheet.dart';
import 'setup_page.dart';
import 'theme.dart';
import 'widgets.dart';

/// Wider than this, the wallet runs across one row, and the month's breakdown and
/// its transactions sit side by side.
const double _wideLayout = 760;
const double _maxWidth = 1100;

/// Rows previewed on the dashboard. The rest are one labelled tap away.
const int _previewCount = 3;

/// The dashboard reads top to bottom in the order the questions come up: what's
/// left until payday, what this month has cost, where it went, and the
/// transactions behind it. Everything below the month picker belongs to that month.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final summary = c.summary;
    final side = context.sidePad(_maxWidth);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final current = c.showingCurrent;

    return PopScope(
      // In an earlier month, back returns to the current one before it leaves the app.
      canPop: current,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) c.showCurrent();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.f5): c.refresh,
          const SingleActivator(LogicalKeyboardKey.keyR, control: true): c.refresh,
          const SingleActivator(LogicalKeyboardKey.keyR, meta: true): c.refresh,
          if (!current) const SingleActivator(LogicalKeyboardKey.escape): c.showCurrent,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: SafeArea(
              bottom: false,
              child: RefreshIndicator(
                onRefresh: c.refresh,
                color: Palette.accent,
                backgroundColor: Palette.card,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(side, Space.xs, side - Space.s, 0),
                      sliver: const SliverToBoxAdapter(child: _TopBar()),
                    ),
                    if (c.error != null)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(side, Space.xs, side, 0),
                        sliver: SliverToBoxAdapter(child: _ErrorNotice(error: c.error!)),
                      ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(side, Space.m, side, Space.xxl + bottom),
                      sliver: SliverToBoxAdapter(
                        // A short fade when switching months, so the change is noticed.
                        child: AnimatedSwitcher(
                          duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
                          child: summary != null
                              ? KeyedSubtree(
                                  key: ValueKey(summary.start),
                                  child: _Body(summary: summary, cycles: c.cycles, now: c.now),
                                )
                              : (c.refreshing ? const _LoadingBody() : const SizedBox.shrink()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How fresh the numbers are, with the refresh and settings buttons. Status sits
/// at the top where it's seen; nothing you use often has to be reached up here,
/// since pull to refresh does the same as the button.
class _TopBar extends StatefulWidget {
  const _TopBar();

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    // "Updated 3 min ago" has to tick on by itself.
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
    return Row(
      children: [
        Expanded(
          child: Semantics(liveRegion: true, child: Text(_status(c, c.now), style: Styles.meta)),
        ),
        IconButton(
          tooltip: 'Update (F5)',
          onPressed: c.refreshing ? null : c.refresh,
          icon: c.refreshing
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: 'Settings',
          onPressed: () => showSettingsSheet(context),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }

  static String _status(AppController c, DateTime now) {
    if (c.refreshing) return 'Updating…';
    final fetched = c.statement?.fetchedAt;
    if (fetched == null) return c.error != null ? 'Not updated yet' : '';
    return updatedLabel(fetched, now: now);
  }
}

/// What went wrong, why, and what you're looking at meanwhile, with the fix as a button.
class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.error});

  final WiseException error;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final fetched = c.statement?.fetchedAt;
    final badToken = error.kind == WiseErrorKind.badToken;
    return Notice(
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
    );
  }
}

/// The dashboard's shape while the first data loads.
class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    const figure = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(width: 0.7, height: 26),
        SizedBox(height: Space.s),
        SkeletonBox(width: 0.6, height: 12),
      ],
    );
    return Skeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 0.6, height: 44),
                SizedBox(height: Space.m),
                SkeletonBox(width: 0.4, height: 14),
                SizedBox(height: Space.s),
                SkeletonBox(width: 0.3, height: 12),
                SizedBox(height: Space.l),
                Divider(),
                SizedBox(height: Space.l),
                Row(
                  children: [
                    Expanded(child: figure),
                    SizedBox(width: Space.l),
                    Expanded(child: figure),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          const SkeletonBox(width: 0.4, height: 20),
          const SizedBox(height: Space.l),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 0.45, height: 26),
                const SizedBox(height: Space.s),
                const SkeletonBox(width: 0.35, height: 12),
                for (var i = 0; i < 3; i++) ...const [
                  SizedBox(height: Space.xl),
                  SkeletonBox(width: 1, height: 14),
                  SizedBox(height: Space.s),
                  SkeletonBox(width: 0.5, height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.summary, required this.cycles, required this.now});

  final CycleSummary summary;
  final List<DateTime> cycles;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideLayout;
        final today = summary.today;
        final month = _MonthPanel(summary: summary, now: now, fill: wide);
        final transactions = _TransactionsPanel(summary: summary, now: now, fill: wide);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (today != null) _WalletPanel(today: today, now: now, wide: wide) else _BackToCurrent(wide: wide),
            // More space between "now" and "this month" than anywhere inside either.
            const SizedBox(height: Space.xl),
            Align(
              alignment: Alignment.centerLeft,
              child: _MonthPicker(cycles: cycles, selected: summary.start, now: now),
            ),
            const SizedBox(height: Space.s),
            if (wide)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: month),
                    SizedBox(width: context.gap),
                    Expanded(child: transactions),
                  ],
                ),
              )
            else ...[
              month,
              SizedBox(height: context.gap),
              transactions,
            ],
          ],
        );
      },
    );
  }
}

/// The wallet right now: left until payday, the most important number on the
/// screen, then the pace. One panel, because the three answer one question.
class _WalletPanel extends StatelessWidget {
  const _WalletPanel({required this.today, required this.now, required this.wide});

  final Today today;
  final DateTime now;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final balance = today.balanceCents;
    final left = Figure(
      hero: true,
      cents: balance,
      color: (balance ?? 0) < 0 ? Palette.spend : Palette.good,
      lines: ['left until ${dayMonth(today.nextPayday)}', '${plural(today.daysLeft, 'day')} left'],
    );
    final perDay = Figure(cents: today.perDayCents, lines: const ['to spend a day']);
    final week = Figure(
      cents: today.weekCents,
      color: Palette.spend,
      lines: [
        'spent this week',
        sinceLabel(today.weekStart, now: now),
      ],
    );

    if (wide) {
      return Panel(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: left),
              const VerticalDivider(width: Space.xxl),
              Expanded(flex: 2, child: perDay),
              const VerticalDivider(width: Space.xxl),
              Expanded(flex: 2, child: week),
            ],
          ),
        ),
      );
    }
    // With large text the two smaller figures stack instead of squeezing side by side.
    final stack = MediaQuery.textScalerOf(context).scale(10) >= 15;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          left,
          const SizedBox(height: Space.l),
          const Divider(),
          const SizedBox(height: Space.l),
          if (stack) ...[
            perDay,
            const SizedBox(height: Space.l),
            week,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: perDay),
                const SizedBox(width: Space.l),
                Expanded(child: week),
              ],
            ),
        ],
      ),
    );
  }
}

/// In an earlier month the wallet isn't shown, since it's about today. This is the
/// way back, in the same place.
class _BackToCurrent extends StatelessWidget {
  const _BackToCurrent({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton.icon(
      onPressed: AppScope.read(context).showCurrent,
      icon: const Icon(Icons.arrow_back, size: 20),
      label: const Text('Back to current month'),
    );
    return wide ? Align(alignment: Alignment.centerLeft, child: button) : button;
  }
}

/// Chooses the month for everything below it. It sits with the month, not at the
/// top of the screen, because the wallet above is always about today.
class _MonthPicker extends StatelessWidget {
  const _MonthPicker({required this.cycles, required this.selected, required this.now});

  final List<DateTime> cycles;
  final DateTime selected;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DateTime>(
      tooltip: 'Choose month',
      initialValue: selected,
      onSelected: (start) {
        HapticFeedback.selectionClick();
        AppScope.read(context).selectCycle(start);
      },
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        for (final start in cycles)
          PopupMenuItem(
            value: start,
            child: Row(
              children: [
                Expanded(child: Text(cycleLabel(start, now: now))),
                if (start == selected) const Icon(Icons.check, size: 18, color: Palette.bar),
              ],
            ),
          ),
      ],
      // At least 48dp tall, so it's an easy target. A heading, and a button.
      child: Semantics(
        button: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Heading(cycleLabel(selected, now: now), style: Styles.title),
              ),
              const SizedBox(width: Space.xs),
              const Icon(Icons.expand_more, color: Palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Breakdown { categories, places }

/// The month: what it cost, then where it went, by category or by place.
class _MonthPanel extends StatefulWidget {
  const _MonthPanel({required this.summary, required this.now, required this.fill});

  final CycleSummary summary;
  final DateTime now;

  /// Beside another panel of the same height: keep "View all" at the bottom.
  final bool fill;

  @override
  State<_MonthPanel> createState() => _MonthPanelState();
}

class _MonthPanelState extends State<_MonthPanel> {
  _Breakdown _by = _Breakdown.categories;

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final label = cycleLabel(s.start, now: widget.now);
    final byCategory = _by == _Breakdown.categories;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Figure(
            cents: s.spentCents,
            color: Palette.spend,
            lines: [s.isCurrent ? 'spent this month' : 'spent that month', 'avg ${rm(s.avgPerDayCents)} a day'],
          ),
          const SizedBox(height: Space.l),
          const Divider(),
          const SizedBox(height: Space.l),
          if (s.categories.isEmpty)
            Text(s.isCurrent ? 'No spending yet this month.' : 'No spending this month.', style: Styles.meta)
          else ...[
            // One section for "where it went", switched between its two views,
            // instead of two long lists in a row.
            ChoiceSwitch<_Breakdown>(
              options: const [(_Breakdown.categories, 'Categories'), (_Breakdown.places, 'Places')],
              selected: _by,
              onChanged: (by) {
                HapticFeedback.selectionClick();
                setState(() => _by = by);
              },
            ),
            const SizedBox(height: Space.xs),
            RowList(
              rows: byCategory
                  ? [
                      for (final cat in s.categories.take(_previewCount))
                        InfoRow(
                          name: cat.name,
                          amount: rm(cat.cents),
                          below: ShareBar(fraction: s.spentCents == 0 ? 0 : cat.cents / s.spentCents),
                        ),
                    ]
                  : [
                      for (final p in s.places.take(_previewCount))
                        InfoRow(name: p.name, amount: rm(p.cents), lines: [plural(p.count, 'time')]),
                    ],
            ),
            if (widget.fill) const Spacer(),
            const Divider(),
            ViewAllButton(
              byCategory ? 'View all categories' : 'View all places',
              onPressed: () => _open(
                context,
                byCategory ? CategoriesPage(summary: s, label: label) : PlacesPage(summary: s, label: label),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The month's transactions, newest first: the latest few here, all of them one tap away.
class _TransactionsPanel extends StatelessWidget {
  const _TransactionsPanel({required this.summary, required this.now, required this.fill});

  final CycleSummary summary;
  final DateTime now;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final latest = s.transactions.take(_previewCount).toList();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Heading('Transactions'),
          if (latest.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.l),
              child: Text(s.isCurrent ? 'No transactions yet.' : 'No transactions this month.', style: Styles.meta),
            )
          else ...[
            const SizedBox(height: Space.xs),
            RowList(
              rows: [for (final t in latest) TxnRow(txn: t, now: now)],
            ),
            if (fill) const Spacer(),
            const Divider(),
            ViewAllButton(
              'View all transactions',
              onPressed: () => _open(
                context,
                TransactionsPage(
                  summary: s,
                  label: cycleLabel(s.start, now: now),
                  now: now,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

void _open(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

/// A transaction row: name and amount, then when, then the category, then a
/// useful note. Inside a day group, "when" is just the time.
class TxnRow extends StatelessWidget {
  const TxnRow({super.key, required this.txn, required this.now, this.full = false, this.timeOnly = false});

  final Txn txn;
  final DateTime now;
  final bool full;
  final bool timeOnly;

  @override
  Widget build(BuildContext context) {
    final moneyIn = !txn.isSpending;
    final note = txn.note;
    // Card notes ("Card transaction of 12.50 MYR issued by …") only repeat the row.
    final usefulNote =
        full &&
        note.isNotEmpty &&
        note.toLowerCase() != txn.name.toLowerCase() &&
        !note.toLowerCase().startsWith('card transaction of ');
    return InfoRow(
      name: txn.name,
      amount: '${moneyIn ? '+' : ''}${rm(txn.cents.abs())}',
      amountColor: moneyIn ? Palette.good : null,
      lines: [
        timeOnly ? time12(txn.date) : whenLabel(txn.date, now: now),
        txn.category,
        if (usefulNote) note,
      ],
    );
  }
}

/// Opens the token screen on top of the dashboard.
void openSetup(BuildContext context, {bool replacing = false}) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => SetupPage(replacing: replacing), fullscreenDialog: true));
