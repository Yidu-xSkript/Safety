// The Pod tab and the care features around it: reminder, partner number, notifications, leaving and the ended pod,
// the evening hello, securing the account, and signing back in after a reinstall.
import 'package:anchor/core/backend/pod_backend.dart';
import 'package:anchor/features/pod/account_controller.dart';
import 'package:anchor/features/pod/pod_controller.dart';
import 'package:anchor/features/rings/ring_model.dart';
import 'package:anchor/features/today/solo_controller.dart';
import 'package:anchor/features/urge/urge_screen.dart';
import 'package:anchor/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_backend.dart';
import 'fakes/phone.dart';
import 'fakes/scenario.dart';

const bothPlatforms = TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS});
final textField = find.byWidgetPredicate((w) => w is TextField || w is CupertinoTextField);

Future<void> podTab(WidgetTester t) async {
  await t.tap(find.text('Pod').last);
  await t.pumpAndSettle();
}

Future<void> tapText(WidgetTester t, String text) async {
  await t.tap(find.text(text).last);
  await t.pumpAndSettle();
}

PodState podState(WidgetTester t) => ProviderScope.containerOf(t.element(find.byType(AnchorApp))).read(podProvider).requireValue;

void main() {
  group('the list', () {
    testWidgets('partner, reminder, number, secure, leave: plain rows, nothing alarming', variant: bothPlatforms, (t) async {
      final s = await Scenario.create();
      await s.launch(t);
      await podTab(t);
      for (final row in ['Partner', 'Teo', 'Daily reminder', 'Off', "Partner's number", 'Stays on this phone', 'Secure your pod', 'Leave pod']) {
        expect(find.text(row), findsOneWidget, reason: row);
      }
      expect(find.textContaining("isn't treatment"), findsOneWidget);
      expect(find.text('Need more than a partner?'), findsNothing, reason: 'hidden until the owner supplies a vetted list');
    });
  });

  group('daily reminder', () {
    testWidgets('on: asks the system once, defaults to 9:30 PM, and is remembered', variant: bothPlatforms, (t) async {
      final s = await Scenario.create();
      final rem = FakeReminders();
      await s.launch(t, reminders: rem);
      await podTab(t);

      await t.tap(find.byType(Switch).evaluate().isNotEmpty ? find.byType(Switch) : find.byType(CupertinoSwitch));
      await t.pumpAndSettle();
      expect(rem.permissionRequests, 1);
      expect(find.text('9:30 PM'), findsOneWidget);
      expect(rem.calls.last, (at: const TimeOfDay(hour: 21, minute: 30), skipToday: false));
      expect((await SharedPreferences.getInstance()).getString('anchor.reminder'), '21:30');

      // a restart keeps it and re-schedules it
      await t.pumpWidget(const SizedBox());
      final rem2 = FakeReminders();
      await s.launch(t, reminders: rem2);
      await podTab(t);
      expect(find.text('9:30 PM'), findsOneWidget);
      expect(rem2.calls.last.at, const TimeOfDay(hour: 21, minute: 30));
    });

    testWidgets('once today is answered, today\'s reminder is skipped; off removes it', (t) async {
      final s = await Scenario.create(extraPrefs: {'anchor.reminder': '21:30'});
      final rem = FakeReminders();
      await s.launch(t, reminders: rem);
      expect(rem.calls.last, (at: const TimeOfDay(hour: 21, minute: 30), skipToday: false));

      await t.tap(find.text('Held the line'));
      await t.pumpAndSettle();
      expect(rem.calls.last, (at: const TimeOfDay(hour: 21, minute: 30), skipToday: true), reason: 'no nagging after you have checked in');

      await podTab(t);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      expect(rem.calls.last.at, isNull);
      expect(find.text('Off'), findsOneWidget);
    });

    testWidgets('if the system says no, it stays off and says why, plainly', (t) async {
      final s = await Scenario.create();
      final rem = FakeReminders(grant: false);
      await s.launch(t, reminders: rem);
      await podTab(t);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      expect(find.text("Notifications are off for Anchor in your phone's settings."), findsOneWidget);
      expect(rem.calls.where((c) => c.at != null), isEmpty);
    });

    testWidgets('the time can be changed', (t) async {
      final s = await Scenario.create(extraPrefs: {'anchor.reminder': '21:30'});
      final rem = FakeReminders();
      await s.launch(t, reminders: rem);
      await podTab(t);
      await t.tap(find.text('9:30 PM'));
      await t.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(find.text('9:30 PM'), findsOneWidget, reason: 'cancel changes nothing');
    });
  });

  group("partner's number", () {
    testWidgets('saved on this phone only; Call and Text then appear when they reach out; removable', (t) async {
      final s = await Scenario.create();
      final opened = <Uri>[];
      await s.launch(t, opener: (u) async {
        opened.add(u);
        return true;
      });
      await podTab(t);
      await tapText(t, "Partner's number");
      expect(find.text('Saved only on this phone. It lets you call or text Teo from here.'), findsOneWidget);
      await t.enterText(textField, '+251911000000');
      await t.pump();
      await tapText(t, 'Save');
      expect(find.text('+251911000000'), findsOneWidget);
      expect((await SharedPreferences.getInstance()).getString('anchor.partner_phone'), '+251911000000');
      expect(s.server.names.values.contains('+251911000000'), isFalse, reason: 'never sent to the server');

      await s.teoReachesOut();
      await settleRealtime(t);
      await tapText(t, 'Today');
      await tapText(t, 'Reply');
      await t.tap(find.text('Call'));
      expect(opened.single.toString(), 'tel:+251911000000');
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();

      await podTab(t);
      await tapText(t, "Partner's number");
      await tapText(t, 'Remove');
      expect(find.text('Stays on this phone'), findsOneWidget);
    });
  });

  group('notifications row', () {
    testWidgets('turn them on again from here', (t) async {
      final s = await Scenario.create(extraPrefs: {'anchor.push.asked': 'no'});
      final push = FakePush();
      await s.launch(t, push: push);
      await podTab(t);
      expect(find.text('Off'), findsWidgets);
      await tapText(t, 'Turn on');
      expect(push.permissionRequests, 1);
      expect(find.text('On'), findsOneWidget);
      expect(s.server.devices['tok-1']?.user, 'mika');
    });
  });

  group('leaving', () {
    testWidgets('a clear question first; cancel changes nothing', variant: bothPlatforms, (t) async {
      final s = await Scenario.create();
      await s.launch(t);
      await podTab(t);
      await tapText(t, 'Leave pod');
      expect(find.text('Leave this pod?'), findsOneWidget);
      expect(find.textContaining("Teo will be told your pod has changed. This can't be undone."), findsOneWidget);
      await tapText(t, 'Cancel');
      expect(find.text('Leave this pod?'), findsNothing);
      expect(s.server.podOf('mika'), isNotNull);
    });

    testWidgets('leaving ends it both ways and returns you to the pairing choice', variant: bothPlatforms, (t) async {
      final s = await Scenario.create();
      await s.launch(t);
      await podTab(t);
      await tapText(t, 'Leave pod');
      await t.tap(find.text('Leave pod').last);
      await t.pumpAndSettle();

      expect(find.text('Pair with one person you trust'), findsOneWidget);
      expect(s.server.podOf('mika'), isNull, reason: 'no membership left');
      expect(s.server.podOf('teo')!.status, PodStatus.archived, reason: 'the pod is archived for Teo');
      // your own history is yours to keep
      expect((await SharedPreferences.getInstance()).getString('anchor.solo.v1'), contains('Mika'));
    });

    testWidgets('the one who stayed sees an ended pod: readable, not writable, with a way to start again', variant: bothPlatforms, (t) async {
      final s = await Scenario.create();
      await s.launch(t);
      expect(find.text('How was today?'), findsOneWidget);

      await s.teo.leavePod();
      await settleRealtime(t);

      expect(find.text('Your pod has ended.'), findsOneWidget);
      expect(find.text('You can still read your history together. Start a new pod when you are ready.'), findsOneWidget);
      expect(find.text('How was today?'), findsNothing, reason: 'nothing can be written any more');
      expect(find.text('Habits'), findsNothing);
      expect(find.text('Waiting on Teo'), findsNothing);

      await tapText(t, 'History'); // still readable
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('Teo'), findsWidgets, reason: 'who they were is kept');

      // the grounding screen still works, and quietly sends nothing
      await t.tap(find.text('Urge').last);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(UrgeScreen), findsOneWidget);
      expect(find.text('Teo has been told.'), findsNothing);
      expect(s.server.urges, isEmpty);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();

      await tapText(t, 'Today');
      await tapText(t, 'Start a new pod');
      expect(find.text('Pair with one person you trust'), findsOneWidget);
    });
  });

  group('say hello', () {
    testWidgets('waiting on Teo; hello appears only in the evening, goes once, and never when they have checked in', variant: bothPlatforms, (t) async {
      final s = await Scenario.create();
      await s.launch(t);
      expect(find.text('Waiting on Teo'), findsOneWidget);
      expect(find.text('Say hello'), findsNothing, reason: 'it is noon: no pestering');

      s.server.advance(const Duration(hours: 7)); // 19:00
      await t.pumpWidget(const SizedBox());
      await s.launch(t);
      expect(find.text('Say hello'), findsOneWidget);
      await tapText(t, 'Say hello');
      expect(find.text('Say hello'), findsNothing, reason: 'once a day');
      expect(s.server.replies.single.kind, 'nudge');
      expect(s.server.replies.single.template, 'hello');
      expect(s.server.replies.single.from, 'mika');

      await t.pumpWidget(const SizedBox()); // even after a restart
      await s.launch(t);
      expect(find.text('Say hello'), findsNothing);
    });

    testWidgets('once Teo has checked in there is nothing to say', (t) async {
      final s = await Scenario.create();
      s.server.advance(const Duration(hours: 7));
      await s.launch(t);
      await s.teo.send(CheckInOp(podId: s.podId, day: DateTime.utc(2026, 11, 14), state: PledgeState.held));
      await settleRealtime(t);
      expect(find.text('Say hello'), findsNothing);
      expect(find.textContaining('Waiting on'), findsNothing);
    });

    testWidgets('in sync when you both have', (t) async {
      final s = await Scenario.create();
      await s.launch(t);
      await s.teo.send(CheckInOp(podId: s.podId, day: DateTime.utc(2026, 11, 14), state: PledgeState.held));
      await settleRealtime(t);
      await tapText(t, 'Held the line');
      expect(find.text('In sync'), findsOneWidget);
    });

    testWidgets('his hello shows up for you, gently', (t) async {
      final s = await Scenario.create();
      await s.launch(t);
      await s.teo.send(ReplyOp(podId: s.podId, id: 'h-1', toUser: 'mika', kind: 'nudge', template: 'hello'));
      await settleRealtime(t);
      expect(find.text('Teo: Just saying hello.'), findsOneWidget);
    });

    test('the server refuses a second hello in a day', () async {
      final s = await Scenario.create();
      await s.teo.send(ReplyOp(podId: s.podId, id: 'h-1', toUser: 'mika', kind: 'nudge', template: 'hello'));
      await expectLater(
        s.teo.send(ReplyOp(podId: s.podId, id: 'h-2', toUser: 'mika', kind: 'nudge', template: 'hello')),
        podError(PodErrorKind.other),
      );
    });
  });

  group('secure your pod', () {
    testWidgets('email, then a code; a wrong code is explained; the right one secures it', variant: bothPlatforms, (t) async {
      final s = await Scenario.create();
      await s.launch(t);
      await podTab(t);
      expect(find.text('Without this, a lost phone means a new pod.'), findsOneWidget);
      await tapText(t, 'Secure your pod');

      // Send code stays disabled until the address looks like one
      await t.enterText(textField, 'mika@');
      await t.pump();
      await t.tap(find.text('Send code'));
      await t.pumpAndSettle();
      expect(find.text('Enter the code'), findsNothing);

      await t.enterText(textField, 'mika@example.com');
      await t.pump();
      await tapText(t, 'Send code');
      expect(find.text('We sent a 6-digit code to mika@example.com.'), findsOneWidget);

      await t.enterText(textField, '000000');
      await t.pump();
      await tapText(t, 'Verify');
      expect(find.text("That code didn't work. Check it and try again."), findsOneWidget);
      expect(s.server.emails, isEmpty);

      await t.enterText(textField, '123456');
      await t.pump();
      await tapText(t, 'Verify');
      expect(find.text('Your pod is secured.'), findsOneWidget);
      expect(s.server.emails['mika'], 'mika@example.com');
      await tapText(t, 'Done');
      expect(find.text('Secured · mika@example.com'), findsOneWidget);
    });

    testWidgets('an email already used by someone else is said plainly', (t) async {
      final s = await Scenario.create();
      s.server.accounts['taken@example.com'] = 'teo';
      await s.launch(t);
      await podTab(t);
      await tapText(t, 'Secure your pod');
      await t.enterText(textField, 'taken@example.com');
      await t.pump();
      await tapText(t, 'Send code');
      expect(find.text('That email is already used by another account.'), findsOneWidget);
    });

    testWidgets('a gentle card from day two, at most twice, and never without a server', (t) async {
      final s = await Scenario.create(started: DateTime.utc(2026, 11, 13)); // yesterday: this is day two
      await s.launch(t);
      expect(find.text('Secure it'), findsOneWidget);
      await tapText(t, 'Not now');
      expect(find.text('Secure it'), findsNothing);

      await t.pumpWidget(const SizedBox());
      await s.launch(t);
      expect(find.text('Secure it'), findsOneWidget, reason: 'asked once, so once more is allowed');
      await tapText(t, 'Not now');

      await t.pumpWidget(const SizedBox());
      await s.launch(t);
      expect(find.text('Secure it'), findsNothing, reason: 'twice is the limit');
    });

    testWidgets('not on day one', (t) async {
      final s = await Scenario.create();
      await s.launch(t);
      expect(find.text('Secure it'), findsNothing);
    });
  });

  group('signing back in after a reinstall', () {
    test('the same account on a new phone brings back the pod, the history and the partner, and uploads nothing', () async {
      final (mika, teo, server) = await pair();
      await mika.solo.setPledge(PledgeState.slipped, note: 'Hard night');
      await mika.solo.toggleHabit(mika.s.data.habits.first);
      await settle();
      await mika.c.read(accountProvider.notifier).requestLink('mika@example.com');
      await mika.c.read(accountProvider.notifier).confirmLink('mika@example.com', '123456');
      await teo.solo.setPledge(PledgeState.held);
      await settle();
      final sent = server.accepted.length;

      final fresh = Phone(server, 'mika-new-phone'); // a different anonymous identity: the phone was wiped
      await fresh.ready();
      expect(fresh.s.data.onboarded, isFalse);
      await fresh.c.read(accountProvider.notifier).requestSignIn('mika@example.com');
      final found = await fresh.c.read(accountProvider.notifier).confirmSignIn('mika@example.com', '123456');
      await settle();

      expect(found, isTrue);
      expect(fresh.s.data.onboarded, isTrue);
      expect(fresh.s.data.name, 'Mika');
      expect(fresh.s.data.habits.map((h) => h.title), ['Reading', 'Workout']);
      expect(fresh.s.pledge?.state, PledgeState.slipped);
      expect(fresh.s.pledge?.note, 'Hard night');
      expect(fresh.p.pod!.active, isTrue);
      expect(fresh.p.pod!.partnerName, 'Teo');
      expect(fresh.p.partner!.pledgeOn(fresh.s.today), PledgeState.held, reason: "Teo's data is there too");
      expect(fresh.p.pending, 0);
      expect(server.accepted.length, sent, reason: 'restoring must not re-upload anything');
    });

    test('a wrong code, an unknown email, and an account with no pod are all handled', () async {
      final (mika, _, server) = await pair();
      await mika.c.read(accountProvider.notifier).requestLink('mika@example.com');
      await mika.c.read(accountProvider.notifier).confirmLink('mika@example.com', '123456');

      final fresh = Phone(server, 'x');
      await fresh.ready();
      final account = fresh.c.read(accountProvider.notifier);
      await expectLater(account.requestSignIn('nobody@example.com'), podError(PodErrorKind.other));
      await account.requestSignIn('mika@example.com');
      await expectLater(account.confirmSignIn('mika@example.com', '000000'), podError(PodErrorKind.invalidOtp));

      // an account that exists but whose pod was left
      final lone = Phone(server, 'lone');
      await lone.onboard('Lone', []);
      await lone.pod.createPod();
      await lone.c.read(accountProvider.notifier).requestLink('lone@example.com');
      await lone.c.read(accountProvider.notifier).confirmLink('lone@example.com', '123456');
      await lone.pod.leavePod();
      final again = Phone(server, 'lone-again');
      await again.ready();
      expect(await again.c.read(accountProvider.notifier).confirmSignIn('lone@example.com', '123456'), isFalse);
    });

    testWidgets('on screen: Welcome, "I already have an account", email, code, and you are back on Today', variant: bothPlatforms, (t) async {
      final s = await Scenario.create(onboarded: false);
      s.server.accounts['mika@example.com'] = 'mika';
      s.server.emails['mika'] = 'mika@example.com';
      final restoredMika = FakeBackend(s.server, 'mika-new');
      await s.teo.send(CheckInOp(podId: s.podId, day: DateTime.utc(2026, 11, 14), state: PledgeState.held)); // Teo has some history
      await s.mika.send(HabitOp(podId: s.podId, id: '00000000-0000-4000-8000-0000000000b1', title: 'Reading', createdDay: DateTime.utc(2026, 11, 1)));

      SharedPreferences.setMockInitialValues({}); // a wiped phone
      t.view.physicalSize = const Size(400, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(s.server.now),
          backendProvider.overrideWithValue(restoredMika),
        ],
        child: const AnchorApp(),
      ));
      await t.pumpAndSettle();

      expect(find.text('Two people. One honest line a day.'), findsOneWidget);
      await tapText(t, 'I already have an account');
      expect(find.text('Welcome back'), findsOneWidget);
      await t.enterText(textField, 'mika@example.com');
      await t.pump();
      await tapText(t, 'Send code');
      await t.enterText(textField, '123456');
      await t.pump();
      await tapText(t, 'Verify');

      expect(find.text('Mika & Teo'), findsWidgets);
      expect(find.text('How was today?'), findsOneWidget);
      expect(find.text('Reading'), findsOneWidget, reason: 'her habit is back');
    });
  });
}
