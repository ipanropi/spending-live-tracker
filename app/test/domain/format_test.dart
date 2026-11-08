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
  });

  test('recent days by name, older ones by date', () {
    final now = DateTime(2026, 11, 8, 15);
    expect(dayLabel(DateTime(2026, 11, 8, 0, 1), now: now), 'Today');
    expect(dayLabel(DateTime(2026, 11, 7, 23, 59), now: now), 'Yesterday');
    expect(dayLabel(DateTime(2026, 11, 6, 12), now: now), 'Fri, 6 Nov');
    expect(dayLabel(DateTime(2025, 12, 31, 12), now: now), 'Wed, 31 Dec 2025');
    expect(whenLabel(DateTime(2026, 11, 8, 14, 15), now: now), 'Today, 2:15 pm');
  });

  test('how fresh the data is', () {
    final now = DateTime(2026, 11, 8, 15);
    expect(updatedLabel(now.subtract(const Duration(seconds: 20)), now: now), 'Updated just now');
    expect(updatedLabel(now.subtract(const Duration(minutes: 5)), now: now), 'Updated 5 min ago');
    expect(updatedLabel(DateTime(2026, 11, 8, 9, 5), now: now), 'Updated 9:05 am');
    expect(updatedLabel(DateTime(2026, 11, 7, 21, 30), now: now), 'Updated Yesterday, 9:30 pm');
  });

  test('rmParts splits the sign and number so "RM" can be drawn smaller', () {
    expect(rmParts(178000), ('', '1,780.00'));
    expect(rmParts(-2000), ('−', '20.00'));
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
