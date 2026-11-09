import 'package:flutter/foundation.dart';

import 'data/statement_cache.dart';
import 'data/token_store.dart';
import 'data/wise_api.dart';
import 'domain/cycles.dart';
import 'domain/models.dart';
import 'domain/summary.dart';

enum Phase { starting, needsToken, ready }

typedef SourceFactory = StatementSource Function(String token);

/// The app's state: the token, the last statement, and what the dashboard shows.
///
/// Opens instantly with the cached statement, then refreshes from Wise in the
/// background. Derived numbers are worked out once per change, not on every rebuild.
class AppController extends ChangeNotifier {
  AppController({
    required this.sourceFor,
    this.tokens = const TokenStore(),
    this.cache = const StatementCache(),
    this.clock = DateTime.now,
    this.skipToken = false,
  });

  final SourceFactory sourceFor;
  final TokenStore tokens;
  final StatementCache cache;
  final DateTime Function() clock;

  /// Fake-data builds don't need a token.
  final bool skipToken;

  /// Refresh on resume only when the data is older than this.
  static const Duration staleAfter = Duration(minutes: 5);

  StatementSource? _source;
  Phase _phase = Phase.starting;
  Statement? _statement;
  bool _refreshing = false;
  WiseException? _error;
  DateTime? _selected; // chosen cycle start; null means the current cycle

  Phase get phase => _phase;
  Statement? get statement => _statement;
  bool get refreshing => _refreshing;
  WiseException? get error => _error;
  DateTime get now => clock();

  Future<void> start() async {
    final token = skipToken ? 'fake' : await tokens.read();
    if (token == null) {
      _phase = Phase.needsToken;
      notifyListeners();
      return;
    }
    _source = sourceFor(token);
    _statement = await cache.read();
    _phase = Phase.ready;
    _invalidate();
    notifyListeners();
    await refresh();
  }

  /// Fetches fresh data from Wise. Keeps showing the old data if it fails.
  Future<void> refresh() async {
    final source = _source;
    if (source == null || _refreshing) return;
    _refreshing = true;
    notifyListeners();
    try {
      final statement = await source.fetchStatement();
      _statement = statement;
      _error = null;
      _invalidate();
      await cache.write(statement);
    } on WiseException catch (e) {
      _error = e;
    } on Object catch (e) {
      _error = WiseException(WiseErrorKind.other, 'Something went wrong: $e');
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  /// For when the app comes back to the foreground.
  Future<void> refreshIfStale() async {
    final fetched = _statement?.fetchedAt;
    if (fetched == null || clock().difference(fetched) > staleAfter) await refresh();
  }

  DateTime? _hiddenAt;

  /// The app went into the background.
  void appHidden() => _hiddenAt = clock();

  /// The app is back. After [staleAfter] away it returns to the current month, so
  /// a quick check never lands on an old month without the wallet figures, and it
  /// refreshes if the data is old. A quick switch to another app keeps your place.
  Future<void> appResumed() async {
    final hidden = _hiddenAt;
    _hiddenAt = null;
    if (!showingCurrent && hidden != null && clock().difference(hidden) >= staleAfter) showCurrent();
    await refreshIfStale();
  }

  /// Checks [token] with Wise and, if it works, saves it and loads the dashboard.
  /// Returns an error message to show, or null on success.
  Future<String?> connect(String token) async {
    final source = sourceFor(token.trim());
    try {
      await source.verify();
    } on WiseException catch (e) {
      source.close();
      return e.message;
    } on Object catch (e) {
      source.close();
      return 'Something went wrong: $e';
    }
    await tokens.write(token.trim());
    _source?.close();
    _source = source;
    _statement = null;
    _error = null;
    _selected = null;
    _phase = Phase.ready;
    _invalidate();
    notifyListeners();
    await refresh();
    return null;
  }

  /// Forgets the token and the cached data on this device.
  Future<void> disconnect() async {
    await tokens.delete();
    await cache.clear();
    _source?.close();
    _source = null;
    _statement = null;
    _error = null;
    _selected = null;
    _phase = Phase.needsToken;
    _invalidate();
    notifyListeners();
  }

  // ---- What the dashboard shows ----

  List<DateTime>? _cycles;
  CycleSummary? _summary;
  DateTime? _derivedDay;

  /// Cycles to pick from, newest first.
  List<DateTime> get cycles {
    _refreshDerivedIfNewDay();
    final s = _statement;
    return _cycles ??= s == null ? [cycleStart(now)] : availableCycles(s, now);
  }

  DateTime get selectedCycle => _selected ?? cycleStart(now);

  /// False while an earlier month is open.
  bool get showingCurrent => _selected == null;

  void showCurrent() => selectCycle(cycleStart(now));

  /// The selected cycle, summarised. Null until there's data.
  CycleSummary? get summary {
    _refreshDerivedIfNewDay();
    final s = _statement;
    if (s == null) return null;
    return _summary ??= summarise(s, selectedCycle, now);
  }

  void selectCycle(DateTime start) {
    _selected = start == cycleStart(now) ? null : start;
    _summary = null;
    notifyListeners();
  }

  void _invalidate() {
    _cycles = null;
    _summary = null;
  }

  // "Days left" and "this week" change at midnight even without new data.
  void _refreshDerivedIfNewDay() {
    final today = dateOnly(now);
    if (_derivedDay != today) {
      _derivedDay = today;
      _invalidate();
    }
  }

  @override
  void dispose() {
    _source?.close();
    super.dispose();
  }
}
