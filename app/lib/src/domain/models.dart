/// The data the app works with, already simplified from Wise's responses.
/// Money is held in sen (integer cents) so totals add up exactly.
library;

/// One transaction from the Wise MYR balance.
class Txn {
  const Txn({required this.date, required this.cents, required this.name, required this.category, this.note = ''});

  factory Txn.fromJson(Map<String, dynamic> json) => Txn(
    date: DateTime.parse(json['date'] as String).toLocal(),
    cents: json['cents'] as int,
    name: json['name'] as String,
    category: json['category'] as String,
    note: json['note'] as String? ?? '',
  );

  /// Local time.
  final DateTime date;

  /// Negative means money out.
  final int cents;

  /// Merchant, recipient or sender.
  final String name;
  final String category;

  /// Wise's description, when it has one.
  final String note;

  bool get isSpending => cents < 0;

  Map<String, Object> toJson() => {
    'date': date.toUtc().toIso8601String(),
    'cents': cents,
    'name': name,
    'category': category,
    if (note.isNotEmpty) 'note': note,
  };
}

/// Everything fetched in one update: transactions (newest first) and the balance now.
class Statement {
  const Statement({required this.transactions, required this.balanceCents, required this.fetchedAt});

  factory Statement.fromJson(Map<String, dynamic> json) => Statement(
    transactions: [for (final t in json['transactions'] as List<dynamic>) Txn.fromJson(t as Map<String, dynamic>)],
    balanceCents: json['balanceCents'] as int?,
    fetchedAt: DateTime.parse(json['fetchedAt'] as String).toLocal(),
  );

  /// Bump when the cached format changes, so old caches are ignored instead of misread.
  static const int cacheVersion = 1;

  final List<Txn> transactions;
  final int? balanceCents;
  final DateTime fetchedAt;

  Map<String, Object?> toJson() => {
    'version': cacheVersion,
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    'balanceCents': balanceCents,
    'transactions': [for (final t in transactions) t.toJson()],
  };
}
