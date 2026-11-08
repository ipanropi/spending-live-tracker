import 'package:spending_tracker/src/data/statement_cache.dart';
import 'package:spending_tracker/src/data/token_store.dart';
import 'package:spending_tracker/src/data/wise_api.dart';
import 'package:spending_tracker/src/domain/models.dart';

/// Sunday 8 Nov 2026, 3 pm: mid-cycle, 14 days before the 22nd.
final testNow = DateTime(2026, 11, 8, 15);

class MemoryTokens implements TokenStore {
  MemoryTokens([this.value]);
  String? value;

  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async => value = token;
  @override
  Future<void> delete() async => value = null;
}

class MemoryCache implements StatementCache {
  MemoryCache([this.value]);
  Statement? value;

  @override
  Future<Statement?> read() async => value;
  @override
  Future<void> write(Statement statement) async => value = statement;
  @override
  Future<void> clear() async => value = null;
}

/// A source that wraps another and can be told to fail, counting fetches.
class ScriptedSource implements StatementSource {
  ScriptedSource(this.inner);
  final StatementSource inner;
  WiseException? failWith;
  int fetches = 0;

  @override
  Future<void> verify() async {
    if (failWith != null) throw failWith!;
    await inner.verify();
  }

  @override
  Future<Statement> fetchStatement() async {
    fetches++;
    if (failWith != null) throw failWith!;
    return inner.fetchStatement();
  }

  @override
  void close() {}
}
