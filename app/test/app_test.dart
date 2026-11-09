import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/src/app_controller.dart';
import 'package:spending_tracker/src/data/fake_source.dart';
import 'package:spending_tracker/src/data/wise_api.dart';
import 'package:spending_tracker/src/domain/models.dart';
import 'package:spending_tracker/src/ui/app.dart';
import 'package:spending_tracker/src/ui/theme.dart';
import 'package:spending_tracker/src/ui/widgets.dart';

import 'helpers.dart';

/// Screens to check: a small phone, a typical phone, a laptop window.
const sizes = {'small phone': Size(360, 740), 'phone': Size(412, 915), 'laptop': Size(1280, 800)};

/// Scrolls [finder] into view, like a user would, then taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Scrolls the open tab back up until [finder] is built and in view, then taps it.
Future<void> scrollUpAndTap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, -200, scrollable: find.byType(Scrollable).first);
  await tapVisible(tester, finder);
}

/// The fake data with a different balance, to see the other pace states.
class _BalanceSource implements StatementSource {
  _BalanceSource(this.inner, this.balanceCents);
  final StatementSource inner;
  final int balanceCents;

  @override
  Future<void> verify() => inner.verify();

  @override
  Future<Statement> fetchStatement() async {
    final s = await inner.fetchStatement();
    return Statement(transactions: s.transactions, balanceCents: balanceCents, fetchedAt: s.fetchedAt);
  }

  @override
  void close() {}
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true; // a tap that misses is a failed test

  late ScriptedSource source;
  late MemoryTokens tokens;
  late DateTime now;

