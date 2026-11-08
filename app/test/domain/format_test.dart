import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/src/domain/format.dart';

void main() {
  test('rm formats sen as ringgit', () {
    expect(rm(0), 'RM 0.00');
    expect(rm(5), 'RM 0.05');
    expect(rm(36560), 'RM 365.60');
    expect(rm(178000), 'RM 1,780.00');
    expect(rm(123456789), 'RM 1,234,567.89');
    expect(rm(-2000), '−RM 20.00');
  });

  test('dates and times', () {
    final d = DateTime(2026, 11, 8, 14, 15);
    expect(dayMonth(d), '8 Nov');
    expect(time12(d), '2:15 pm');
    expect(time12(DateTime(2026, 11, 8, 0, 5)), '12:05 am');
    expect(time12(DateTime(2026, 11, 8, 12)), '12:00 pm');
    expect(weekdayDateTime(d), 'Sun, 8 Nov, 2:15 pm');
  });

  test('cycleLabel adds the year only when it differs', () {
    final now = DateTime(2026, 11, 8);
    expect(cycleLabel(DateTime(2026, 11, 7), now: now), '7 Nov – 6 Dec');
    expect(cycleLabel(DateTime(2026, 12, 7), now: now), '7 Dec – 6 Jan 2027');
  });

  test('plural', () {
    expect(plural(1, 'time'), '1 time');
    expect(plural(3, 'time'), '3 times');
    expect(plural(0, 'payment'), '0 payments');
  });
}
