import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/src/domain/models.dart';
import 'package:spending_tracker/src/domain/summary.dart';

Txn _t(DateTime date, int cents, String name, String category) =>
    Txn(date: date, cents: cents, name: name, category: category);

void main() {
  // Sunday 8 Nov 2026, mid-afternoon. The current cycle started on the 7th.
  final now = DateTime(2026, 11, 8, 15);
  final statement = Statement(
    balanceCents: 36560,
    fetchedAt: now,
    transactions: [
      _t(DateTime(2026, 11, 8, 12, 30), -1250, 'ZUS', 'Food & Drinks'),
      _t(DateTime(2026, 11, 8, 8), -650, 'KANTIN', 'Food & Drinks'),
      _t(DateTime(2026, 11, 7, 18), -2500, 'GRAB*RIDE', 'Transport'),
      _t(DateTime(2026, 11, 7, 10), -990, 'ZUS', 'Food & Drinks'),
      _t(DateTime(2026, 11, 7, 9), 89000, 'ME', 'Money in'),
      _t(DateTime(2026, 11, 6, 12), -4890, 'SPEEDMART', 'Groceries'), // last cycle, but this week
      _t(DateTime(2026, 10, 1, 12), -1500, 'OLD', 'Other'), // the cycle before
    ],
  );

  test('current cycle: only its transactions, money in not counted as spending', () {
    final s = summarise(statement, DateTime(2026, 11, 7), now);
    expect(s.isCurrent, isTrue);
    expect(s.transactions.length, 5);
    expect(s.spentCents, 1250 + 650 + 2500 + 990);
    expect(s.avgPerDayCents, ((1250 + 650 + 2500 + 990) / 2).round()); // 7th and 8th
  });

  test('categories and places are highest first, with counts', () {
    final s = summarise(statement, DateTime(2026, 11, 7), now);
    expect(s.categories.map((c) => (c.name, c.cents, c.count)), [('Food & Drinks', 2890, 3), ('Transport', 2500, 1)]);
    final food = s.categories.first;
    expect(food.places.map((p) => (p.name, p.cents, p.count)), [('ZUS', 2240, 2), ('KANTIN', 650, 1)]);
    expect(s.places.first.name, 'GRAB*RIDE');
  });

  test('today: left, days to the next payday, per day and this week', () {
    final today = summarise(statement, DateTime(2026, 11, 7), now).today!;
    expect(today.balanceCents, 36560);
    expect(today.nextPayday, DateTime(2026, 11, 22));
    expect(today.daysLeft, 14);
    expect(today.perDayCents, 2611); // RM 365.60 / 14, rounded down
    expect(today.weekCents, 1250 + 650 + 2500 + 990 + 4890); // since Monday 2 Nov, across cycles
    expect(today.weekStart, DateTime(2026, 11, 2));
  });

  test('a past cycle has no "today" and averages over the whole cycle', () {
    final s = summarise(statement, DateTime(2026, 10, 7), now);
    expect(s.isCurrent, isFalse);
    expect(s.today, isNull);
    expect(s.spentCents, 4890);
    expect(s.avgPerDayCents, (4890 / 31).round());
  });

  test('available cycles, newest first, always including the current one', () {
    expect(availableCycles(statement, now), [DateTime(2026, 11, 7), DateTime(2026, 10, 7), DateTime(2026, 9, 7)]);
    expect(availableCycles(Statement(transactions: const [], balanceCents: 0, fetchedAt: now), now), [
      DateTime(2026, 11, 7),
    ]);
  });

  test('no balance, or none left, means no per-day amount to spend', () {
    final none = summarise(
      Statement(transactions: const [], balanceCents: null, fetchedAt: now),
      DateTime(2026, 11, 7),
      now,
    );
    expect(none.today!.perDayCents, isNull);
    final overdrawn = summarise(
      Statement(transactions: const [], balanceCents: -500, fetchedAt: now),
      DateTime(2026, 11, 7),
      now,
    );
    expect(overdrawn.today!.perDayCents, 0);
  });
}
