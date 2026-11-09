import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/cycles.dart';
import '../domain/format.dart';
import '../domain/models.dart';
import 'shell.dart';
import 'status.dart';
import 'theme.dart';
import 'widgets.dart';

/// A list reads best at about this width; wider windows centre it.
const double _maxWidth = 760;

/// "What did I spend?" Every transaction loaded, newest first, grouped by day, with
/// search and a category filter for "how much at Grab this month?".
class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  final _search = TextEditingController();
  String _query = '';
  String? _category; // null: all

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Txn t) {
    if (_category != null && t.category != _category) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return t.name.toLowerCase().contains(q) ||
        displayName(t.name).toLowerCase().contains(q) ||
        t.note.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final statement = c.statement;
    final now = c.now;
    final all = statement?.transactions ?? const <Txn>[];
    final filtering = _query.isNotEmpty || _category != null;
    final shown = filtering ? all.where(_matches).toList() : all;
    final days = _groupByDay(shown);

    // Categories you've used, most-used first, so the useful filters come first.
    final counts = <String, int>{};
    for (final t in all) {
      counts[t.category] = (counts[t.category] ?? 0) + 1;
    }
    final categories = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });

    return TabScroll(
      maxWidth: _maxWidth,
      slivers: [
        const SliverToBoxAdapter(child: ScreenHeader('Activity')),
        const SliverToBoxAdapter(child: ErrorBanner()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: Space.s),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.trim()),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search places',
                prefixIcon: const Icon(Icons.search, color: Palette.muted),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                      ),
              ),
            ),
          ),
        ),
        if (categories.length > 1)
          SliverToBoxAdapter(
            child: _CategoryFilter(
              categories: categories,
              selected: _category,
              onSelected: (category) {
                HapticFeedback.selectionClick();
                setState(() => _category = category);
              },
            ),
          ),
        if (filtering && shown.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: Space.s),
              child: Semantics(liveRegion: true, child: Text(_resultLine(shown), style: Styles.desc)),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: Space.l)),
        if (statement == null && c.error == null)
          const SliverToBoxAdapter(child: ListSkeleton())
        else if (statement != null && days.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xl),
              child: Text(
                filtering ? 'Nothing matches. Try another name or category.' : 'No transactions yet.',
                style: Styles.meta,
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: days.length,
            itemBuilder: (context, i) => Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : Space.xl),
              child: _DayGroup(day: days[i], now: now),
            ),
          ),
        if (statement != null && days.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: Space.xl),
              child: Text(
                'Showing everything since ${dayMonth(oldestLoadedCycle(now))}.',
                style: Styles.meta,
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  static String _resultLine(List<Txn> shown) {
    final spent = shown.fold(0, (sum, t) => t.isSpending ? sum - t.cents : sum);
    final count = plural(shown.length, 'transaction');
    return spent > 0 ? '$count, ${rm(spent)} spent' : count;
  }

  static List<_Day> _groupByDay(List<Txn> txns) {
    final days = <_Day>[];
    for (final t in txns) {
      final date = dateOnly(t.date);
      if (days.isEmpty || days.last.date != date) days.add(_Day(date));
      days.last.txns.add(t);
      if (t.isSpending) days.last.spentCents -= t.cents;
    }
    return days;
  }
}

class _Day {
  _Day(this.date);
  final DateTime date;
  final List<Txn> txns = [];
  int spentCents = 0;
}

/// One day: its name and what it cost, then its transactions on one surface.
class _DayGroup extends StatelessWidget {
  const _DayGroup({required this.day, required this.now});

  final _Day day;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(dayLabel(day.date, now: now), trailing: day.spentCents > 0 ? rm(day.spentCents) : null),
        ListSurface(
          children: [for (final t in day.txns) TxnTile(txn: t, now: now, onTap: () => showTxnDetails(context, t, now))],
        ),
      ],
    );
  }
}

/// All, then each category: one tap narrows the list.
class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({required this.categories, required this.selected, required this.onSelected});

  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, String? value) => Padding(
      padding: const EdgeInsets.only(right: Space.s),
      child: ChoiceChip(
        label: Text(label),
        selected: selected == value,
        showCheckmark: false,
        onSelected: (_) => onSelected(value),
      ),
    );
    final chips = [chip('All', null), for (final category in categories) chip(category, category)];
    // Phones: one row that scrolls sideways into the margin, so a chip cut off at the
    // edge shows there are more. Wider windows have room to show them all.
    return Padding(
      padding: const EdgeInsets.only(top: Space.s),
      child: MediaQuery.sizeOf(context).width >= railFrom
          ? Wrap(runSpacing: Space.s, children: chips)
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(children: chips),
            ),
    );
  }
}

/// A list's shape while the first update loads.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Skeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonBox(width: 0.3, height: 16),
          SizedBox(height: Space.m),
          SkeletonBox(width: 1, height: 64),
          SizedBox(height: Space.xs),
          SkeletonBox(width: 1, height: 64),
          SizedBox(height: Space.xs),
          SkeletonBox(width: 1, height: 64),
        ],
      ),
    );
  }
}
