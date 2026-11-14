// The grounding screen as a person meets it: instant, honest about whether the partner knows, one step at a time.
import 'package:anchor/features/pod/pod_controller.dart';
import 'package:anchor/features/urge/urge_screen.dart';
import 'package:anchor/main.dart';
import 'package:anchor/core/backend/pod_backend.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/scenario.dart';

const bothPlatforms = TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS});
final textField = find.byWidgetPredicate((w) => w is TextField || w is CupertinoTextField);

Future<void> pressUrge(WidgetTester t) async {
  // Android: the extended FAB. iOS: the trailing toolbar action. Both are labelled "Urge".
  await t.tap(find.text('Urge').last);
  await t.pump(); // the route is pushed...
  await t.pump(const Duration(milliseconds: 400)); // ...and has finished sliding in
}

Future<void> seconds(WidgetTester t, int n) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(seconds: 1));
  }
}

PodState podState(WidgetTester t) => ProviderScope.containerOf(t.element(find.byType(AnchorApp))).read(podProvider).requireValue;

void main() {
  testWidgets('opens within two frames, with the network down, and says the partner will be told', variant: bothPlatforms, (t) async {
    final s = await Scenario.create();
    await s.launch(t, online: false);

    await t.tap(find.text('Urge').last);
    await t.pump();
    await t.pump(); // two frames after the tap (about 30 ms): the screen is there, before any network answer
    expect(find.text('Stay with me for three minutes.'), findsOneWidget);
    expect(find.text("Teo will be told the moment you're back online. The next three minutes are yours."), findsOneWidget);
    expect(find.text('Stand up.'), findsOneWidget);
    expect(find.text('3:00'), findsOneWidget);
    expect(find.text('In.'), findsOneWidget);
    expect(s.server.urges, isEmpty, reason: 'nothing could be sent, and the screen did not wait for it');

    // connectivity returns: the queued ping goes out by itself and the copy changes
    s.mika.online = true;
    await t.pump(const Duration(seconds: 31));
    expect(s.server.urges.length, 1);
    expect(find.text('Teo has been told.'), findsOneWidget);
  });

  testWidgets('online: the partner is told at once', variant: bothPlatforms, (t) async {
    final s = await Scenario.create();
    await s.launch(t);
    await pressUrge(t);
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Teo has been told.'), findsOneWidget);
    expect(s.server.urges.length, 1);
    expect(s.server.urges.values.single.user, 'mika');
  });

  testWidgets('one instruction a minute, a visible countdown, no flashing text', (t) async {
    final s = await Scenario.create();
    await s.launch(t);
    await pressUrge(t);

    await seconds(t, 59);
    expect(find.text('Stand up.'), findsOneWidget);
    expect(find.text('2:01'), findsOneWidget);
    await seconds(t, 1);
    await t.pump(const Duration(seconds: 1)); // the cross-fade
    expect(find.text('Drink a glass of water.'), findsOneWidget);
    expect(find.text('Stand up.'), findsNothing, reason: 'one instruction at a time');
    await seconds(t, 60);
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Put the phone in another room, or face down.'), findsOneWidget);
    expect(s.server.urges.length, 1);
  });

  testWidgets('the breath: In. for four seconds, Out. for six', (t) async {
    final s = await Scenario.create();
    await s.launch(t);
    await pressUrge(t);
    await seconds(t, 3);
    expect(find.text('In.'), findsOneWidget);
    await seconds(t, 1);
    expect(find.text('Out.'), findsOneWidget);
    await seconds(t, 6);
    expect(find.text('In.'), findsOneWidget);
  });

  testWidgets('after three minutes: how are you now? "It passed" closes it and resolves the urge', variant: bothPlatforms, (t) async {
    final s = await Scenario.create();
    await s.launch(t);
    await pressUrge(t);
    await seconds(t, 181);
    expect(find.text('How are you now?'), findsOneWidget);
    expect(find.text('That was a mistake'), findsNothing, reason: 'the mistake button belongs to the crisis, not the end');
    await t.pumpAndSettle(); // the breathing ring has come to rest: nothing is animating any more

    await t.tap(find.text('It passed'));
    await t.pumpAndSettle();
    expect(find.byType(UrgeScreen), findsNothing);
    expect(s.server.urges.values.single.outcome, 'passed');
  });

  testWidgets('"I need more time" starts the three minutes again and keeps the urge open', (t) async {
    final s = await Scenario.create();
    await s.launch(t);
    await pressUrge(t);
    await seconds(t, 181);
    await t.tap(find.text('I need more time'));
    await t.pump();
    expect(find.text('3:00'), findsOneWidget);
    expect(find.text('Stand up.'), findsOneWidget);
    expect(s.server.urges.values.single.outcome, isNull, reason: 'still reaching out: not resolved');
  });

  testWidgets('"I slipped" leads gently into the slip sheet and records it', variant: bothPlatforms, (t) async {
    final s = await Scenario.create();
    await s.launch(t);
    await pressUrge(t);
    await seconds(t, 181);
    await t.pumpAndSettle();
    await t.tap(find.text('I slipped'));
    await t.pumpAndSettle();

    expect(find.byType(UrgeScreen), findsNothing);
    expect(find.text('Thank you for telling the truth.'), findsOneWidget);
    await t.enterText(textField, 'It got hard after midnight');
    await t.pump();
    await t.tap(find.text('Tell Teo'));
    await t.pumpAndSettle();
    expect(find.textContaining('Slipped ·'), findsOneWidget);
    expect(s.server.urges.values.single.outcome, 'slipped');
    expect(s.server.checkIns['mika']!.values.single.note, 'It got hard after midnight');
  });

  testWidgets('"That was a mistake" retracts the ping, says all clear, and closes', variant: bothPlatforms, (t) async {
    final s = await Scenario.create();
    await s.launch(t);
    await pressUrge(t);
    await t.pump(const Duration(milliseconds: 50));
    expect(s.server.urges.values.single.retracted, isFalse);

    await t.tap(find.text('That was a mistake'));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('All clear sent.'), findsOneWidget);
    expect(s.server.urges.values.single.retracted, isTrue);
    await t.pump(const Duration(milliseconds: 1500));
    await t.pumpAndSettle();
    expect(find.byType(UrgeScreen), findsNothing);
  });

  testWidgets('the partner\'s reply appears on the screen, tied to this urge', (t) async {
    final s = await Scenario.create();
    await s.launch(t);
    await pressUrge(t);
    await t.pump(const Duration(milliseconds: 50));
    final id = s.server.urges.keys.single;

    await s.teo.send(ReplyOp(podId: s.podId, id: 'r-1', toUser: 'mika', kind: 'urge_reply', template: 'here', urgeId: id));
    await settleRealtime(t);
    expect(find.text("Teo: I'm here."), findsOneWidget);
  });

  testWidgets('back always works', (t) async {
    final s = await Scenario.create();
    await s.launch(t);
    await pressUrge(t);
    expect(find.byType(UrgeScreen), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(UrgeScreen), findsNothing);
  });

  group('without motion', () {
    testWidgets('the ring holds still; the words and a soft tap at each turn carry the breath', (t) async {
      t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final taps = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') taps.add(call.arguments as String);
        return null;
      });
      addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      final s = await Scenario.create();
      await s.launch(t);
      await pressUrge(t);
      expect(t.hasRunningAnimations, isFalse, reason: 'nothing animates');
      expect(find.text('In.'), findsOneWidget);
      await seconds(t, 4);
      expect(find.text('Out.'), findsOneWidget);
      await seconds(t, 6);
      expect(find.text('In.'), findsOneWidget);
      expect(taps.where((x) => x == 'HapticFeedbackType.selectionClick').length, 2, reason: 'one tap at each turn');
    });
  });
}
