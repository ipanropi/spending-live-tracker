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
      _t(DateTime(2026, 11, 6, 12), -4890, 'SPEEDMART', 'Groceries'), // last cycle
      _t(DateTime(2026, 10, 9, 10), -300, 'KANTIN', 'Food & Drinks'), // last cycle, day 3
      _t(DateTime(2026, 10, 8, 12), -700, 'KANTIN', 'Food & Drinks'), // last cycle, day 2
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

  test('compared with last month by the same day of the month', () {
    final s = summarise(statement, DateTime(2026, 11, 7), now);
    expect(s.previousCents, 700); // 7 and 8 Oct only: day 3 isn't over yet this month
  });

  test('a past cycle is compared with the whole cycle before it', () {
    expect(summarise(statement, DateTime(2026, 10, 7), now).previousCents, 1500);
  });

  test('no comparison for the oldest month loaded, since the one before was not fetched', () {
    expect(summarise(statement, DateTime(2026, 6, 7), now).previousCents, isNull);
    expect(summarise(statement, DateTime(2026, 7, 7), now).previousCents, 0);
  });

  test('a past cycle averages over the whole cycle', () {
    final s = summarise(statement, DateTime(2026, 10, 7), now);
    expect(s.isCurrent, isFalse);
    expect(s.spentCents, 4890 + 300 + 700);
    expect(s.avgPerDayCents, (5890 / 31).round());
  });

  test('available cycles, newest first, always including the current one', () {
    expect(availableCycles(statement, now), [DateTime(2026, 11, 7), DateTime(2026, 10, 7), DateTime(2026, 9, 7)]);
    expect(availableCycles(Statement(transactions: const [], balanceCents: 0, fetchedAt: now), now), [
      DateTime(2026, 11, 7),
    ]);
  });
}
