import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/cycles.dart';
import '../domain/models.dart';
import '../domain/wise_parse.dart';

/// Where the app gets its statement from: Wise, or fake data for tests and screenshots.
abstract interface class StatementSource {
  /// Checks the token works and the account has an MYR balance. Throws [WiseException] if not.
  Future<void> verify();

  /// Fetches the last [cyclesToLoad] monthly cycles of transactions and the balance now.
  Future<Statement> fetchStatement();

  /// Releases network resources.
  void close();
}

enum WiseErrorKind { badToken, blocked, offline, noBalance, other }

class WiseException implements Exception {
  const WiseException(this.kind, this.message);
  final WiseErrorKind kind;
  final String message;

  @override
  String toString() => message;
}

/// Reads your MYR balance and statement from the Wise API with a read-only token.
class WiseApi implements StatementSource {
  WiseApi(this._token, {http.Client? client}) : _client = client ?? http.Client();

  /// Overridable at build time for testing against a fake server:
  /// `--dart-define=WISE_API=http://127.0.0.1:9999`.
  static const String baseUrl = String.fromEnvironment('WISE_API', defaultValue: 'https://api.wise.com');
  static const String currency = 'MYR';
  static const Duration _timeout = Duration(seconds: 30);

  final String _token;
  final http.Client _client;

  // Found once, then reused: your profile and balance ids don't change.
  String? _profileId;
  String? _balanceId;

  @override
  Future<void> verify() => _ids();

  @override
  Future<Statement> fetchStatement() async {
    final (profileId, balanceId) = await _ids();
    final now = DateTime.now();
    final uri = Uri.parse('$baseUrl/v1/profiles/$profileId/balance-statements/$balanceId/statement.json').replace(
      queryParameters: {
        'currency': currency,
        'type': 'COMPACT',
        'intervalStart': _wiseTime(statementWindowStart(now)),
        'intervalEnd': _wiseTime(now),
      },
    );
    final body = await _get(uri);
    // A few months of transactions is a big-ish JSON; parse it off the UI thread.
    return compute(_parse, (body, now));
  }

  Future<(String, String)> _ids() async {
    if (_profileId != null && _balanceId != null) return (_profileId!, _balanceId!);
    final profileId = pickPersonalProfileId(await _get(Uri.parse('$baseUrl/v2/profiles')));
    if (profileId == null) {
      throw const WiseException(WiseErrorKind.noBalance, 'No Wise profile found for this token.');
    }
    final balanceId = pickBalanceId(
      await _get(Uri.parse('$baseUrl/v4/profiles/$profileId/balances?types=STANDARD')),
      currency,
    );
    if (balanceId == null) {
      throw const WiseException(WiseErrorKind.noBalance, 'No MYR balance in your Wise account. Add some MYR first.');
    }
    return (_profileId = profileId, _balanceId = balanceId);
  }

  Future<String> _get(Uri uri) async {
    final http.Response res;
    try {
      res = await _client.get(uri, headers: {'Authorization': 'Bearer $_token'}).timeout(_timeout);
    } on TimeoutException {
      throw const WiseException(WiseErrorKind.offline, 'Wise took too long to answer. Try again.');
    } on Exception {
      throw const WiseException(WiseErrorKind.offline, "Can't reach Wise. Check your internet connection.");
    }
    // Decode as UTF-8 whatever the headers say, so names like "Café" come through intact.
    final body = utf8.decode(res.bodyBytes, allowMalformed: true);
    return switch (res.statusCode) {
      200 => body,
      401 => throw const WiseException(WiseErrorKind.badToken, 'Wise rejected the token. Add a new read-only token.'),
      403 => throw const WiseException(
        WiseErrorKind.blocked,
        'Wise blocked this request (403). The token may not have statement access, '
        'or Wise wants extra verification.',
      ),
      final code => throw WiseException(
        WiseErrorKind.other,
        'Wise error $code: ${body.length > 200 ? '${body.substring(0, 200)}…' : body}',
      ),
    };
  }

  @override
  void close() => _client.close();
}

Statement _parse((String, DateTime) input) => parseStatement(input.$1, input.$2);

/// Wise wants UTC with milliseconds: 2026-06-06T16:00:00.000Z.
String _wiseTime(DateTime t) =>
    DateTime.fromMillisecondsSinceEpoch(t.millisecondsSinceEpoch, isUtc: true).toIso8601String();
