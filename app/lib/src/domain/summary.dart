/// Everything the dashboard shows, worked out once per update instead of on every rebuild.
library;

import 'cycles.dart';
import 'models.dart';

/// Total spent at one place, and how many times.
class PlaceTotal {
  const PlaceTotal({required this.name, required this.category, required this.cents, required this.count});
  final String name;
  final String category;

  /// Positive: the amount spent.
  final int cents;
  final int count;
}

/// Total spent in one category, with its places (highest first).
class CategoryTotal {
  const CategoryTotal({required this.name, required this.cents, required this.count, required this.places});
  final String name;
  final int cents;
  final int count;
  final List<PlaceTotal> places;
}

/// One monthly cycle (7th to 6th), summarised.
class CycleSummary {
  const CycleSummary({
    required this.start,
    required this.isCurrent,
    required this.transactions,
    required this.spentCents,
    required this.daysCounted,
    required this.categories,
    required this.places,
    required this.previousCents,
  });

  final DateTime start;
  final bool isCurrent;

  /// Newest first, money in included.
  final List<Txn> transactions;
  final int spentCents;

  /// Days of the cycle so far (today included), or all of them for a past cycle.
  final int daysCounted;
  final List<CategoryTotal> categories;
  final List<PlaceTotal> places;

  /// What the cycle before had spent by the same point (the same number of days in),
  /// for comparison. Null when that cycle is older than what was loaded from Wise.
  final int? previousCents;

  int get avgPerDayCents => daysCounted > 0 ? (spentCents / daysCounted).round() : 0;
}

/// The cycles that have data, newest first. Always includes the current one.
List<DateTime> availableCycles(Statement s, DateTime now) {
  final starts = {cycleStart(now), for (final t in s.transactions) cycleStart(t.date)}.toList()
    ..sort((a, b) => b.compareTo(a));
  return starts;
}

CycleSummary summarise(Statement s, DateTime start, DateTime now) {
  final end = cycleEnd(start);
  final isCurrent = start == cycleStart(now);
  final txns = [
    for (final t in s.transactions)
      if (!t.date.isBefore(start) && t.date.isBefore(end)) t,
  ];
  final spending = [
    for (final t in txns)
      if (t.isSpending) t,
  ];
  final days = isCurrent ? daysBetween(start, now) + 1 : daysBetween(start, end);

  // The previous cycle, up to the same day number (all of it, for a past cycle).
  final prevStart = DateTime(start.year, start.month - 1, start.day);
  final prevEnd = isCurrent ? DateTime(prevStart.year, prevStart.month, prevStart.day + days) : start;
  final previous = prevStart.isBefore(oldestLoadedCycle(now))
      ? null
      : _spent([
          for (final t in s.transactions)
            if (t.isSpending &&
                !t.date.isBefore(prevStart) &&
                t.date.isBefore(prevEnd.isAfter(start) ? start : prevEnd))
              t,
        ]);

  return CycleSummary(
    start: start,
    isCurrent: isCurrent,
    transactions: txns,
    spentCents: _spent(spending),
    daysCounted: days,
    categories: byCategory(spending),
    places: byPlace(spending),
    previousCents: previous,
  );
}

/// Places, highest total first.
List<PlaceTotal> byPlace(List<Txn> spending) {
  final totals = <String, (String, int, int)>{}; // name → (category, cents, count)
  for (final t in spending) {
    final (category, cents, count) = totals[t.name] ?? (t.category, 0, 0);
    totals[t.name] = (category, cents - t.cents, count + 1);
  }
  return [
    for (final MapEntry(key: name, value: (category, cents, count)) in totals.entries)
      PlaceTotal(name: name, category: category, cents: cents, count: count),
  ]..sort((a, b) => b.cents.compareTo(a.cents));
}

/// Categories, highest total first, each with its places.
List<CategoryTotal> byCategory(List<Txn> spending) {
  final groups = <String, List<Txn>>{};
  for (final t in spending) {
    (groups[t.category] ??= []).add(t);
  }
  return [
    for (final MapEntry(key: name, value: list) in groups.entries)
      CategoryTotal(name: name, cents: _spent(list), count: list.length, places: byPlace(list)),
  ]..sort((a, b) => b.cents.compareTo(a.cents));
}

/// Money out of a list of debits, as a positive number.
int _spent(List<Txn> spending) => spending.fold(0, (sum, t) => sum - t.cents);
