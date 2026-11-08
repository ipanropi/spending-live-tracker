import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/src/domain/cycles.dart';

void main() {
  group('cycleStart', () {
    test('payday itself starts the new cycle', () {
      expect(cycleStart(DateTime(2026, 11, 7)), DateTime(2026, 11, 7));
      expect(cycleStart(DateTime(2026, 11, 8, 12)), DateTime(2026, 11, 7));
    });
    test('the day before still belongs to the old cycle', () {
      expect(cycleStart(DateTime(2026, 11, 6, 23, 59)), DateTime(2026, 10, 7));
    });
    test('crosses the new year', () {
      expect(cycleStart(DateTime(2027, 1, 3)), DateTime(2026, 12, 7));
    });
    test('cycleEnd is the next cycle start', () {
      expect(cycleEnd(DateTime(2026, 12, 7)), DateTime(2027, 1, 7));
    });
  });

  group('nextPayday', () {
    final cases = {
      DateTime(2026, 11, 8, 15): (DateTime(2026, 11, 22), 14),
      DateTime(2026, 11, 21, 15): (DateTime(2026, 11, 22), 1),
      DateTime(2026, 11, 22, 15): (DateTime(2026, 12, 7), 15), // payday: count to the following one
      DateTime(2026, 12, 6, 15): (DateTime(2026, 12, 7), 1),
      DateTime(2026, 12, 7, 15): (DateTime(2026, 12, 22), 15),
      DateTime(2026, 12, 23, 15): (DateTime(2027, 1, 7), 15),
      DateTime(2026, 12, 31, 15): (DateTime(2027, 1, 7), 7),
      DateTime(2027, 2, 22, 15): (DateTime(2027, 3, 7), 13),
    };
    cases.forEach((now, expected) {
      test('$now', () {
        final payday = nextPayday(now);
        expect(payday, expected.$1);
        expect(daysBetween(now, payday), expected.$2);
      });
    });
  });

  group('weekStart', () {
    test('Sunday belongs to the week that started on Monday', () {
      expect(weekStart(DateTime(2026, 11, 8, 18)), DateTime(2026, 11, 2));
    });
    test('Monday starts a new week', () {
      expect(weekStart(DateTime(2026, 11, 9, 0, 1)), DateTime(2026, 11, 9));
    });
  });

  group('statementWindowStart (Malaysia time, whatever the device zone)', () {
    test('mid-cycle: 7 June midnight MYT', () {
      expect(statementWindowStart(DateTime.utc(2026, 11, 8, 5)), DateTime.utc(2026, 6, 6, 16));
    });
    test('16:00 UTC on the 6th is already the 7th in Malaysia', () {
      expect(statementWindowStart(DateTime.utc(2026, 11, 6, 16)), DateTime.utc(2026, 6, 6, 16));
    });
    test('15:59 UTC on the 6th is still the old cycle', () {
      expect(statementWindowStart(DateTime.utc(2026, 11, 6, 15, 59)), DateTime.utc(2026, 5, 6, 16));
    });
    test('crosses the new year', () {
      expect(statementWindowStart(DateTime.utc(2027, 2, 10)), DateTime.utc(2026, 9, 6, 16));
    });
  });
}
