import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../data/wise_api.dart';
import '../domain/cycles.dart';
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
                    padding: EdgeInsets.fromLTRB(side, 16, side - 8, 0),
                    sliver: const SliverToBoxAdapter(child: _Header()),
                  ),
                  if (c.error != null)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(side, 12, side, 0),
                      sliver: SliverToBoxAdapter(child: _ErrorNotice(error: c.error!)),
                    ),
                  if (summary == null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: c.refreshing ? const _Loading() : const SizedBox.shrink(),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(side, context.gap, side, 32 + bottom),
                      sliver: SliverToBoxAdapter(
                        child: _Body(summary: summary, now: c.now),
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

/// The month picker, when the data was last updated, and the refresh and settings buttons.
class _Header extends StatelessWidget {
  const _Header();

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
    final sameDay = dateOnly(fetched) == dateOnly(now);
    return 'Updated ${sameDay ? '' : '${dayMonth(fetched)}, '}${time12(fetched)}';
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
      onSelected: AppScope.read(context).selectCycle,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                cycleLabel(selected, now: now),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Palette.text),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, color: Palette.muted),
          ],
        ),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.error});

  final WiseException error;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.read(context);
    final badToken = error.kind == WiseErrorKind.badToken;
    return Notice(
      message: error.message,
      action: badToken ? 'Update token' : 'Try again',
      onAction: badToken ? () => openSetup(context, replacing: true) : c.refresh,
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading from Wise…', style: Styles.meta),
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
    empty: 'No spending yet.',
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
    empty: 'Nothing yet.',
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
    onOpen: () => _open(context, TransactionsPage(summary: summary, label: _label)),
    rows: [for (final t in summary.transactions.take(_previewCount)) TxnRow(txn: t)],
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
      value: rm(summary.spentCents),
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
      value: balance == null ? '–' : rm(balance),
      color: (balance ?? 0) < 0 ? Palette.spend : Palette.good,
      lines: ['left until ${dayMonth(today.nextPayday)}', '${plural(today.daysLeft, 'day')} left'],
    );
    final perDay = StatCard(value: today.perDayCents == null ? '–' : rm(today.perDayCents!), lines: const ['per day']);
    final week = StatCard(value: rm(today.weekCents), color: Palette.spend, lines: const ['spent this week']);

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
/// useful note in the full list.
class TxnRow extends StatelessWidget {
  const TxnRow({super.key, required this.txn, this.full = false});

  final Txn txn;
  final bool full;

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
      lines: [weekdayDateTime(txn.date), txn.category, if (usefulNote) note],
    );
  }
}

/// Opens the token screen on top of the dashboard.
void openSetup(BuildContext context, {bool replacing = false}) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => SetupPage(replacing: replacing), fullscreenDialog: true));