  Future<void> pumpApp(
    WidgetTester tester,
    Size size, {
    String? token = 'good',
    double textScale = 1,
    Duration fetchDelay = Duration.zero,
    bool reduceMotion = false,
    bool settle = true,
    int? balanceCents,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    if (reduceMotion) {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
    }
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    now = testNow;
    tokens = MemoryTokens(token);
    final StatementSource fake = FakeSource(clock: () => now, delay: fetchDelay);
    source = ScriptedSource(balanceCents == null ? fake : _BalanceSource(fake, balanceCents));
    final controller = AppController(sourceFor: (_) => source, tokens: tokens, cache: MemoryCache(), clock: () => now);
    await tester.pumpWidget(SpendingApp(controller: controller));
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    // The tab bar on phones, the rail on wider windows: both show the label.
    final tab = find.descendant(
      of: find.byWidgetPredicate((w) => w is NavigationBar || w is NavigationRail),
      matching: find.text(label),
    );
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }

  double top(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    group(name, () {
      testWidgets('Now answers "am I OK until payday?" first: what is left, the pace, then today', (tester) async {
        await pumpApp(tester, size);
        expect(find.text('Updated just now'), findsOneWidget);
        expect(find.bySemanticsLabel('RM 1,780.00, left until payday, Sun 22 Nov, 14 days to go'), findsOneWidget);
        // The verdict in words, then the chart that backs it up.
        expect(find.text('On pace: RM 162 to spare'), findsOneWidget);
        expect(find.text('RM 127 a day lasts until payday.'), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            'Chart of money left this pay period, above an even pace: RM 1,780.00 left on day 2 of 15, '
            'where an even pace would leave RM 1,617.63.',
          ),
          findsOneWidget,
        );
        // Today's payments, newest first, each with its category and time.
        expect(find.text('RM 24.60 spent'), findsOneWidget);
        expect(find.byType(TxnTile), findsNWidgets(3));
        expect(find.text('6:10 pm'), findsOneWidget);
        expect(find.text('Kantin Pejabat'), findsOneWidget); // names in normal case
        expect(find.text('KTM Berhad'), findsOneWidget); // short codes stay in capitals
        expect(find.text('All activity'), findsOneWidget);

        final left = find.text('RM 1,780.00');
        final verdict = find.text('On pace: RM 162 to spare');
        final today = find.text('RM 24.60 spent');
        expect(top(tester, left), lessThan(top(tester, verdict)));
        if (size.width < 760) {
          expect(top(tester, verdict), lessThan(top(tester, today)));
          expect(find.byType(NavigationBar), findsOneWidget);
        } else {
          // Side by side: today sits beside the money, not under it.
          expect(tester.getTopLeft(today).dx, greaterThan(tester.getTopRight(verdict).dx));
          expect(find.byType(NavigationRail), findsOneWidget);
        }
      });

      testWidgets('Activity has every transaction by day, with search and category filters', (tester) async {
        await pumpApp(tester, size);
        await tapVisible(tester, find.text('All activity'));
        expect(find.text('Search places'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('RM 24.60'), findsOneWidget); // spent today
        expect(find.text('Yesterday'), findsOneWidget);
        expect(find.text('RM 61.90'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'kantin');
        await tester.pumpAndSettle();
        expect(find.text('3 transactions, RM 22.00 spent'), findsOneWidget);
        expect(find.text('Kantin Pejabat'), findsNWidgets(3));
        await tester.tap(find.byTooltip('Clear search'));
        await tester.pumpAndSettle();

        await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Transport'));
        expect(find.text('4 transactions, RM 51.20 spent'), findsOneWidget);
        expect(find.text('Zus Coffee Penang'), findsNothing);
        await tapVisible(tester, find.widgetWithText(ChoiceChip, 'All'));
        expect(find.text('Zus Coffee Penang'), findsOneWidget);
      });

      testWidgets('Spending shows the month by category, against last month', (tester) async {
        await pumpApp(tester, size);
        await openTab(tester, 'Spending');
        expect(find.text('This month'), findsOneWidget);
        expect(find.text('7 Nov – 6 Dec'), findsOneWidget);
        expect(find.text('RM 86.50'), findsOneWidget);
        expect(find.text('spent so far this month'), findsOneWidget);
        expect(find.text('RM 43.25 a day on average'), findsOneWidget);
        expect(find.text('RM 87 more than last month by day 2'), findsOneWidget);
        expect(find.byType(ShareBar), findsNWidgets(3));
        expect(find.text('Top places'), findsOneWidget);
        expect(find.textContaining(RegExp(r'^All \d+ places')), findsNothing); // five places: all shown

        final categories = find.text('By category');
        final places = find.text('Top places');
        if (size.width < 760) {
          expect(top(tester, categories), lessThan(top(tester, places)));
        } else {
          expect(top(tester, categories), top(tester, places)); // side by side
        }

        // A category opens with its places and each payment.
        await tapVisible(tester, find.text('Food & Drinks').first);
        expect(find.text('RM 59.40'), findsOneWidget);
        expect(find.text('69% of spending, 7 Nov – 6 Dec'), findsOneWidget);
        expect(find.text('4 payments at 3 places'), findsOneWidget);
        expect(find.text('2 times'), findsOneWidget); // the canteen
        expect(find.text('Yesterday, 7:15 pm'), findsOneWidget); // payments show the day too
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('4 payments at 3 places'), findsNothing);
        expect(find.text('By category'), findsOneWidget);
      });

      testWidgets('earlier months step back one at a time, with their own comparison', (tester) async {
        await pumpApp(tester, size);
        await openTab(tester, 'Spending');
        expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNull);

        await tapVisible(tester, find.byTooltip('Earlier month'));
        expect(find.text('Last month'), findsOneWidget);
        expect(find.text('7 Oct – 6 Nov'), findsOneWidget);
        expect(find.text('RM 353.30'), findsOneWidget);
        expect(find.text('spent that month'), findsOneWidget);
        expect(find.text('RM 283 more than the month before'), findsOneWidget);
        expect(find.text('AI & software'), findsWidgets); // not lost in "Other"

        await tapVisible(tester, find.text('All 9 places'));
        expect(find.text('7 Oct – 6 Nov · 9 places'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();

        await scrollUpAndTap(tester, find.byTooltip('Later month'));
        expect(find.text('This month'), findsOneWidget);
      });

      testWidgets('text at 200% still fits everywhere', (tester) async {
        await pumpApp(tester, size, textScale: 2);
        expect(find.text('RM 1,780.00'), findsOneWidget);
        await tapVisible(tester, find.text('Zus Coffee Penang'));
        expect(find.text('Name from Wise'), findsOneWidget);
        await tester.tapAt(const Offset(10, 10)); // close the sheet
        await tester.pumpAndSettle();

        await openTab(tester, 'Activity');
        await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Food & Drinks'));

        await openTab(tester, 'Spending');
        await tapVisible(tester, find.text('Groceries').first);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await scrollUpAndTap(tester, find.byTooltip('Earlier month'));
        await tapVisible(tester, find.text('All 9 places'));
        await tester.pageBack();
        await tester.pumpAndSettle();

        await openTab(tester, 'Now');
        await tapVisible(tester, find.byTooltip('Settings', skipOffstage: false));
        await tester.ensureVisible(find.text('Disconnect'));
        await tester.pumpAndSettle();
      });
    });
  }

  testWidgets('a transaction opens in full, with the note when it adds something', (tester) async {
    await pumpApp(tester, sizes['phone']!);
    await tapVisible(tester, find.text('Zus Coffee Penang'));
    expect(find.text('ZUS COFFEE PENANG'), findsOneWidget); // the name as Wise sent it
    expect(find.text('Today, 12:30 pm'), findsOneWidget);
    expect(find.textContaining('Card transaction of'), findsNothing); // boilerplate hidden
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await openTab(tester, 'Activity');
    await tapVisible(tester, find.text('Ali Bin Abu').first);
    expect(find.text('Duit makan minggu ni'), findsOneWidget);
  });

  testWidgets('spending fast shows in amber, with what a day still lasts', (tester) async {
    await pumpApp(tester, sizes['phone']!, balanceCents: 50000);
    final verdict = tester.widget<Text>(find.text('Spending fast: RM 8 over pace'));
    expect(verdict.style?.color, Palette.warn);
    expect(find.text('RM 36 a day from now lasts until payday.'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Chart of money left this pay period, below an even pace')), findsOneWidget);
  });

  testWidgets('below zero shows in red, with when the next top-up is', (tester) async {
    await pumpApp(tester, sizes['phone']!, balanceCents: -2000);
    final verdict = tester.widget<Text>(find.text('Overspent by RM 20'));
    expect(verdict.style?.color, Palette.spend);
    expect(find.text('The next top-up is on payday, Sun 22 Nov.'), findsOneWidget);
  });

  testWidgets('back steps out: an earlier month, then the tab, then the app', (tester) async {
    await pumpApp(tester, sizes['phone']!);
    await openTab(tester, 'Spending');
    await tapVisible(tester, find.byTooltip('Earlier month'));
    // What Android's back gesture sends.
    Future<void> back() async {
      final message = const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute'));
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage('flutter/navigation', message, (_) {});
      await tester.pumpAndSettle();
    }

    await back();
    expect(find.text('This month'), findsOneWidget);
    await back();
    expect(find.text('On pace: RM 162 to spare'), findsOneWidget);
  });

  testWidgets('on desktop: Escape returns to this month, Ctrl+1–3 switch tabs', (tester) async {
    await pumpApp(tester, sizes['laptop']!);
    Future<void> ctrl(LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    await ctrl(LogicalKeyboardKey.digit3);
    expect(find.text('This month'), findsOneWidget);
    await tapVisible(tester, find.byTooltip('Earlier month'));
    expect(find.text('Last month'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('This month'), findsOneWidget);
    await ctrl(LogicalKeyboardKey.digit2);
    expect(find.text('Search places'), findsOneWidget);
    await ctrl(LogicalKeyboardKey.digit1);
    expect(find.text('On pace: RM 162 to spare'), findsOneWidget);
  });

  testWidgets('changing the token keeps the how-to folded away', (tester) async {
    await pumpApp(tester, sizes['phone']!);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change Wise token'));
    await tester.pumpAndSettle();
    expect(find.text('Open wise.com and log in'), findsNothing);
    await tester.tap(find.text('How to get a token'));
    await tester.pumpAndSettle();
    expect(find.text('Open wise.com and log in'), findsOneWidget);
  });

  testWidgets('first run asks for a token, then opens on Now', (tester) async {
    await pumpApp(tester, sizes['phone']!, token: null);
    expect(find.text('Connect Wise'), findsOneWidget);
    await tester.tap(find.text('Connect'));
    await tester.pump();
    expect(find.text('Paste your Wise token first.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  my-token  ');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(tokens.value, 'my-token');
    expect(find.text('RM 1,780.00'), findsOneWidget);
  });

  testWidgets('a rejected token offers to update it on every tab, and keeps the old numbers', (tester) async {
    await pumpApp(tester, sizes['phone']!);
    source.failWith = const WiseException(WiseErrorKind.badToken, 'Wise rejected the token.');
    await tester.tap(find.byTooltip('Update (F5)'));
    await tester.pumpAndSettle();
    expect(find.text('Token not accepted'), findsOneWidget);
    expect(find.text('Wise rejected the token.'), findsOneWidget);
    expect(find.text('Showing saved data from Today, 3:00 pm'), findsOneWidget);
    expect(find.text('Update token'), findsOneWidget);
    expect(find.text('RM 1,780.00'), findsOneWidget);
    await openTab(tester, 'Spending');
    expect(find.text('Token not accepted'), findsOneWidget);
    expect(find.text('RM 86.50'), findsOneWidget);
  });

  testWidgets('the first load shows a skeleton of the screen, then the numbers', (tester) async {
    await pumpApp(tester, sizes['phone']!, fetchDelay: const Duration(seconds: 2), settle: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.bySemanticsLabel('Loading your data'), findsOneWidget);
    expect(find.text('RM 1,780.00'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Loading your data'), findsNothing);
    expect(find.text('RM 1,780.00'), findsOneWidget);
  });

  // The skeleton's pulse: its opacity right now.
  double skeletonOpacity(WidgetTester tester) => tester
      .widget<FadeTransition>(find.descendant(of: find.byType(Skeleton), matching: find.byType(FadeTransition)))
      .opacity
      .value;

  testWidgets('the skeleton pulses', (tester) async {
    await pumpApp(tester, sizes['phone']!, fetchDelay: const Duration(seconds: 5), settle: false);
    await tester.pump(const Duration(milliseconds: 100));
    final a = skeletonOpacity(tester);
    await tester.pump(const Duration(milliseconds: 450));
    expect(skeletonOpacity(tester), isNot(a));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('with reduced motion, the skeleton stays still', (tester) async {
    await pumpApp(tester, sizes['phone']!, fetchDelay: const Duration(seconds: 5), reduceMotion: true, settle: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(skeletonOpacity(tester), 1);
    await tester.pump(const Duration(milliseconds: 450));
    expect(skeletonOpacity(tester), 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('"Updated" keeps itself current', (tester) async {
    await pumpApp(tester, sizes['phone']!);
    expect(find.text('Updated just now'), findsOneWidget);
    now = testNow.add(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 31));
    expect(find.text('Updated 5 min ago'), findsOneWidget);
  });

  testWidgets('F5 and Ctrl+R refresh on desktop', (tester) async {
    await pumpApp(tester, sizes['laptop']!);
    expect(source.fetches, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(source.fetches, 2);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(source.fetches, 3);
  });

  testWidgets('disconnect asks first, then returns to setup', (tester) async {
    await pumpApp(tester, sizes['phone']!);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(find.text('Disconnect Wise?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Disconnect'));
    await tester.pumpAndSettle();
    expect(tokens.value, isNull);
    expect(find.text('Connect Wise'), findsOneWidget);
  });
}
