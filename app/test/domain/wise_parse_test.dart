import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/src/domain/models.dart';
import 'package:spending_tracker/src/domain/wise_parse.dart';

// Shaped like dev/mockwise.py, which follows Wise's docs.
final _statement = jsonEncode({
  'transactions': [
    {
      'type': 'DEBIT',
      'date': '2026-11-08T04:30:00.000000Z',
      'amount': {'value': -12.50, 'currency': 'MYR'},
      'details': {
        'type': 'CARD',
        'description': 'Card transaction of 12.50 MYR issued by Zus Coffee',
        'merchant': {'name': 'ZUS COFFEE PENANG', 'category': 'Restaurants'},
      },
    },
    {
      'type': 'DEBIT',
      'date': '2026-11-04T04:30:00.000Z',
      'amount': {'value': 30, 'currency': 'MYR'}, // positive on a DEBIT: must become money out
      'details': {
        'type': 'TRANSFER',
        'recipient': {'name': 'Ali Bin Abu'},
      },
    },
    {
      'type': 'CREDIT',
      'date': '2026-11-05T04:30:00Z',
      'amount': {'value': '500.00', 'currency': 'MYR'}, // a string amount still parses
      'details': {'type': 'DEPOSIT', 'description': 'Received money', 'senderName': 'MUHAMMAD IRFAN'},
    },
    {
      'type': 'DEBIT',
      'date': '2026-11-03T04:30:00Z',
      'amount': {'value': -18.00},
      'details': {
        'type': 'CARD',
        'merchant': {'name': 'KEDAI RUNCIT AMAN', 'category': null},
      },
    },
    {
      'type': 'DEBIT',
      'date': 'not a date',
      'amount': {'value': -1},
    },
    {'unexpected': 'shape'},
  ],
  'endOfStatementBalance': {'value': 365.60, 'currency': 'MYR'},
});

void main() {
  final fetched = DateTime.utc(2026, 11, 8, 6);
  final s = parseStatement(_statement, fetched);

  test('keeps valid transactions, newest first, and skips broken ones', () {
    expect(s.transactions.map((t) => t.name), [
      'ZUS COFFEE PENANG',
      'MUHAMMAD IRFAN',
      'Ali Bin Abu',
      'KEDAI RUNCIT AMAN',
    ]);
  });

  test('money out is negative and money in positive, in sen', () {
    expect(s.transactions.map((t) => t.cents), [-1250, 50000, -3000, -1800]);
  });

  test('categories: keywords, then Wise category, then type, then Other', () {
    expect(s.transactions.map((t) => t.category), ['Food & Drinks', 'Money in', 'Transfers', 'Other']);
  });

  test('balance and notes', () {
    expect(s.balanceCents, 36560);
    expect(s.transactions.first.note, startsWith('Card transaction of'));
    expect(s.transactions[1].note, 'Received money');
  });

  test('round-trips through the cache format', () {
    final json = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
    final back = Statement.fromJson(json);
    expect(json['version'], Statement.cacheVersion);
    expect(back.balanceCents, s.balanceCents);
    expect(back.fetchedAt, fetched.toLocal());
    expect(
      back.transactions.map((t) => (t.date, t.cents, t.name, t.category, t.note)),
      s.transactions.map((t) => (t.date, t.cents, t.name, t.category, t.note)),
    );
  });

  test('anything that is not JSON-shaped as expected gives an empty statement', () {
    final empty = parseStatement('[]', fetched);
    expect(empty.transactions, isEmpty);
    expect(empty.balanceCents, isNull);
  });

  group('ids', () {
    test('picks the personal profile and keeps large ids exact', () {
      final body = jsonEncode([
        {'id': 98765432101, 'type': 'BUSINESS'},
        {'id': 12345678901, 'type': 'personal'},
      ]);
      expect(pickPersonalProfileId(body), '12345678901');
    });
    test('falls back to the first profile', () {
      expect(
        pickPersonalProfileId(
          jsonEncode([
            {'id': 7, 'type': 'BUSINESS'},
          ]),
        ),
        '7',
      );
      expect(pickPersonalProfileId('[]'), isNull);
    });
    test('picks the MYR balance', () {
      final body = jsonEncode([
        {'id': 111, 'currency': 'USD'},
        {'id': 222333444, 'currency': 'MYR'},
      ]);
      expect(pickBalanceId(body, 'MYR'), '222333444');
      expect(pickBalanceId(body, 'EUR'), isNull);
    });
  });
}
