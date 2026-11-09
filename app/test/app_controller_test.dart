import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/src/app_controller.dart';
import 'package:spending_tracker/src/data/fake_source.dart';
import 'package:spending_tracker/src/data/wise_api.dart';

import 'helpers.dart';

void main() {
  late MemoryTokens tokens;
  late MemoryCache cache;
  late ScriptedSource source;
  late DateTime clock;

  AppController controller() =>
      AppController(sourceFor: (_) => source, tokens: tokens, cache: cache, clock: () => clock);

  setUp(() {
    tokens = MemoryTokens();
    cache = MemoryCache();
    clock = testNow;
    source = ScriptedSource(FakeSource(clock: () => clock, delay: Duration.zero));
  });

  test('asks for a token when there is none', () async {
    final c = controller();
    await c.start();
    expect(c.phase, Phase.needsToken);
  });

  test('a bad token is not saved, and the error is shown', () async {
    final c = controller();
    await c.start();
    source.failWith = const WiseException(WiseErrorKind.badToken, 'Wise rejected the token.');
    expect(await c.connect('nope'), 'Wise rejected the token.');
    expect(tokens.value, isNull);
    expect(c.phase, Phase.needsToken);
  });

  test('a good token is saved, trimmed, and data loads and is cached', () async {
    final c = controller();
    await c.start();
    expect(await c.connect('  good  '), isNull);
    expect(tokens.value, 'good');
    expect(c.phase, Phase.ready);
    expect(c.period!.balanceCents, 178000);
    expect(cache.value, isNotNull);
  });

  test('opens with cached data, then refreshes', () async {
    tokens.value = 'good';
    cache.value = await FakeSource(clock: () => clock, delay: Duration.zero).fetchStatement();
    final c = controller();
    final started = c.start();
    await Future<void>.delayed(Duration.zero);
    expect(c.phase, Phase.ready);
    expect(c.summary, isNotNull); // cached data shows before Wise answers
    await started;
    expect(source.fetches, 1);
  });

  test('a failed refresh keeps the old data and reports the error', () async {
    tokens.value = 'good';
    final c = controller();
    await c.start();
    source.failWith = const WiseException(WiseErrorKind.offline, "Can't reach Wise.");
    await c.refresh();
    expect(c.error?.kind, WiseErrorKind.offline);
    expect(c.summary, isNotNull);
    source.failWith = null;
    await c.refresh();
    expect(c.error, isNull);
  });

  test('refreshes on resume only when the data is stale', () async {
    tokens.value = 'good';
    final c = controller();
    await c.start();
    expect(source.fetches, 1);
    await c.refreshIfStale();
    expect(source.fetches, 1);
    clock = clock.add(AppController.staleAfter + const Duration(seconds: 1));
    await c.refreshIfStale();
    expect(source.fetches, 2);
  });

  test('switching cycles, and back to the current one', () async {
    tokens.value = 'good';
    final c = controller();
    await c.start();
    expect(c.cycles.first, DateTime(2026, 11, 7));
    c.selectCycle(DateTime(2026, 10, 7));
    expect(c.summary!.isCurrent, isFalse);
    c.selectCycle(DateTime(2026, 11, 7));
    expect(c.summary!.isCurrent, isTrue);
  });

  test('after a while away, the app opens on Now and the current month', () async {
    tokens.value = 'good';
    final c = controller();
    await c.start();
    c
      ..selectTab(AppTab.spending)
      ..selectCycle(DateTime(2026, 10, 7));
    expect(c.showingCurrent, isFalse);

    // A quick look at another app keeps your place.
    c.appHidden();
    clock = testNow.add(const Duration(minutes: 2));
    await c.appResumed();
    expect(c.tab, AppTab.spending);
    expect(c.showingCurrent, isFalse);

    // Back later: a fresh "how am I doing?".
    c.appHidden();
    clock = testNow.add(const Duration(minutes: 10));
    await c.appResumed();
    expect(c.tab, AppTab.now);
    expect(c.showingCurrent, isTrue);
  });

  test('"days left" moves on at midnight without new data', () async {
    tokens.value = 'good';
    final c = controller();
    await c.start();
    expect(c.period!.daysLeft, 14);
    clock = DateTime(2026, 11, 9, 0, 5);
    expect(c.period!.daysLeft, 13);
    expect(c.period!.today, isEmpty); // a new day starts with nothing spent
  });

  test('disconnect forgets the token and the cached data', () async {
    tokens.value = 'good';
    final c = controller();
    await c.start();
    await c.disconnect();
    expect(tokens.value, isNull);
    expect(cache.value, isNull);
    expect(c.phase, Phase.needsToken);
    expect(c.summary, isNull);
    expect(c.period, isNull);
  });
}
