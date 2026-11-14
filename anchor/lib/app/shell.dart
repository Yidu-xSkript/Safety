import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/adaptive/adaptive_page.dart';
import '../features/history/history_page.dart';
import '../features/pod/pod_page.dart';
import '../features/today/today_page.dart';
import '../features/urge/urge_flow.dart';
import '../l10n/app_localizations.dart';

/// Today · History · Pod. Android: NavigationBar (<600dp) or NavigationRail (>=600dp) + extended Urge FAB.
/// iOS: tab bar; Urge is each page's trailing toolbar action.
class AnchorShell extends StatefulWidget {
  const AnchorShell({super.key});

  @override
  State<AnchorShell> createState() => _AnchorShellState();
}

class _AnchorShellState extends State<AnchorShell> {
  int _index = 0;

  void _urge() => openUrge(context);

  List<Widget> get _pages => [
        TodayPage(onUrge: _urge),
        HistoryPage(onUrge: _urge),
        PodPage(onUrge: _urge),
      ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (isIOS(context)) return _ios(l);
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth >= 600 ? _androidRail(l) : _androidBar(l),
    );
  }

  Widget _ios(AppLocalizations l) {
    final pages = _pages;
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: [
          BottomNavigationBarItem(icon: const Icon(CupertinoIcons.sun_max), label: l.tabToday),
          BottomNavigationBarItem(icon: const Icon(CupertinoIcons.calendar), label: l.tabHistory),
          BottomNavigationBarItem(icon: const Icon(CupertinoIcons.person_2), label: l.tabPod),
        ],
      ),
      tabBuilder: (context, i) => pages[i],
    );
  }

  Widget _urgeFab(AppLocalizations l) => FloatingActionButton.extended(
        onPressed: _urge,
        tooltip: l.urgeTooltip,
        icon: const Icon(Icons.anchor),
        label: Text(l.urge),
      );

  Widget _androidBar(AppLocalizations l) => Scaffold(
        body: SafeArea(top: false, bottom: false, child: IndexedStack(index: _index, children: _pages)),
        floatingActionButton: _urgeFab(l),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(icon: const Icon(Icons.today_outlined), selectedIcon: const Icon(Icons.today), label: l.tabToday),
            NavigationDestination(
                icon: const Icon(Icons.calendar_month_outlined), selectedIcon: const Icon(Icons.calendar_month), label: l.tabHistory),
            NavigationDestination(icon: const Icon(Icons.people_outline), selectedIcon: const Icon(Icons.people), label: l.tabPod),
          ],
        ),
      );

  Widget _androidRail(AppLocalizations l) => Scaffold(
        floatingActionButton: _urgeFab(l),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                NavigationRailDestination(
                    icon: const Icon(Icons.today_outlined), selectedIcon: const Icon(Icons.today), label: Text(l.tabToday)),
                NavigationRailDestination(
                    icon: const Icon(Icons.calendar_month_outlined),
                    selectedIcon: const Icon(Icons.calendar_month),
                    label: Text(l.tabHistory)),
                NavigationRailDestination(
                    icon: const Icon(Icons.people_outline), selectedIcon: const Icon(Icons.people), label: Text(l.tabPod)),
              ],
            ),
            Expanded(child: IndexedStack(index: _index, children: _pages)),
          ],
        ),
      );
}
