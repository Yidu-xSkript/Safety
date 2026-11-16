// The Phase 1 acceptance path (log a full day, survive a restart, roll over at 04:00) on both platforms, plus
// onboarding up to the pairing choice. Storage is fake preferences, time is a controllable clock, and the
// partner is a cached synthetic Teo (no server: the backend is "unconfigured").
import 'package:anchor/core/app_lock.dart';
import 'package:anchor/features/rings/ring_model.dart';
import 'package:anchor/features/rings/slab.dart';
import 'package:anchor/features/today/solo_controller.dart';
import 'package:anchor/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_lock.dart';
import 'harness.dart';

final textField = find.byWidgetPredicate((w) => w is TextField || w is CupertinoTextField);
var now = testNow;

Future<void> launch(WidgetTester t) async {
  t.view.physicalSize = const Size(400, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [clockProvider.overrideWithValue(() => now), appLockServiceProvider.overrideWithValue(FakeAppLock())],
    child: const AnchorApp(),
  ));
  await t.pumpAndSettle();
}

Future<void> tapText(WidgetTester t, String text) async {
  await t.tap(find.text(text).last);
  await t.pumpAndSettle();
}

SoloState solo(WidgetTester t) => ProviderScope.containerOf(t.element(find.byType(AnchorApp))).read(soloProvider).requireValue;

Future<void> resumeApp(WidgetTester t) async {
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await t.pumpAndSettle();
}

// TargetPlatformVariant sets and clears the platform override safely around each run.
const bothPlatforms = TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS});

void main() {
  setUp(() {
    now = testNow;
    seedSolo();
  });

  testWidgets('onboarding: welcome, name, habits, then the pairing choice', variant: bothPlatforms, (t) async {
    await launch(t);
    expect(find.text('Two people. One honest line a day.'), findsOneWidget);
    expect(find.textContaining("isn't treatment"), findsOneWidget);
    await tapText(t, 'Get started');

    await tapText(t, 'Continue'); // empty name: nothing happens
    expect(find.text('What should we call you?'), findsOneWidget);
    await t.enterText(textField, 'Mika');
    await t.pump();
    await tapText(t, 'Continue');

    expect(find.text('Pick a few daily habits'), findsOneWidget);
    await tapText(t, 'Reading');
    await tapText(t, 'Workout (30 min)');
    await tapText(t, 'Start');

    expect(find.text('Pair with one person you trust'), findsOneWidget, reason: 'onboarding ends at pairing, not Today');
    expect(solo(t).data.onboarded, isTrue);
    expect(solo(t).data.habits.map((h) => h.title), ['Reading', 'Workout (30 min)']);
  });

  testWidgets('log a day, restart, roll over at 04:00', variant: bothPlatforms, (t) async {
    seedSolo(onboardedMika(started: DateTime.utc(2026, 11, 14)), true);
    await launch(t);

    expect(find.text('Mika & Teo'), findsWidgets);
    expect(find.text('How was today?'), findsOneWidget);
    expect(find.text('0 of 2'), findsOneWidget);

    // --- Pledge held, tick a habit
    await tapText(t, 'Held the line');
    expect(find.text('Held the line · 12:00 PM'), findsOneWidget);
    expect(find.text('Teo can see it.'), findsOneWidget);
    expect(find.text('How was today?'), findsNothing);
    await tapText(t, 'Reading');
    expect(find.text('1 of 2'), findsOneWidget);
    expect(solo(t).habitsToday, (done: 1, total: 2));

    // --- Change the answer; "Not yet" saves nothing
    await tapText(t, "Change today's answer");
    await tapText(t, 'I slipped');
    expect(find.text('Thank you for telling the truth.'), findsOneWidget);
    expect(find.textContaining('Teo will see this'), findsOneWidget);
    await t.enterText(textField, 'Hard night');
    await t.pump();
    await tapText(t, 'Not yet');
    expect(find.text('Thank you for telling the truth.'), findsNothing);
    expect(solo(t).pledge!.state, PledgeState.held, reason: '"Not yet" must not overwrite the earlier answer');

    // --- Save the slip with a note
    await tapText(t, 'I slipped');
    await t.enterText(textField, 'Hard night');
    await t.pump();
    await tapText(t, 'Tell Teo');
    expect(find.text('Slipped · 12:00 PM'), findsOneWidget);
    expect(find.text('Told. Tomorrow is a new ring. The tree keeps growing.'), findsOneWidget);
    expect(find.text('Hard night'), findsOneWidget);
    expect(solo(t).pledge!.state, PledgeState.slipped);
    expect(solo(t).pledge!.note, 'Hard night');

    // --- Restart: a fresh app over the same storage lands straight on Today with everything intact
    await t.pumpWidget(const SizedBox());
    await launch(t);
    expect(find.text('Two people. One honest line a day.'), findsNothing);
    expect(find.text('Slipped · 12:00 PM'), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);

    // --- 02:00 is still "today"; 04:00 starts the next day with a fresh pledge card
    now = DateTime(2026, 11, 15, 2);
    await resumeApp(t);
    expect(find.text('Slipped · 12:00 PM'), findsOneWidget);
    now = DateTime(2026, 11, 15, 4);
    await resumeApp(t);
    expect(find.text('How was today?'), findsOneWidget);
    expect(find.text('0 of 2'), findsOneWidget);
    // yesterday's slip stays in the record
    expect(solo(t).data.pledgeOn(solo(t).today.subtract(const Duration(days: 1))), PledgeState.slipped);
  });

  testWidgets('a brand-new pair shows only today in your own row of the week strip', variant: bothPlatforms, (t) async {
    seedSolo(onboardedMika(started: DateTime.utc(2026, 11, 14)), true);
    await launch(t);
    // 7 partner glyphs + 1 for you: days before you started did not happen, so they are not "unchecked"
    expect(find.byType(RingGlyph), findsNWidgets(8));
  });
}
