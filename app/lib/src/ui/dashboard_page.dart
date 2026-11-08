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

/// Wider than this, the overview and the lists sit side by side.
const double _wideLayout = 760;
const double _maxWidth = 1100;
const int _previewCount = 5;

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final summary = c.summary;
    final side = context.sidePad(_maxWidth);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f5): c.refresh,
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): c.refresh,
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): c.refresh,
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
                    padding: EdgeInsets.fromLTRB(side, Space.s, side - Space.s, 0),
                    sliver: const SliverToBoxAdapter(child: _Header()),
                  ),
                  if (c.error != null)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(side, Space.s, side, 0),
                      sliver: SliverToBoxAdapter(child: _ErrorNotice(error: c.error!)),
                    ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(side, context.gap, side, Space.xxl + bottom),
                    sliver: SliverToBoxAdapter(
                      // A short fade when switching months, so the change is noticed.
                      child: AnimatedSwitcher(
                        duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
                        child: summary != null
                            ? KeyedSubtree(
                                key: ValueKey(summary.start),
                                child: _Body(summary: summary, now: c.now),
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
    );
  }
}

/// The month picker, how fresh the data is, and the refresh and settings buttons.
class _Header extends StatefulWidget {
  const _Header();

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
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
    final now = c.now;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CyclePicker(cycles: c.cycles, selected: c.selectedCycle, now: now),
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Semantics(liveRegion: true, child: Text(_status(c, now), style: Styles.meta)),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Update (F5)',
          onPressed: c.refreshing ? null : c.refresh,
          icon: c.refreshing
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh),
        ),
        IconButton(tooltip: 'Settings', onPressed: () => showSettingsSheet(context), icon: const Icon(Icons.more_vert)),
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

class _CyclePicker extends StatelessWidget {
  const _CyclePicker({required this.cycles, required this.selected, required this.now});

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
      // At least 48dp tall, so it's an easy target for a thumb.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Heading(
                cycleLabel(selected, now: now),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Palette.text, height: 1.2),
              ),
            ),
            const SizedBox(width: Space.xs),
            const Icon(Icons.expand_more, color: Palette.muted),
          ],
        ),
      ),
    );
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
    final gap = SizedBox(height: context.gap);
    Widget card(List<Widget> boxes) => Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: boxes),
    );
    return Skeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          card(const [
            SkeletonBox(width: 0.6, height: 44),
            SizedBox(height: Space.m),
            SkeletonBox(width: 0.4, height: 14),
            SizedBox(height: Space.s),
            SkeletonBox(width: 0.3, height: 12),
          ]),
          gap,
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final i in [0, 1]) ...[
                  if (i > 0) SizedBox(width: context.gap),
                  Expanded(
                    child: card(const [
                      SkeletonBox(width: 0.7, height: 26),
                      SizedBox(height: Space.s),
                      SkeletonBox(width: 0.5, height: 12),
                    ]),
                  ),
                ],
              ],
            ),
          ),
          gap,
          card([
            const SkeletonBox(width: 0.35, height: 16),
            for (var i = 0; i < 3; i++) ...const [
              SizedBox(height: Space.xl),
              SkeletonBox(width: 1, height: 14),
              SizedBox(height: Space.s),
              SkeletonBox(width: 0.5, height: 10),
            ],
          ]),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.summary, required this.now});

  final CycleSummary summary;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final gap = SizedBox.square(dimension: context.gap);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideLayout;
        final categories = _categoriesCard(context);
        final places = _placesCard(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Overview(summary: summary, now: now, wide: wide),
            gap,
            if (wide)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: categories),
                    gap,
                    Expanded(child: places),
                  ],
                ),
              )
            else ...[
              categories,
              gap,
              places,
            ],
            gap,
            _transactionsCard(context),
          ],
        );
      },
    );
  }

  String get _label => cycleLabel(summary.start, now: now);

  Widget _categoriesCard(BuildContext context) => SectionCard(
    title: 'By category',
    total: summary.categories.length,
    empty: summary.isCurrent ? 'No spending yet this month.' : 'No spending this month.',
    onOpen: () => _open(context, CategoriesPage(summary: summary, label: _label)),
    rows: [
      for (final cat in summary.categories.take(_previewCount))
        InfoRow(
          name: cat.name,
          amount: rm(cat.cents),
          below: ShareBar(fraction: summary.spentCents == 0 ? 0 : cat.cents / summary.spentCents),
        ),
    ],
  );

  Widget _placesCard(BuildContext context) => SectionCard(
    title: 'Top places',
    total: summary.places.length,
    empty: 'No places yet.',
    onOpen: () => _open(context, PlacesPage(summary: summary, label: _label)),
    rows: [
      for (final p in summary.places.take(_previewCount))
        InfoRow(name: p.name, amount: rm(p.cents), lines: [plural(p.count, 'time')]),
    ],
  );

  Widget _transactionsCard(BuildContext context) => SectionCard(
    title: 'Transactions',
    total: summary.transactions.length,
    empty: 'No transactions yet.',
    onOpen: () => _open(context, TransactionsPage(summary: summary, label: _label, now: now)),
    rows: [for (final t in summary.transactions.take(_previewCount)) TxnRow(txn: t, now: now)],
  );

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

/// Left until payday, per day, spent this week and spent this month.
class _Overview extends StatelessWidget {
  const _Overview({required this.summary, required this.now, required this.wide});

  final CycleSummary summary;
  final DateTime now;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final gap = SizedBox.square(dimension: context.gap);
    final month = StatCard(
      cents: summary.spentCents,
      color: Palette.spend,
      lines: [
        summary.isCurrent ? 'spent this month' : 'spent in ${cycleLabel(summary.start, now: now)}',
        'avg ${rm(summary.avgPerDayCents)} a day',
      ],
    );
    final today = summary.today;
    if (today == null) return month;

    final balance = today.balanceCents;
    final hero = StatCard(
      hero: true,
      cents: balance,
      color: (balance ?? 0) < 0 ? Palette.spend : Palette.good,
      lines: ['left until ${dayMonth(today.nextPayday)}', '${plural(today.daysLeft, 'day')} left'],
    );
    final perDay = StatCard(cents: today.perDayCents, lines: const ['per day']);
    final week = StatCard(cents: today.weekCents, color: Palette.spend, lines: const ['spent this week']);

    Widget row(List<Widget> cards) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[if (i > 0) gap, Expanded(child: cards[i])],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: wide
          ? [
              hero,
              gap,
              row([perDay, week, month]),
            ]
          : [
              hero,
              gap,
              row([perDay, week]),
              gap,
              month,
            ],
    );
  }
}

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
