/// The pay period you're in now, and whether the money will last until payday.
///
/// Irfan tops up Wise on each payday (the 7th and the 22nd), so the money in the
/// wallet is meant to last from one payday to the next. Each period is a burn-down:
/// what was there at the start, spent evenly, reaches zero on the next payday. Being
/// above that even pace means you're fine; below it, you're spending fast.
library;

import 'cycles.dart';
import 'models.dart';

enum PaceState {
  /// Above an even pace: what's left will last.
  onPace,

  /// Below an even pace: at this rate the money runs out before payday.
  fast,

  /// The balance is below zero.
  overspent,

  /// No balance from Wise, so there's nothing to compare.
  unknown,
}

class PayPeriod {
  const PayPeriod({
    required this.start,
    required this.end,
    required this.dayNumber,
    required this.balanceCents,
    required this.spentCents,
    required this.todayCents,
    required this.today,
    required this.leftByDay,
  });

  /// The payday it started on, at midnight.
  final DateTime start;

  /// The next payday, at midnight. The period ends the moment it begins.
  final DateTime end;

  /// The Wise balance: what's left. Null when Wise didn't send one.
  final int? balanceCents;

  /// Spent since [start].
  final int spentCents;

  /// Spent today.
  final int todayCents;

  /// Today's transactions, newest first, money in included.
  final List<Txn> today;

  /// Money left at the end of each day so far: [0] is the start of the period and
  /// the last entry is now. Empty without a balance.
  final List<int> leftByDay;

  /// Today is day [dayNumber] of [days], counting from 1.
  final int dayNumber;

  /// Whole days from [start] to [end].
  int get days => daysBetween(start, end);

  /// Days until payday, counting today.
  int get daysLeft => days - dayNumber + 1;

  /// What the period started with: the balance plus everything spent since payday,
  /// so money that came in during the period counts as if it was there from the start.
  int? get availableCents => balanceCents == null ? null : balanceCents! + spentCents;

  /// What an even pace would leave by the end of today.
  int? get evenPaceLeftCents {
    final available = availableCents;
    if (available == null) return null;
    return (available * (days - dayNumber) / days).round();
  }

  /// How far above (positive) or below (negative) an even pace you are.
  int? get aheadCents {
    final even = evenPaceLeftCents;
    return even == null ? null : balanceCents! - even;
  }

  /// What you can spend each day, today included, and still last until payday.
  int? get perDayCents {
    final balance = balanceCents;
    if (balance == null) return null;
    return balance > 0 ? balance ~/ daysLeft : 0;
  }

  PaceState get state {
    final balance = balanceCents;
    if (balance == null || (availableCents ?? 0) <= 0) return PaceState.unknown;
    if (balance < 0) return PaceState.overspent;
    return aheadCents! >= 0 ? PaceState.onPace : PaceState.fast;
  }
}

/// The pay period containing [now], from the statement.
PayPeriod payPeriod(Statement s, DateTime now) {
  final today = dateOnly(now);
  final start = lastPayday(now);
  final end = nextPayday(now);
  final dayNumber = daysBetween(start, today) + 1;

  final spending = [
    for (final t in s.transactions)
      if (t.isSpending && !t.date.isBefore(start)) t,
  ];
  final spent = _sum(spending);

  final balance = s.balanceCents;
  final leftByDay = <int>[];
  if (balance != null) {
    final available = balance + spent;
    for (var k = 0; k <= dayNumber; k++) {
      final dayEnd = DateTime(start.year, start.month, start.day + k);
      leftByDay.add(
        available -
            _sum([
              for (final t in spending)
                if (t.date.isBefore(dayEnd)) t,
            ]),
      );
    }
    leftByDay[dayNumber] = balance; // now, exactly as Wise reports it
  }

  return PayPeriod(
    start: start,
    end: end,
    dayNumber: dayNumber,
    balanceCents: balance,
    spentCents: spent,
    todayCents: _sum([
      for (final t in spending)
        if (!t.date.isBefore(today)) t,
    ]),
    today: [
      for (final t in s.transactions)
        if (!t.date.isBefore(today)) t,
    ],
    leftByDay: leftByDay,
  );
}

int _sum(List<Txn> spending) => spending.fold(0, (sum, t) => sum - t.cents);
