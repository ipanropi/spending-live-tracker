import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../domain/format.dart';
import '../domain/summary.dart';
import 'activity_page.dart';
import 'detail_pages.dart';
import 'status.dart';
import 'theme.dart';
import 'widgets.dart';

/// Two columns from here: categories on the left, places on the right.
const double _twoColumnsFrom = 760;

/// Top places shown before "All places".
const int _topPlaces = 5;

/// "Where does my money go?" One month (7th to 6th) at a time: the total, how it
/// compares with the month before, and what it went on.
class SpendingPage extends StatelessWidget {
  const SpendingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final summary = c.summary;
    final body = summary == null
        ? (c.error == null ? const ListSkeleton() : const SizedBox.shrink())
        // A short fade when the month changes, so the change is noticed.
        : AnimatedSwitcher(
            duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
            child: KeyedSubtree(
              key: ValueKey(summary.start),
              child: _MonthBody(summary: summary, c: c),
            ),
          );
    // Escape and the back gesture return to this month (see HomeShell).
    return TabScroll(
      slivers: [
        const SliverToBoxAdapter(child: ScreenHeader('Spending')),
        const SliverToBoxAdapter(child: ErrorBanner()),
        SliverToBoxAdapter(child: _MonthStepper(c: c)),
        const SliverToBoxAdapter(child: SizedBox(height: Space.l)),
        SliverToBoxAdapter(child: body),
      ],
    );
  }
}

/// ‹ This month › with the dates under it. Steps one month at a time, through the
/// months loaded from Wise.
class _MonthStepper extends StatelessWidget {
  const _MonthStepper({required this.c});

  final AppController c;

  @override
  Widget build(BuildContext context) {
    final cycles = c.cycles; // newest first
    final i = cycles.indexOf(c.selectedCycle).clamp(0, cycles.length - 1);
    final now = c.now;
    final title = switch (i) {
      0 => 'This month',
      1 => 'Last month',
      _ => '$i months ago',
    };
    void go(int to) {
      HapticFeedback.selectionClick();
      c.selectCycle(cycles[to]);
    }

    // Kept compact on wide windows, so the arrows stay next to the month they change.
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Earlier month',
              onPressed: i < cycles.length - 1 ? () => go(i + 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: MergeSemantics(
                  child: Column(
                    children: [
                      Heading(title, style: Styles.sectionTitle),
                      const SizedBox(height: 2),
                      Text(
                        cycleLabel(c.selectedCycle, now: now),
                        style: Styles.meta,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Later month',
              onPressed: i > 0 ? () => go(i - 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthBody extends StatelessWidget {
  const _MonthBody({required this.summary, required this.c});

  final CycleSummary summary;
  final AppController c;

  @override
  Widget build(BuildContext context) {
    final now = c.now;
    final label = cycleLabel(summary.start, now: now);
    final total = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Headline(
          cents: summary.spentCents,
          size: context.heroSize * 0.85,
          lines: [
            summary.isCurrent ? 'spent so far this month' : 'spent that month',
            if (summary.spentCents > 0) '${rm(summary.avgPerDayCents)} a day on average',
          ],
        ),
        if (_comparison(summary) case final comparison?) ...[const SizedBox(height: Space.s), comparison],
      ],
    );
    if (summary.categories.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          total,
          const SizedBox(height: Space.xl),
          Text(summary.isCurrent ? 'Nothing spent yet this month.' : 'Nothing spent that month.', style: Styles.meta),
        ],
      );
    }

    final categories = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('By category'),
        ListSurface(
          children: [
            for (final category in summary.categories)
              _CategoryRow(
                category: category,
                share: category.cents / summary.spentCents,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CategoryPage(category: category, summary: summary, label: label, now: now),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
    final places = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Top places'),
        ListSurface(children: [for (final p in summary.places.take(_topPlaces)) PlaceTile(place: p)]),
        if (summary.places.length > _topPlaces) ...[
          const SizedBox(height: Space.xs),
          ViewAllButton(
            'All ${summary.places.length} places',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlacesPage(summary: summary, label: label),
              ),
            ),
          ),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _twoColumnsFrom) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              total,
              const SizedBox(height: Space.xxl),
              categories,
              const SizedBox(height: Space.xxl),
              places,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            total,
            const SizedBox(height: Space.xxl),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: categories),
                const SizedBox(width: Space.xxl),
                Expanded(child: places),
              ],
            ),
          ],
        );
      },
    );
  }

  /// "RM 185 more than last month by day 2": amber when more, green when less.
  /// Compared at the same day of the month, since a month in progress against a
  /// whole one would always look good.
  static Widget? _comparison(CycleSummary s) {
    final previous = s.previousCents;
    if (previous == null || (previous == 0 && s.spentCents == 0)) return null;
    final diff = s.spentCents - previous;
    final than = s.isCurrent ? 'than last month by day ${s.daysCounted}' : 'than the month before';
    final (text, icon, color) = diff.abs() < 100
        ? ('About the same $than', Icons.drag_handle, Palette.text2)
        : diff > 0
        ? ('${rmWhole(diff)} more $than', Icons.arrow_upward, Palette.warn)
        : ('${rmWhole(-diff)} less $than', Icons.arrow_downward, Palette.good);
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: ExcludeSemantics(child: Icon(icon, size: 16, color: color)),
          ),
          const SizedBox(width: Space.s - 2),
          Expanded(
            child: Text(text, style: Styles.extra.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

/// A category: its icon, name and amount, then its share of the month. Opens the category.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.share, required this.onTap});

  final CategoryTotal category;
  final double share;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.s, Space.m),
          child: Row(
            children: [
              CategoryIcon(category.name),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // With large text the amount goes under the name, so neither is squeezed.
                    if (context.largeText) ...[
                      Text(category.name, style: Styles.rowName),
                      Text(rm(category.cents), style: Styles.rowAmount),
                    ] else
                      Row(
                        children: [
                          Expanded(child: Text(category.name, style: Styles.rowName)),
                          const SizedBox(width: Space.m),
                          Text(rm(category.cents), style: Styles.rowAmount),
                        ],
                      ),
                    ShareBar(fraction: share),
                  ],
                ),
              ),
              const SizedBox(width: Space.xs),
              const Chevron(),
            ],
          ),
        ),
      ),
    );
  }
}
