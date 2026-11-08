import 'package:flutter/material.dart';

import '../domain/format.dart';
import '../domain/summary.dart';
import 'dashboard_page.dart';
import 'theme.dart';
import 'widgets.dart';

const double _maxWidth = 760;

/// A full list for one month, opened from a dashboard card. Items are built
/// lazily, so long months scroll smoothly.
class _ListPage extends StatelessWidget {
  const _ListPage({required this.title, required this.subtitle, required this.itemCount, required this.itemBuilder});

  final String title;
  final String subtitle;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    final side = context.sidePad(_maxWidth);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            Text(subtitle, style: Styles.meta),
          ],
        ),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
      ),
      body: itemCount == 0
          ? const Center(child: Text('Nothing here yet.', style: Styles.meta))
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(side, 4, side, 24 + MediaQuery.paddingOf(context).bottom),
              itemCount: itemCount,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: itemBuilder,
            ),
    );
  }
}

/// Every category; open one to see its places, highest first, with how often.
class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key, required this.summary, required this.label});

  final CycleSummary summary;
  final String label;

  @override
  Widget build(BuildContext context) => _ListPage(
    title: 'By category',
    subtitle: label,
    itemCount: summary.categories.length,
    itemBuilder: (_, i) => _CategoryTile(category: summary.categories[i], spentCents: summary.spentCents),
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

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: InfoRow(
                name: cat.name,
                amount: rm(cat.cents),
                trailing: AnimatedRotation(
                  turns: _open ? 0.25 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(Icons.chevron_right, color: Palette.muted, size: 20),
                ),
                below: ShareBar(fraction: widget.spentCents == 0 ? 0 : cat.cents / widget.spentCents),
                lines: [plural(cat.count, 'payment')],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open ? _places(cat) : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _places(CategoryTotal cat) => Container(
    margin: const EdgeInsets.only(left: 4, bottom: 18),
    padding: const EdgeInsets.only(left: 16),
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: Palette.line, width: 2)),
    ),
    child: Column(
      children: [
        for (var i = 0; i < cat.places.length; i++) ...[
          if (i > 0) const Divider(),
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 2 : 12, bottom: 12),
            child: InfoRow(
              name: cat.places[i].name,
              amount: rm(cat.places[i].cents),
              lines: [plural(cat.places[i].count, 'time')],
            ),
          ),
        ],
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
    itemCount: summary.places.length,
    itemBuilder: (_, i) {
      final p = summary.places[i];
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: InfoRow(name: p.name, amount: rm(p.cents), lines: [plural(p.count, 'time'), p.category]),
      );
    },
  );
}

/// Every transaction in the month, newest first, with the full details.
class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key, required this.summary, required this.label});

  final CycleSummary summary;
  final String label;

  @override
  Widget build(BuildContext context) => _ListPage(
    title: 'All transactions',
    subtitle: '$label · ${plural(summary.transactions.length, 'transaction')}',
    itemCount: summary.transactions.length,
    itemBuilder: (_, i) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: TxnRow(txn: summary.transactions[i], full: true),
    ),
  );
}
