// The app lock and the privacy cover: when it locks, what it never blocks, and what the app switcher sees.
import 'package:anchor/features/lock/lock_screen.dart';
import 'package:anchor/features/urge/urge_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_lock.dart';
import 'fakes/scenario.dart';

const bothPlatforms = TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS});

Future<void> leaveApp(WidgetTester t) async {
  for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
    t.binding.handleAppLifecycleStateChanged(s);
    await t.pump();
  }
}

Future<void> returnToApp(WidgetTester t) async {
  for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
    t.binding.handleAppLifecycleStateChanged(s);
    await t.pump();
  }
  await t.pump(const Duration(milliseconds: 50));
}

void main() {
  group('cold start', () {
    testWidgets('locked, and the system prompt appears straight away; success opens the app', variant: bothPlatforms, (t) async {
      final s = await Scenario.create();
      final lock = FakeAppLock(supported: true, result: true);
      await s.launch(t, lock: lock);
      await t.pumpAndSettle();
      expect(lock.reasons, ['Unlock Anchor']);
      expect(find.text('How was today?'), findsOneWidget);
      expect(find.text('Anchor is locked'), findsNothing);
    });

    testWidgets('a failed prompt keeps it locked, says nothing about the app, and the button asks again', variant: bothPlatforms, (t) async {
      final s = await Scenario.create();
      final lock = FakeAppLock(supported: true, result: false);
      await s.launch(t, lock: lock);
      await t.pumpAndSettle();
      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.text('Anchor is locked'), findsOneWidget);
      expect(find.text('How was today?'), findsNothing);
      expect(find.textContaining('Teo'), findsNothing, reason: 'nothing about the pod is visible while locked');

      lock.result = true;
      await t.tap(find.text('Unlock'));
      await t.pumpAndSettle();
      expect(lock.reasons.length, 2);
      expect(find.text('How was today?'), findsOneWidget);
    });

    testWidgets('Urge is reachable from the lock screen, and the lock is still there afterwards', variant: bothPlatforms, (t) async {
      final s = await Scenario.create();
      await s.launch(t, lock: FakeAppLock(supported: true, result: false));
      await t.pumpAndSettle();
      await t.tap(find.text('Urge'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(UrgeScreen), findsOneWidget, reason: 'a crisis must never be stuck behind a fingerprint');
      expect(s.server.urges.length, 1, reason: 'and the ping goes out as usual');

      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Anchor is locked'), findsOneWidget);
    });

    testWidgets('no lock when the phone cannot lock', (t) async {
      final s = await Scenario.create();
      await s.launch(t, lock: FakeAppLock(supported: false));
      await t.pumpAndSettle();
      expect(find.text('How was today?'), findsOneWidget);
    });

    testWidgets('no lock when you turned it off', (t) async {
      final s = await Scenario.create(extraPrefs: {'anchor.applock': 'off'});
      final lock = FakeAppLock(supported: true);
      await s.launch(t, lock: lock);
      await t.pumpAndSettle();
      expect(find.text('How was today?'), findsOneWidget);
      expect(lock.reasons, isEmpty);
    });

    testWidgets('nothing to protect before pairing: no lock', (t) async {
      final s = await Scenario.create(paired: false);
      final lock = FakeAppLock(supported: true);
      await s.launch(t, lock: lock);
      await t.pumpAndSettle();
      expect(find.text('Pair with one person you trust'), findsOneWidget);
      expect(lock.reasons, isEmpty);
    });

    testWidgets('nor before onboarding', (t) async {
      final s = await Scenario.create(onboarded: false);
      final lock = FakeAppLock(supported: true);
      await s.launch(t, lock: lock);
      await t.pumpAndSettle();
      expect(find.text('Two people. One honest line a day.'), findsOneWidget);
      expect(lock.reasons, isEmpty);
    });
  });

  group('coming back to the app', () {
    testWidgets('locks after 30 seconds away, not before', (t) async {
      final s = await Scenario.create();
      final lock = FakeAppLock(supported: true);
      await s.launch(t, lock: lock);
      await t.pumpAndSettle();
      expect(find.text('How was today?'), findsOneWidget);

      await leaveApp(t);
      s.server.advance(const Duration(seconds: 29));
      await returnToApp(t);
      expect(find.text('How was today?'), findsOneWidget, reason: '29 seconds is a glance, not an absence');
      expect(lock.reasons.length, 1, reason: 'no new prompt');

      lock.result = false;
      await leaveApp(t);
      s.server.advance(const Duration(seconds: 31));
      await returnToApp(t);
      await t.pumpAndSettle();
      expect(find.text('Anchor is locked'), findsOneWidget);
      expect(find.text('How was today?'), findsNothing);
    });

    testWidgets('and unlocking afterwards does not lock it again', (t) async {
      final s = await Scenario.create();
      final lock = FakeAppLock(supported: true, result: true);
      await s.launch(t, lock: lock);
      await t.pumpAndSettle();
      await leaveApp(t);
      s.server.advance(const Duration(minutes: 5));
      await returnToApp(t);
      await t.pumpAndSettle();
      expect(find.text('How was today?'), findsOneWidget, reason: 'locked, prompted, unlocked');
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive); // a stray inactive/resume (the prompt closing)
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed); // must not lock it again
      await t.pump();
      await t.pumpAndSettle();
      expect(find.text('How was today?'), findsOneWidget);
    });
  });

  group('app switcher cover', () {
    testWidgets('shows nothing the moment the app is no longer active, and goes away when it returns', variant: bothPlatforms, (t) async {
      final s = await Scenario.create();
      await s.launch(t, lock: FakeAppLock());
      await t.pumpAndSettle();
      expect(find.byType(PrivacyCover), findsNothing);

      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      expect(find.byType(PrivacyCover), findsOneWidget);

      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(find.byType(PrivacyCover), findsNothing);
    });

    testWidgets('not drawn when you turned it off', (t) async {
      final s = await Scenario.create(extraPrefs: {'anchor.hide': 'off'});
      await s.launch(t, lock: FakeAppLock());
      await t.pumpAndSettle();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      expect(find.byType(PrivacyCover), findsNothing);
    });

    testWidgets('the Android screenshot block follows the setting', (t) async {
      final s = await Scenario.create();
      final privacy = FakePrivacy();
      await s.launch(t, lock: FakeAppLock(), privacy: privacy);
      await t.pumpAndSettle();
      expect(privacy.calls.last, isTrue, reason: 'on by default');

      await t.tap(find.text('Pod').last);
      await t.pumpAndSettle();
      await t.tap(find.text('Hide in app switcher'));
      await t.pumpAndSettle();
      expect(privacy.calls.last, isFalse);
      expect((await SharedPreferences.getInstance()).getString('anchor.hide'), 'off');
    });
  });

  group('settings', () {
    Future<void> podTab(WidgetTester t) async {
      await t.tap(find.text('Pod').last);
      await t.pumpAndSettle();
    }

    testWidgets('turning the lock off asks the system first, so someone holding your unlocked phone cannot', variant: bothPlatforms, (t) async {
      final s = await Scenario.create();
      final lock = FakeAppLock(supported: true, result: true);
      await s.launch(t, lock: lock);
      await t.pumpAndSettle();
      await podTab(t);
      final before = lock.reasons.length;

      await t.tap(find.text('App lock'));
      await t.pumpAndSettle();
      expect(lock.reasons.length, greaterThan(before), reason: 'asked the system before changing it');
      expect((await SharedPreferences.getInstance()).getString('anchor.applock'), 'off');

      lock.result = false; // a wrong fingerprint changes nothing
      await t.tap(find.text('App lock'));
      await t.pumpAndSettle();
      expect((await SharedPreferences.getInstance()).getString('anchor.applock'), 'off');
    });

    testWidgets('a phone that cannot lock says so, and the switch is off and disabled', (t) async {
      final s = await Scenario.create();
      await s.launch(t, lock: FakeAppLock(supported: false));
      await t.pumpAndSettle();
      await podTab(t);
      expect(find.text('Not available on this phone'), findsOneWidget);
    });

    testWidgets('and one that can describes it', (t) async {
      final s = await Scenario.create();
      await s.launch(t, lock: FakeAppLock(supported: true));
      await t.pumpAndSettle();
      await podTab(t);
      expect(find.text("Face, fingerprint or your phone's passcode"), findsOneWidget);
    });
  });
}
