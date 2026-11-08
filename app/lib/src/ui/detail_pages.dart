import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/cycles.dart';
import '../domain/format.dart';
import '../domain/models.dart';
import '../domain/summary.dart';
import 'dashboard_page.dart';
import 'theme.dart';
import 'widgets.dart';

const double _maxWidth = 760;

/// A full list for one month, opened from a dashboard card. Items are built
/// lazily, so long months scroll smoothly.
class _ListPage extends StatelessWidget {
  const _ListPage({
    required this.title,
    required this.subtitle,
    required this.itemCount,
    required this.itemBuilder,
    required this.empty,
  });

  final String title;
  final String subtitle;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final side = context.sidePad(_maxWidth);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Heading(title, style: Styles.title),
            Text(subtitle, style: Styles.meta),
          ],
        ),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
      ),
      body: itemCount == 0
          ? Center(child: Text(empty, style: Styles.meta))
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(side, Space.xs, side, Space.xl + MediaQuery.paddingOf(context).bottom),
              itemCount: itemCount,
              itemBuilder: itemBuilder,
            ),
    );
  }
}

/// A row with a divider above it unless it's the first in its group.
Widget _divided(bool first, Widget child, {double vertical = Space.l}) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    if (!first) const Divider(),
    Padding(
      padding: EdgeInsets.symmetric(vertical: vertical),
      child: child,
    ),
  ],
);

/// Every category; open one to see its places, highest first, with how often.
class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key, required this.summary, required this.label});

  final CycleSummary summary;
  final String label;

  @override
  Widget build(BuildContext context) => _ListPage(
    title: 'By category',
    subtitle: label,
    empty: 'No spending this month.',
    itemCount: summary.categories.length,
    itemBuilder: (_, i) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (i > 0) const Divider(),
        _CategoryTile(category: summary.categories[i], spentCents: summary.spentCents),
      ],
    ),
  );
}

class _CategoryTile extends StatefulWidget {
  const _CategoryTile({required this.category, required this.spentCents});

  final CategoryTotal category;
  final int spentCents;

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _open = false;

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _open = !_open);
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    final motion = context.reduceMotion ? Duration.zero : const Duration(milliseconds: 200);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          onTapHint: _open ? 'Hide places' : 'Show places',
          child: InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.l),
              child: InfoRow(
                name: cat.name,
                amount: rm(cat.cents),
                trailing: AnimatedRotation(turns: _open ? 0.25 : 0, duration: motion, child: const Chevron(size: 20)),
                below: ShareBar(fraction: widget.spentCents == 0 ? 0 : cat.cents / widget.spentCents),
                lines: [plural(cat.count, 'payment')],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: motion,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open ? _places(cat) : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  // The category's places, indented under it with a line on the left, so they read as its children.
  Widget _places(CategoryTotal cat) => Container(
    margin: const EdgeInsets.only(left: Space.xs, bottom: Space.l),
    padding: const EdgeInsets.only(left: Space.l),
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: Palette.line, width: 2)),
    ),
    child: Column(
      children: [
        for (var i = 0; i < cat.places.length; i++)
          _divided(
            i == 0,
            InfoRow(
              name: cat.places[i].name,
              amount: rm(cat.places[i].cents),
              lines: [plural(cat.places[i].count, 'time')],
            ),
            vertical: Space.m,
          ),
      ],
    ),
  );
}

/// Every place, highest first.
class PlacesPage extends StatelessWidget {
  const PlacesPage({super.key, required this.summary, required this.label});

  final CycleSummary summary;
  final String label;

  @override
  Widget build(BuildContext context) => _ListPage(
    title: 'All places',
    subtitle: label,
    empty: 'No places this month.',
    itemCount: summary.places.length,
    itemBuilder: (_, i) {
      final p = summary.places[i];
      return _divided(i == 0, InfoRow(name: p.name, amount: rm(p.cents), lines: [plural(p.count, 'time'), p.category]));
    },
  );
}

/// Every transaction in the month, newest first, grouped by day under a header
/// with that day's spending, so each row only needs the time.
class TransactionsPage extends StatelessWidget {
  TransactionsPage({super.key, required this.summary, required this.label, required this.now})
    : _items = _groupByDay(summary.transactions);

  final CycleSummary summary;
  final String label;
  final DateTime now;
  final List<Object> _items; // _Day headers and Txn rows, in display order

  static List<Object> _groupByDay(List<Txn> txns) {
    final items = <Object>[];
    _Day? day;
    for (final t in txns) {
      final date = dateOnly(t.date);
      if (day == null || day.date != date) {
        day = _Day(date);
        items.add(day);
      }
      if (t.isSpending) day.spentCents -= t.cents;
      items.add(t);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) => _ListPage(
    title: 'All transactions',
    subtitle: '$label · ${plural(summary.transactions.length, 'transaction')}',
    empty: 'No transactions this month.',
    itemCount: _items.length,
    itemBuilder: (_, i) => switch (_items[i]) {
      final _Day day => _DayHeader(day: day, now: now, first: i == 0),
      final Txn t => _divided(_items[i - 1] is _Day, TxnRow(txn: t, now: now, full: true, timeOnly: true)),
      _ => const SizedBox.shrink(),
    },
  );
}

class _Day {
  _Day(this.date);
  final DateTime date;
  int spentCents = 0;
}

/// "Today ............ RM 24.10": the day, and what was spent that day.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.now, required this.first});

  final _Day day;
  final DateTime now;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: first ? Space.l : Space.xl, bottom: Space.xs),
      child: MergeSemantics(
        child: Row(
          children: [
            Expanded(child: Heading(dayLabel(day.date, now: now))),
            if (day.spentCents > 0) Text(rm(day.spentCents), style: Styles.meta.copyWith(fontFeatures: tabular)),
          ],
        ),
      ),
    );
  }
}
