import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import 'activity_page.dart';
import 'now_page.dart';
import 'spending_page.dart';
import 'theme.dart';
import 'widgets.dart';

/// Below this width the tabs sit at the bottom, where a thumb reaches them. Above it
/// (tablets, computers) they become a rail on the left, so they don't stretch across.
const double railFrom = 600;

const _tabs = [
  (AppTab.now, 'Now', Icons.speed_outlined, Icons.speed),
  (AppTab.activity, 'Activity', Icons.receipt_long_outlined, Icons.receipt_long),
  (AppTab.spending, 'Spending', Icons.bar_chart_outlined, Icons.bar_chart),
];

/// The app once connected: three tabs, one question each.
///   Now: am I OK until payday?
///   Activity: what did I spend?
///   Spending: where does my money go?
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final rail = MediaQuery.sizeOf(context).width >= railFrom;
    final index = c.tab.index;

    // Each tab keeps its scroll position and search while you're elsewhere.
    final body = IndexedStack(index: index, children: const [NowPage(), ActivityPage(), SpendingPage()]);

    void select(int i) {
      if (i != index) HapticFeedback.selectionClick();
      c.selectTab(AppTab.values[i]);
    }

    return PopScope(
      // Back steps out: an earlier month to this month, another tab to Now, then out of the app.
      canPop: c.tab == AppTab.now && c.showingCurrent,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (c.tab == AppTab.spending && !c.showingCurrent) {
          c.showCurrent();
        } else {
          c.selectTab(AppTab.now);
        }
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.f5): c.refresh,
          const SingleActivator(LogicalKeyboardKey.keyR, control: true): c.refresh,
          const SingleActivator(LogicalKeyboardKey.keyR, meta: true): c.refresh,
          if (c.tab == AppTab.spending && !c.showingCurrent)
            const SingleActivator(LogicalKeyboardKey.escape): c.showCurrent,
          for (var i = 0; i < _tabs.length; i++) ...{
            SingleActivator(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i), control: true): () => select(i),
            SingleActivator(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i), meta: true): () => select(i),
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: rail
                ? Row(
                    children: [
                      NavigationRail(
                        selectedIndex: index,
                        onDestinationSelected: select,
                        groupAlignment: -1,
                        minWidth: 88,
                        destinations: [
                          for (final (_, label, icon, selected) in _tabs)
                            NavigationRailDestination(
                              icon: Icon(icon),
                              selectedIcon: Icon(selected),
                              label: Text(label),
                              padding: const EdgeInsets.symmetric(vertical: Space.xs),
                            ),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: SafeArea(left: false, child: body)),
                    ],
                  )
                : SafeArea(bottom: false, child: body),
            bottomNavigationBar: rail
                ? null
                : DecoratedBox(
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Palette.line)),
                    ),
                    child: NavigationBar(
                      selectedIndex: index,
                      onDestinationSelected: select,
                      destinations: [
                        for (final (_, label, icon, selected) in _tabs)
                          NavigationDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: label),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
