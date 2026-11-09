import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/src/app_controller.dart';
import 'package:spending_tracker/src/data/fake_source.dart';
import 'package:spending_tracker/src/data/wise_api.dart';
import 'package:spending_tracker/src/ui/app.dart';
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
    source = ScriptedSource(FakeSource(clock: () => now, delay: fetchDelay));
    final controller = AppController(sourceFor: (_) => source, tokens: tokens, cache: MemoryCache(), clock: () => now);
    await tester.pumpWidget(SpendingApp(controller: controller));
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> openMonth(WidgetTester tester, String label) async {
    await tapVisible(tester, find.byTooltip('Choose month'));
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    group(name, () {
      testWidgets('the dashboard reads in order: left, this month, where it went, transactions', (tester) async {
        await pumpApp(tester, size);
        expect(find.text('Updated just now'), findsOneWidget);
        // The wallet, one panel: what's left until payday, then the pace.
        expect(find.bySemanticsLabel('RM 1,780.00, left until 22 Nov, 14 days left'), findsOneWidget);
        expect(find.text('RM 1,780.00'), findsOneWidget);
        expect(find.text('RM 127.14'), findsOneWidget);
        expect(find.text('to spend a day'), findsOneWidget);
        expect(find.text('RM 345.90'), findsOneWidget); // since Monday, so it includes days before payday
        expect(find.text('spent this week'), findsOneWidget);
        expect(find.text('since Mon, 2 Nov'), findsOneWidget);
        // This month, with its picker beside it rather than at the top of the screen.
        expect(find.text('7 Nov – 6 Dec'), findsOneWidget);
        expect(find.text('RM 86.50'), findsOneWidget); // since the 7th
        expect(find.text('spent this month'), findsOneWidget);
        expect(find.text('avg RM 43.25 a day'), findsOneWidget);
        // Where it went: three categories, and a labelled way to the rest.
        // (Food & Drinks also shows as the category of two transactions.)
        final food = find.text('Food & Drinks').first;
        expect(find.descendant(of: find.byType(InfoRow), matching: find.byType(ShareBar)), findsNWidgets(3));
        expect(find.text('View all categories'), findsOneWidget);
        // The transactions behind it: the latest three.
        expect(find.text('Today, 6:10 pm'), findsOneWidget);
        expect(find.text('Yesterday, 7:15 pm'), findsNothing);
        expect(find.text('View all transactions'), findsOneWidget);

        double top(Finder f) => tester.getTopLeft(f).dy;
        expect(top(find.text('RM 1,780.00')), lessThan(top(find.text('7 Nov – 6 Dec'))));
        expect(top(find.text('7 Nov – 6 Dec')), lessThan(top(find.text('spent this month'))));
        expect(top(find.text('spent this month')), lessThan(top(food)));
        if (size.width < 760) {
          expect(top(food), lessThan(top(find.text('Today, 6:10 pm'))));
        } else {
          // Side by side: the month's breakdown and its transactions start level.
          expect(top(find.byType(Panel).at(1)), top(find.byType(Panel).at(2)));
        }
      });

      testWidgets('categories open in full, with each one\'s places inside', (tester) async {
        await pumpApp(tester, size);
        await tapVisible(tester, find.text('View all categories'));
        expect(find.text('Categories'), findsOneWidget); // titled like the button that opened it
        expect(find.text('7 Nov – 6 Dec'), findsOneWidget);
        expect(find.text('4 payments'), findsOneWidget);
        expect(find.text('Kantin Pejabat'), findsNothing);

        await tapVisible(tester, find.text('Food & Drinks'));
        expect(find.text('Kantin Pejabat'), findsOneWidget); // names in normal case
        expect(find.text('2 times'), findsOneWidget); // 2 canteen visits this month

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('RM 1,780.00'), findsOneWidget);
      });

      testWidgets('the switch shows places instead of categories', (tester) async {
        await pumpApp(tester, size);
        expect(find.text('Grabfood'), findsNothing);
        await tapVisible(tester, find.text('Places'));
        expect(find.text('Grabfood'), findsOneWidget);
        expect(find.text('1 time'), findsWidgets);
        expect(find.text('View all categories'), findsNothing);

        await tapVisible(tester, find.text('View all places'));
        expect(find.text('Places'), findsOneWidget);
        expect(find.text('KTM Berhad'), findsOneWidget); // short codes stay in capitals
      });

      testWidgets('all transactions are grouped by day, with the time, category and notes on their own lines', (
        tester,
      ) async {
        await pumpApp(tester, size);
        await tapVisible(tester, find.text('View all transactions'));
        expect(find.text('Transactions'), findsOneWidget);
        expect(find.text('7 Nov – 6 Dec · 6 transactions'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('RM 24.60'), findsOneWidget); // spent today
        expect(find.text('Yesterday'), findsOneWidget);
        expect(find.text('RM 61.90'), findsOneWidget); // spent yesterday
        expect(find.text('6:10 pm'), findsOneWidget); // just the time inside a day
        expect(find.text('Transport'), findsWidgets);
        expect(find.textContaining('Card transaction of'), findsNothing); // boilerplate hidden
      });

      testWidgets('an earlier month shows only that month, with a way back', (tester) async {
        await pumpApp(tester, size);
        await openMonth(tester, '7 Oct – 6 Nov');
        expect(find.text('spent that month'), findsOneWidget);
        expect(find.text('RM 353.30'), findsOneWidget);
        expect(find.textContaining('left until'), findsNothing); // the wallet is about today
        expect(find.text('to spend a day'), findsNothing);
        expect(find.text('AI & software'), findsWidgets); // not lost in "Other"

        await tapVisible(tester, find.text('Back to current month'));
        expect(find.text('left until 22 Nov'), findsOneWidget);
        expect(find.text('Back to current month'), findsNothing);
      });

      testWidgets('text at 200% still fits everywhere', (tester) async {
        await pumpApp(tester, size, textScale: 2);
        expect(find.text('RM 1,780.00'), findsOneWidget);
        await tapVisible(tester, find.text('View all categories'));
        await tapVisible(tester, find.text('Food & Drinks'));
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('Places'));
        await tapVisible(tester, find.text('View all places'));
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('View all transactions'));
        expect(find.text('Today'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await openMonth(tester, '7 Oct – 6 Nov');
        expect(find.text('Back to current month'), findsOneWidget);
        await tapVisible(tester, find.byTooltip('Settings', skipOffstage: false)); // scrolled away by now
        await tester.ensureVisible(find.text('Disconnect'));
        await tester.pumpAndSettle();
      });
    });
  }

  testWidgets('back from an earlier month returns to the current one, not out of the app', (tester) async {
    await pumpApp(tester, sizes['phone']!);
    await openMonth(tester, '7 Oct – 6 Nov');
    // What Android's back gesture sends.
    final message = const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute'));
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage('flutter/navigation', message, (_) {});
    await tester.pumpAndSettle();
    expect(find.text('left until 22 Nov'), findsOneWidget);
  });

  testWidgets('Escape returns to the current month on desktop', (tester) async {
    await pumpApp(tester, sizes['laptop']!);
    await openMonth(tester, '7 Oct – 6 Nov');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('left until 22 Nov'), findsOneWidget);
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

  testWidgets('first run asks for a token, then shows the dashboard', (tester) async {
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

  testWidgets('a rejected token offers to update it, and keeps the old numbers', (tester) async {
    await pumpApp(tester, sizes['phone']!);
    source.failWith = const WiseException(WiseErrorKind.badToken, 'Wise rejected the token.');
    await tester.tap(find.byTooltip('Update (F5)'));
    await tester.pumpAndSettle();
    expect(find.text('Token not accepted'), findsOneWidget);
    expect(find.text('Wise rejected the token.'), findsOneWidget);
    expect(find.text('Showing saved data from Today, 3:00 pm'), findsOneWidget);
    expect(find.text('Update token'), findsOneWidget);
    expect(find.text('RM 1,780.00'), findsOneWidget);
  });

  testWidgets('the first load shows a skeleton of the dashboard, then the numbers', (tester) async {
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

  testWidgets('the skeleton pulses, but stays still with reduced motion', (tester) async {
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
