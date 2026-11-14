import 'package:anchor/app/shell.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void setSize(WidgetTester t, double w, double h) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  testWidgets('Android phone: NavigationBar with three tabs and an Urge FAB that opens the Urge screen', (t) async {
    setSize(t, 400, 800);
    await t.pumpWidget(harness(const AnchorShell()));
    await t.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    expect(find.descendant(of: fab, matching: find.text('Urge')), findsOneWidget);

    await t.tap(fab);
    await t.pumpAndSettle();
    expect(find.textContaining('Urge flow'), findsOneWidget);
    await t.tap(find.text('Close'));
    await t.pumpAndSettle();
    expect(find.textContaining('Urge flow'), findsNothing);
  });

  testWidgets('Android tablet width switches to a NavigationRail', (t) async {
    setSize(t, 900, 800);
    await t.pumpWidget(harness(const AnchorShell()));
    await t.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('Android tab switching keeps the shell and shows each tab title', (t) async {
    setSize(t, 400, 800);
    await t.pumpWidget(harness(const AnchorShell()));
    await t.tap(find.text('History'));
    await t.pumpAndSettle();
    expect(find.text('Your first ring forms tonight.'), findsOneWidget);
    await t.tap(find.text('Pod'));
    await t.pumpAndSettle();
    expect(find.text('Your pod will live here.'), findsOneWidget);
  });

  testWidgets('iOS: Cupertino tab bar, no FAB, Urge is a toolbar action', (t) async {
    setSize(t, 400, 800);
    await t.pumpWidget(harness(const AnchorShell(), platform: TargetPlatform.iOS));
    await t.pumpAndSettle();

    expect(find.byType(CupertinoTabBar), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);

    await t.tap(find.widgetWithText(CupertinoButton, 'Urge'));
    await t.pumpAndSettle();
    expect(find.textContaining('Urge flow'), findsOneWidget);
  });

  testWidgets('Today reads as one semantic label per slab', (t) async {
    setSize(t, 400, 800);
    final handle = t.ensureSemantics();
    await t.pumpWidget(harness(const AnchorShell()));
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp(r'^Mika: 14 days held\. Today: habits 3 of 4, pledge not checked in\.')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Teo: 22 days held\.')), findsOneWidget);
    handle.dispose();
  });
}
