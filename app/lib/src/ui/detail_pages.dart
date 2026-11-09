import 'package:flutter/material.dart';

import '../domain/format.dart';
import '../domain/summary.dart';
import 'theme.dart';
import 'widgets.dart';

const double _maxWidth = 760;

/// A page opened from Spending: a title bar with back, then sections that scroll.
class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final side = context.sidePad(_maxWidth);
    return Scaffold(
      appBar: AppBar(
        title: Heading(title, style: Styles.title),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(side, Space.xl, side, Space.xxl + MediaQuery.paddingOf(context).bottom),
        children: children,
      ),
    );
  }
}

/// One category in one month: how much and how big a share, where, and each payment.
class CategoryPage extends StatelessWidget {
  const CategoryPage({
    super.key,
    required this.category,
    required this.summary,
    required this.label,
    required this.now,
  });

  final CategoryTotal category;
  final CycleSummary summary;
  final String label;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final share = summary.spentCents > 0 ? (category.cents * 100 / summary.spentCents).round() : 0;
    final payments = [
      for (final t in summary.transactions)
        if (t.isSpending && t.category == category.name) t,
    ];
    return _DetailScaffold(
      title: category.name,
      children: [
        Headline(
          cents: category.cents,
          size: context.heroSize * 0.85,
          lines: [
            '$share% of spending, $label',
            '${plural(category.count, 'payment')} at ${plural(category.places.length, 'place')}',
          ],
        ),
        const SizedBox(height: Space.xxl),
        const SectionHeader('Places'),
        ListSurface(children: [for (final p in category.places) PlaceTile(place: p, showCategory: false)]),
        const SizedBox(height: Space.xxl),
        const SectionHeader('Payments'),
        ListSurface(
          children: [
            for (final t in payments)
              TxnTile(txn: t, now: now, inCategory: true, onTap: () => showTxnDetails(context, t, now)),
          ],
        ),
      ],
    );
  }
}

/// Every place in one month, highest first.
class PlacesPage extends StatelessWidget {
  const PlacesPage({super.key, required this.summary, required this.label});

  final CycleSummary summary;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      title: 'Places',
      children: [
        Text('$label · ${plural(summary.places.length, 'place')}', style: Styles.meta),
        const SizedBox(height: Space.l),
        ListSurface(children: [for (final p in summary.places) PlaceTile(place: p)]),
      ],
    );
  }
}
