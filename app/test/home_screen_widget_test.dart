import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/src/domain/pace.dart';
import 'package:spending_tracker/src/home_screen_widget.dart';

void main() {
  // Day 4 of the 7th–22nd period: 12 days to go, today included.
  PayPeriod period({required int? balance, required int spent}) => PayPeriod(
    start: DateTime(2026, 11, 7),
    end: DateTime(2026, 11, 22),
    dayNumber: 4,
    balanceCents: balance,
    spentCents: spent,
    todayCents: 0,
    today: const [],
    leftByDay: const [],
  );

  test('on pace: per day and what is left, cut down to whole ringgit', () {
    expect(widgetData(period(balance: 36560, spent: 10000)), {
      'perDay': '30', // 365.60 / 12 = 30.46
      'left': 'RM 365',
      'state': 'onPace',
    });
  });

  test('spending fast', () {
    expect(widgetData(period(balance: 20000, spent: 30000)), {'perDay': '16', 'left': 'RM 200', 'state': 'fast'});
  });

  test('overspent: nothing a day, and a minus sign on what is left', () {
    expect(widgetData(period(balance: -2040, spent: 50000)), {'perDay': '0', 'left': '−RM 20', 'state': 'overspent'});
  });

  test('big amounts keep their thousands separator', () {
    expect(widgetData(period(balance: 1234567, spent: 0))['left'], 'RM 12,345');
  });

  test('no data yet, or no balance from Wise: a neutral placeholder', () {
    const empty = {'perDay': '–', 'left': 'Spending', 'state': 'unknown'};
    expect(widgetData(null), empty);
    expect(widgetData(period(balance: null, spent: 0)), empty);
  });
}
