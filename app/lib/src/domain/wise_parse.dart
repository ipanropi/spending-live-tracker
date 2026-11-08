/// Turns Wise's JSON into app data.
///
/// Parsing is deliberately loose: the field shapes come from Wise's docs, not
/// real responses yet, so anything unexpected becomes a sensible default
/// instead of breaking the whole update.
library;

import 'dart:convert';

import 'categories.dart';
import 'models.dart';

/// Parses a balance statement (`statement.json?type=COMPACT`).
Statement parseStatement(String body, DateTime fetchedAt) {
  final root = _obj(jsonDecode(body));
  final transactions = <Txn>[];
  for (final item in _list(root['transactions'])) {
    final t = _obj(item);
    final date = DateTime.tryParse(_str(t['date']))?.toLocal();
    if (date == null) continue;
    final details = _obj(t['details']);
    final merchant = _obj(details['merchant']);

    // Money out is always negative and money in positive, whatever sign Wise sends.
    var cents = _cents(_obj(t['amount'])['value']);
    final type = _str(t['type']);
    if (type == 'DEBIT' && cents > 0) cents = -cents;
    if (type == 'CREDIT' && cents < 0) cents = -cents;

    final name = _firstNonEmpty([
      _str(merchant['name']),
      _str(_obj(details['recipient'])['name']),
      _str(details['senderName']),
      _str(details['description']),
    ]);
    transactions.add(
      Txn(
        date: date,
        cents: cents,
        name: name,
        category: categorize(
          name: name,
          moneyIn: cents > 0,
          wiseCategory: _str(merchant['category']),
          detailType: _str(details['type']),
        ),
        note: _str(details['description']).trim(),
      ),
    );
  }
  transactions.sort((a, b) => b.date.compareTo(a.date));

  final balance = root['endOfStatementBalance'];
  return Statement(
    transactions: transactions,
    balanceCents: balance == null ? null : _cents(_obj(balance)['value']),
    fetchedAt: fetchedAt,
  );
}

/// Picks the personal profile's id from `GET /v2/profiles`, falling back to the first profile.
String? pickPersonalProfileId(String body) {
  final profiles = _list(jsonDecode(body)).map(_obj).toList();
  final personal =
      profiles.where((p) => _str(p['type']).toUpperCase() == 'PERSONAL').firstOrNull ?? profiles.firstOrNull;
  return personal == null ? null : _id(personal['id']);
}

/// Picks the balance id for [currency] from `GET /v4/profiles/{id}/balances`.
String? pickBalanceId(String body, String currency) {
  final balance = _list(jsonDecode(body)).map(_obj).where((b) => _str(b['currency']) == currency).firstOrNull;
  return balance == null ? null : _id(balance['id']);
}

// Small readers that never throw on an unexpected shape.
Map<String, dynamic> _obj(Object? v) => v is Map<String, dynamic> ? v : const {};
List<dynamic> _list(Object? v) => v is List<dynamic> ? v : const [];
String _str(Object? v) => v is String ? v : '';
String? _id(Object? v) => switch (v) {
  final int i => i.toString(),
  final double d => d.toStringAsFixed(0),
  final String s when s.isNotEmpty => s,
  _ => null,
};
int _cents(Object? v) => switch (v) {
  final num n => (n * 100).round(),
  final String s => ((num.tryParse(s) ?? 0) * 100).round(),
  _ => 0,
};
String _firstNonEmpty(List<String> values) =>
    values.map((v) => v.trim()).firstWhere((v) => v.isNotEmpty, orElse: () => 'Unknown');
