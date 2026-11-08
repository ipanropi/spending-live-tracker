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

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    group(name, () {
      testWidgets('dashboard shows the numbers, number first', (tester) async {
        await pumpApp(tester, size);
        expect(find.text('7 Nov – 6 Dec'), findsOneWidget);
        expect(find.text('Updated just now'), findsOneWidget);
        expect(find.text('RM 1,780.00'), findsOneWidget);
        expect(find.text('left until 22 Nov'), findsOneWidget);
        expect(find.text('14 days left'), findsOneWidget);
        expect(find.text('RM 127.14'), findsOneWidget);
        expect(find.text('per day'), findsOneWidget);
        expect(find.text('RM 345.90'), findsOneWidget); // since Monday 2 Nov
        expect(find.text('spent this week'), findsOneWidget);
        expect(find.text('RM 86.50'), findsOneWidget); // since the 7th
        expect(find.text('avg RM 43.25 a day'), findsOneWidget);
        expect(find.text('By category'), findsOneWidget);
        expect(find.text('Top places'), findsOneWidget);
        expect(find.text('Transactions'), findsOneWidget);
        expect(find.text('Today, 6:10 pm'), findsOneWidget); // recent days by name
      });

      testWidgets('categories open a full view with dropdowns of places', (tester) async {
        await pumpApp(tester, size);
        await tapVisible(tester, find.text('By category'));
        expect(find.text('7 Nov – 6 Dec'), findsOneWidget); // the page's subtitle
        expect(find.text('Food & Drinks'), findsOneWidget);
        expect(find.text('4 payments'), findsOneWidget);
        expect(find.text('KANTIN PEJABAT'), findsNothing);

        await tapVisible(tester, find.text('Food & Drinks'));
        expect(find.text('KANTIN PEJABAT'), findsOneWidget);
        expect(find.text('2 times'), findsOneWidget); // 2 canteen visits this month

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('RM 1,780.00'), findsOneWidget);
      });

      testWidgets('all transactions are grouped by day, with the time, category and notes on their own lines', (
        tester,
      ) async {
        await pumpApp(tester, size);
        await tapVisible(tester, find.text('Transactions'));
        expect(find.text('All transactions'), findsOneWidget);
        expect(find.text('7 Nov – 6 Dec · 6 transactions'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('RM 24.60'), findsOneWidget); // spent today
        expect(find.text('Yesterday'), findsOneWidget);
        expect(find.text('RM 61.90'), findsOneWidget); // spent yesterday
        expect(find.text('6:10 pm'), findsOneWidget); // just the time inside a day
        expect(find.text('Transport'), findsWidgets);
        expect(find.textContaining('Card transaction of'), findsNothing); // boilerplate hidden
      });

      testWidgets('a past month shows only what was spent', (tester) async {
        await pumpApp(tester, size);
        await tester.tap(find.text('7 Nov – 6 Dec'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('7 Oct – 6 Nov').last);
        await tester.pumpAndSettle();
        expect(find.text('spent in 7 Oct – 6 Nov'), findsOneWidget);
        expect(find.textContaining('left until'), findsNothing);
        expect(find.text('per day'), findsNothing);
      });

      testWidgets('text at 200% still fits everywhere', (tester) async {
        await pumpApp(tester, size, textScale: 2);
        expect(find.text('RM 1,780.00'), findsOneWidget);
        await tapVisible(tester, find.text('By category'));
        await tapVisible(tester, find.text('Food & Drinks'));
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('Transactions'));
        expect(find.text('Today'), findsOneWidget);
      });
    });
  }

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
