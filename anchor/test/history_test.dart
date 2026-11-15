// The History tab: the month at a glance, the day sheet, the two numbers, and the empty and early-month cases.
import 'package:anchor/app/shell.dart';
import 'package:anchor/core/local_day.dart';
import 'package:anchor/features/rings/ring_model.dart';
import 'package:anchor/features/rings/slab.dart';
import 'package:anchor/features/today/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

const bothPlatforms = TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS});

CheckIn at(PledgeState s, int day, {String? note}) => CheckIn(state: s, at: DateTime(2026, 11, day, 21), note: note);

/// Mika: Nov 8 held, 9 held, 10 slipped (note), 11 held, 12 silent, 13 held, 14 (today) pending.
SoloData mika() => onboardedMika(
      started: dayOf(2026, 11, 8),
      checkIns: {
        '2026-11-08': at(PledgeState.held, 8),
        '2026-11-09': at(PledgeState.held, 9),
        '2026-11-10': at(PledgeState.slipped, 10, note: 'Hard night'),
        '2026-11-11': at(PledgeState.held, 11),
        '2026-11-13': at(PledgeState.held, 13),
      },
      logs: {
        '2026-11-10': {'gym'},
        '2026-11-11': {'read', 'gym'},
      },
    );

Future<void> openHistory(WidgetTester t, {TargetPlatform platform = TargetPlatform.android, double textScale = 1, SoloData? data, bool paired = true}) async {
  seedSolo(data ?? mika(), paired);
  t.view.physicalSize = const Size(400, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(harness(const AnchorShell(), platform: platform, textScale: textScale));
  await t.pumpAndSettle();
  await t.tap(find.text('History'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('a month of two people: glyphs for each day they existed, nothing for days that did not happen', variant: bothPlatforms, (t) async {
    await openHistory(t);
    expect(find.text('November 2026'), findsOneWidget);
    // Mika: Nov 8..14 = 7 glyphs. Teo: Nov 1..14 = 14 glyphs (held every day since Oct 24). Legend: 3. No future days.
    expect(find.byType(RingGlyph), findsNWidgets(7 + 14 + 3));
    expect(find.text('Held'), findsOneWidget);
    expect(find.text('Slipped'), findsOneWidget);
    expect(find.text('Not checked in'), findsOneWidget, reason: 'the legend names every shape in words');
    expect(find.text('Mika on the left, Teo on the right'), findsOneWidget);
  });

  testWidgets('two numbers each, side by side and equal: best streak and days held this month', (t) async {
    await openHistory(t);
    expect(find.text('Best streak'), findsNWidgets(2));
    expect(find.text('Held this month'), findsNWidgets(2));
    // Mika: best run 2 (Nov 8-9), 4 days held this month. Teo: best run 22, 14 days held this month.
    expect(find.text('2 days'), findsOneWidget);
    expect(find.text('4 days'), findsOneWidget);
    expect(find.text('22 days'), findsOneWidget);
    expect(find.text('14 days'), findsOneWidget);
  });

  testWidgets('every day is one tappable thing that says what happened in words', (t) async {
    final handle = t.ensureSemantics();
    await openHistory(t);
    expect(find.bySemanticsLabel(RegExp(r'Nov 10.*Mika slipped, Teo held')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Nov 12.*Mika not checked in, Teo held')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Nov 3.*Teo held')), findsOneWidget, reason: 'before Mika started: only Teo is mentioned');
    handle.dispose();
  });

  testWidgets('tapping a day opens what happened: pledge, note, habits, for each of you', variant: bothPlatforms, (t) async {
    await openHistory(t);
    await t.tap(find.bySemanticsLabel(RegExp(r'Nov 10')));
    await t.pumpAndSettle();
    expect(find.text('Tuesday, November 10, 2026'), findsOneWidget);
    expect(find.text('Mika: Slipped'), findsOneWidget);
    expect(find.text('Hard night'), findsOneWidget);
    expect(find.text('Habits 1 of 2 · Workout (30 min)'), findsOneWidget);
    expect(find.text('Teo: Held the line'), findsOneWidget);
  });

  testWidgets('a silent day is "not checked in", never a slip', (t) async {
    await openHistory(t);
    await t.tap(find.bySemanticsLabel(RegExp(r'Nov 12')));
    await t.pumpAndSettle();
    expect(find.text('Mika: Not checked in'), findsOneWidget);
    expect(find.text('Mika: Slipped'), findsNothing);
  });

  testWidgets('earlier months: Teo from Oct 24, nothing for Mika, and no going back past where it began', (t) async {
    await openHistory(t);
    await t.tap(find.byTooltip('Previous month'));
    await t.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.byType(RingGlyph), findsNWidgets(8 + 3), reason: "Teo: Oct 24-31; Mika hadn't started");
    expect(find.text('Best streak'), findsNWidgets(2));
    expect(tester(t).widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_left)).onPressed, isNull, reason: 'October is where it began');

    await t.tap(find.byTooltip('Next month'));
    await t.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
    expect(tester(t).widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNull, reason: 'no future months');
  });

  testWidgets('before there is anything to show, a quiet line, not an empty grid', (t) async {
    await openHistory(t, data: const SoloData(name: 'Mika', onboarded: true), paired: false);
    expect(find.text('Your first ring forms tonight.'), findsOneWidget);
    expect(find.byType(RingGlyph), findsNothing);
  });

  testWidgets('solo (no partner): only your own glyphs and numbers', (t) async {
    await openHistory(t, paired: false);
    expect(find.byType(RingGlyph), findsNWidgets(7 + 3));
    expect(find.text('Best streak'), findsOneWidget);
    expect(find.textContaining('on the left'), findsNothing);
  });

  testWidgets('at 200% text the grid still fits', (t) async {
    await openHistory(t, textScale: 2);
    expect(tester(t).takeException(), isNull);
    expect(find.text('November 2026'), findsOneWidget);
  });
}

WidgetTester tester(WidgetTester t) => t;
