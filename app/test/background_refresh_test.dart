import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/src/background_refresh.dart';
import 'package:spending_tracker/src/data/fake_source.dart';
import 'package:spending_tracker/src/data/wise_api.dart';
import 'package:spending_tracker/src/domain/pace.dart';

import 'helpers.dart';

void main() {
  late MemoryTokens tokens;
  late MemoryCache cache;
  late ScriptedSource source;
  late List<PayPeriod?> published;
  late DateTime clock;

  Future<void> run() => refreshInBackground(
    tokens: tokens,
    cache: cache,
    sourceFor: (_) => source,
    clock: () => clock,
    publish: (p) async => published.add(p),
  );

  setUp(() {
    tokens = MemoryTokens('good');
    cache = MemoryCache();
    clock = testNow;
    source = ScriptedSource(FakeSource(clock: () => clock, delay: Duration.zero));
    published = [];
  });

  test('not connected yet: nothing is fetched or drawn', () async {
    tokens.value = null;
    await run();
    expect(source.fetches, 0);
    expect(published, isEmpty);
  });

  test('fetches, caches, and redraws the widget', () async {
    await run();
    expect(source.fetches, 1);
    expect(cache.value, isNotNull);
    expect(published.single!.balanceCents, 178000);
  });

  test('offline: redraws from the cache, with the day moved on', () async {
    await run();
    source.failWith = const WiseException(WiseErrorKind.offline, 'No connection.');
    clock = testNow.add(const Duration(days: 1));
    await run();
    expect(published, hasLength(2));
    expect(published.last!.balanceCents, 178000);
    expect(published.last!.daysLeft, published.first!.daysLeft - 1);
  });

  test('offline with nothing cached: nothing to draw', () async {
    source.failWith = const WiseException(WiseErrorKind.offline, 'No connection.');
    await run();
    expect(published, isEmpty);
  });
}
