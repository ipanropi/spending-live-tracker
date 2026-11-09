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

/// "Left until payday" and the pace, for the cycle you're in now.
class Today {
  const Today({
    required this.balanceCents,
    required this.nextPayday,
    required this.daysLeft,
    required this.perDayCents,
    required this.weekCents,
    required this.weekStart,
  });

  /// The Wise balance, which is what's left until the next top-up. Null if Wise didn't send one.
  final int? balanceCents;
  final DateTime nextPayday;

  /// Counts today.
  final int daysLeft;

  /// What you can spend per day until payday. Zero once the balance runs out.
  final int? perDayCents;

  /// Spent since Monday.
  final int weekCents;

  /// That Monday. Shown with the week, because just after payday the week
  /// still holds spending from before it.
  final DateTime weekStart;
}

/// One monthly cycle (7th to 6th), summarised.
class CycleSummary {
  const CycleSummary({
    required this.start,
    required this.isCurrent,
    required this.transactions,
    required this.spentCents,
    required this.avgPerDayCents,
    required this.categories,
    required this.places,
    required this.today,
  });

  final DateTime start;
  final bool isCurrent;

  /// Newest first, money in included.
  final List<Txn> transactions;
  final int spentCents;
  final int avgPerDayCents;
  final List<CategoryTotal> categories;
  final List<PlaceTotal> places;

  /// Only for the current cycle.
  final Today? today;
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
  final spent = _spent(spending);
  final days = isCurrent ? daysBetween(start, now) + 1 : daysBetween(start, end);

  return CycleSummary(
    start: start,
    isCurrent: isCurrent,
    transactions: txns,
    spentCents: spent,
    avgPerDayCents: days > 0 ? (spent / days).round() : 0,
    categories: byCategory(spending),
    places: byPlace(spending),
    today: isCurrent ? _today(s, now) : null,
  );
}

Today _today(Statement s, DateTime now) {
  final payday = nextPayday(now);
  final daysLeft = daysBetween(now, payday); // counts today
  final balance = s.balanceCents;
  final monday = weekStart(now);
  return Today(
    weekStart: monday,
    balanceCents: balance,
    nextPayday: payday,
    daysLeft: daysLeft,
    perDayCents: balance == null ? null : (balance > 0 ? (balance / daysLeft).floor() : 0),
    weekCents: _spent([
      for (final t in s.transactions)
        if (t.isSpending && !t.date.isBefore(monday)) t,
    ]),
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
