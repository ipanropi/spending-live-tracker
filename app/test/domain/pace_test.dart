import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/src/domain/cycles.dart';
import 'package:spending_tracker/src/domain/models.dart';
import 'package:spending_tracker/src/domain/pace.dart';

Txn _t(DateTime date, int cents, String name) => Txn(date: date, cents: cents, name: name, category: 'Other');

void main() {
  // Sunday 8 Nov 2026, mid-afternoon: day 2 of the pay period that started on the 7th.
  final now = DateTime(2026, 11, 8, 15);
  final txns = [
    _t(DateTime(2026, 11, 8, 12, 30), -1250, 'ZUS'),
    _t(DateTime(2026, 11, 8, 8), -650, 'KANTIN'),
    _t(DateTime(2026, 11, 7, 18), -2500, 'GRAB'),
    _t(DateTime(2026, 11, 7, 10), -990, 'ZUS'),
    _t(DateTime(2026, 11, 7, 9), 89000, 'ME'), // the payday top-up
    _t(DateTime(2026, 11, 6, 12), -4890, 'SPEEDMART'), // the period before
  ];
  PayPeriod period(int? balance, [DateTime? at]) =>
      payPeriod(Statement(transactions: txns, balanceCents: balance, fetchedAt: now), at ?? now);

  test('the period runs payday to payday, counting today', () {
    final p = period(36560);
    expect(p.start, DateTime(2026, 11, 7));
    expect(p.end, DateTime(2026, 11, 22));
    expect(p.days, 15);
    expect(p.dayNumber, 2);
    expect(p.daysLeft, 14);
  });

  test('spending since payday, today, and what it started with', () {
    final p = period(36560);
    expect(p.spentCents, 1250 + 650 + 2500 + 990); // not the 6th, and not the top-up
    expect(p.todayCents, 1250 + 650);
    expect(p.today.map((t) => t.name), ['ZUS', 'KANTIN']);
    expect(p.availableCents, 36560 + 5390);
  });

  test('money left by day: payday, the end of each day, then now', () {
    expect(period(36560).leftByDay, [41950, 41950 - 2500 - 990, 36560]);
    expect(period(null).leftByDay, isEmpty);
  });

  test('above an even pace is on pace, with what is to spare', () {
    final p = period(36560);
    expect(p.evenPaceLeftCents, (41950 * 13 / 15).round()); // 13 of 15 days left after tonight
    expect(p.aheadCents, 36560 - 36357);
    expect(p.state, PaceState.onPace);
    expect(p.perDayCents, 36560 ~/ 14);
  });

  test('below it is spending fast', () {
    final p = period(30000);
    expect(p.aheadCents, lessThan(0));
    expect(p.state, PaceState.fast);
  });

  test('below zero is overspent, with nothing a day to spend', () {
    final p = period(-500);
    expect(p.state, PaceState.overspent);
    expect(p.perDayCents, 0);
  });

  test('without a balance there is nothing to judge', () {
    final p = period(null);
    expect(p.state, PaceState.unknown);
    expect(p.perDayCents, isNull);
    expect(p.aheadCents, isNull);
  });

  test('on payday itself a new period starts', () {
    final p = period(36560, DateTime(2026, 11, 22, 9));
    expect(p.start, DateTime(2026, 11, 22));
    expect(p.end, DateTime(2026, 12, 7));
    expect(p.dayNumber, 1);
    expect(p.daysLeft, 15);
  });

  group('lastPayday', () {
    final cases = {
      DateTime(2026, 11, 7): DateTime(2026, 11, 7),
      DateTime(2026, 11, 21, 23): DateTime(2026, 11, 7),
      DateTime(2026, 11, 22): DateTime(2026, 11, 22),
      DateTime(2026, 12, 6, 23): DateTime(2026, 11, 22),
      DateTime(2027, 1, 3): DateTime(2026, 12, 22), // across the new year
    };
    cases.forEach((at, expected) => test('$at', () => expect(lastPayday(at), expected)));
  });
}
