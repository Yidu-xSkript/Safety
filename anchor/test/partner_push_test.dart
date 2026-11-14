// The partner's side of the hard moment (cards, reply sheet), notification consent, notification taps,
// and the icon shortcut. Mika's phone is the app on screen; Teo is scripted over the shared server.
import 'package:anchor/core/backend/pod_backend.dart';
import 'package:anchor/core/push/push_service.dart';
import 'package:anchor/features/pod/push_controller.dart';
import 'package:anchor/features/rings/ring_model.dart';
import 'package:anchor/features/urge/contact.dart';
import 'package:anchor/features/urge/urge_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/scenario.dart';

const bothPlatforms = TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS});

void main() {
  group('when Teo reaches out', () {
    testWidgets('a card appears on its own, and one tap answers in prepared words', variant: bothPlatforms, (t) async {
      final s = await Scenario.create();
      await s.launch(t);
      expect(find.text('Teo is reaching out.'), findsNothing);

      final id = await s.teoReachesOut();
      await settleRealtime(t);
      expect(find.text('Teo is reaching out.'), findsOneWidget);

      await t.tap(find.text('Reply'));
      await t.pumpAndSettle();
      // the sheet repeats who, then offers four prepared replies and nothing else
      expect(find.text('Teo is reaching out.'), findsNWidgets(2));
      for (final reply in ["I'm here.", "I'm here. Call me?", 'Walk with me?', 'Proud of you.']) {
        expect(find.text(reply), findsOneWidget);
      }
      expect(textField(), findsNothing, reason: 'no free text, ever');

      await t.tap(find.text("I'm here."));
      await t.pump();
      expect(find.text('Sent.'), findsOneWidget);
      await t.pump(const Duration(seconds: 1));
      await t.pumpAndSettle();
      expect(find.text('Sent.'), findsNothing);

      expect(s.server.replies.single.template, 'here');
      expect(s.server.replies.single.urgeId, id, reason: 'tied to his urge, so it shows on his grounding screen');
      expect(s.server.replies.single.from, 'mika');
      await settleRealtime(t);
      expect(find.text('Reply'), findsNothing, reason: 'already answered');
    });

    testWidgets('it disappears when he says it was a mistake', (t) async {
      final s = await Scenario.create();
      await s.launch(t);
      final id = await s.teoReachesOut();
      await settleRealtime(t);
      expect(find.text('Teo is reaching out.'), findsOneWidget);

      await s.teo.send(UrgeUpdateOp(id: id, retract: true));
      await settleRealtime(t);
      expect(find.text('Teo is reaching out.'), findsNothing);
    });

    testWidgets('Call and Text appear only when a number is saved, and open the phone\'s own apps', (t) async {
      final s = await Scenario.create(extraPrefs: {kPartnerPhoneKey: '+251911000000'});
      final opened = <Uri>[];
      await s.launch(t, opener: (u) async {
        opened.add(u);
        return true;
      });
      await s.teoReachesOut();
      await settleRealtime(t);
      await t.tap(find.text('Reply'));
      await t.pumpAndSettle();

      await t.tap(find.text('Call'));
      await t.tap(find.text('Text'));
      expect(opened.map((u) => u.toString()), ['tel:+251911000000', 'sms:+251911000000']);
    });

    testWidgets('without a saved number there is no Call or Text', (t) async {
      final s = await Scenario.create();
      await s.launch(t);
      await s.teoReachesOut();
      await settleRealtime(t);
      await t.tap(find.text('Reply'));
      await t.pumpAndSettle();
      expect(find.text('Call'), findsNothing);
      expect(find.text('Text'), findsNothing);
    });
  });

  group('when Teo posts an update (a slip)', () {
    Future<void> teoSlips(Scenario s, {String? note}) => s.teo.send(
          CheckInOp(podId: s.podId, day: DateTime.utc(2026, 11, 14), state: PledgeState.slipped, note: note),
        );

    testWidgets('his note is shown and answering is one tap', (t) async {
      final s = await Scenario.create();
      await s.launch(t);
      await teoSlips(s, note: 'Hard night');
      await settleRealtime(t);

      expect(find.text('Teo posted an update.'), findsOneWidget);
      expect(find.text('Hard night'), findsOneWidget);
      await t.tap(find.text('Reply'));
      await t.pumpAndSettle();
      for (final reply in ['Thank you for telling me.', 'Tomorrow is a new ring.', "I'm here. Call me?", 'Proud of you.']) {
        expect(find.text(reply), findsOneWidget);
      }
      await t.tap(find.text('Thank you for telling me.'));
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();

      expect(s.server.replies.single.template, 'thank_you');
      expect(s.server.replies.single.urgeId, isNull, reason: 'a slip reply has no urge');
      await settleRealtime(t);
      expect(find.text('Reply'), findsNothing);
    });

    testWidgets('and a kind word from him shows up for you', (t) async {
      final s = await Scenario.create();
      await s.launch(t);
      await s.teo.send(ReplyOp(podId: s.podId, id: 'r-9', toUser: 'mika', kind: 'slip_reply', template: 'new_ring'));
      await settleRealtime(t);
      expect(find.text('Teo: Tomorrow is a new ring.'), findsOneWidget);
    });
  });

  group('notifications', () {
    testWidgets('we ask why before we ask the system, once, and remember "Not now"', variant: bothPlatforms, (t) async {
      final s = await Scenario.create();
      final push = FakePush();
      await s.launch(t, push: push);

      expect(find.text('Know when Teo reaches out'), findsOneWidget);
      expect(find.text('Anchor can notify you quietly. Notifications never say what this app is for.'), findsOneWidget);
      expect(push.permissionRequests, 0, reason: 'never asked cold');

      await t.tap(find.text('Not now'));
      await t.pumpAndSettle();
      expect(find.text('Know when Teo reaches out'), findsNothing);
      expect(push.permissionRequests, 0);
      expect(s.server.devices, isEmpty);

      // a restart does not ask again
      await t.pumpWidget(const SizedBox());
      await s.launch(t, push: push);
      expect(find.text('Know when Teo reaches out'), findsNothing);
      expect((await SharedPreferences.getInstance()).getString(kPushAskedKey), 'no');
    });

    testWidgets('turning them on registers this phone, and a refreshed token is registered too', variant: bothPlatforms, (t) async {
      final s = await Scenario.create();
      final push = FakePush(tok: 'tok-1');
      await s.launch(t, push: push);
      await t.tap(find.text('Turn on notifications'));
      await t.pumpAndSettle();

      expect(push.permissionRequests, 1);
      expect(find.text('Know when Teo reaches out'), findsNothing);
      final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
      expect(s.server.devices['tok-1'], (user: 'mika', platform: platform));

      push.refreshToken('tok-2');
      await t.pump();
      await t.pump();
      expect(s.server.devices['tok-2']?.user, 'mika', reason: 'the system rotated the token; the server follows');
    });

    testWidgets('if the system says no, we do not pretend and do not ask again', (t) async {
      final s = await Scenario.create();
      final push = FakePush(grant: false);
      await s.launch(t, push: push);
      await t.tap(find.text('Turn on notifications'));
      await t.pumpAndSettle();
      expect(push.permissionRequests, 1);
      expect(s.server.devices, isEmpty);
      expect(find.text('Know when Teo reaches out'), findsNothing);
    });

    testWidgets('a build without Firebase never shows the prompt', (t) async {
      final s = await Scenario.create();
      await s.launch(t, push: FakePush(supported: false));
      expect(find.text('Know when Teo reaches out'), findsNothing);
    });

    testWidgets('tapping a notification while the app runs opens the reply sheet', (t) async {
      final s = await Scenario.create();
      final push = FakePush(supported: false);
      await s.launch(t, push: push);
      final id = await s.teoReachesOut();

      push.tap(PushRoute(PushRouteKind.urge, id));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      await t.pumpAndSettle();
      expect(find.text("I'm here."), findsOneWidget, reason: 'the reply sheet is up');
    });

    testWidgets('launching from a notification does the same, after refreshing', (t) async {
      final s = await Scenario.create();
      final id = await s.teoReachesOut();
      await s.launch(t, push: FakePush(supported: false, initial: PushRoute(PushRouteKind.urge, id)));
      await t.pump(const Duration(milliseconds: 100));
      await t.pumpAndSettle();
      expect(find.text("I'm here."), findsOneWidget);
    });

    testWidgets('a tap on an old notification (he has since retracted) opens nothing', (t) async {
      final s = await Scenario.create();
      final push = FakePush(supported: false);
      final id = await s.teoReachesOut();
      await s.teo.send(UrgeUpdateOp(id: id, retract: true));
      await s.launch(t, push: push);
      push.tap(PushRoute(PushRouteKind.urge, id));
      await t.pump(const Duration(milliseconds: 100));
      await t.pumpAndSettle();
      expect(find.text("I'm here."), findsNothing);
    });
  });

  group('the icon shortcut', () {
    testWidgets('opens the grounding screen, once however many times it is pressed', (t) async {
      final s = await Scenario.create();
      final shortcuts = FakeShortcuts();
      await s.launch(t, shortcuts: shortcuts);
      shortcuts.press();
      shortcuts.press();
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(UrgeScreen), findsOneWidget);
      expect(s.server.urges.length, 1, reason: 'two presses must not send two pings');
    });
  });
}

Finder textField() => find.byWidgetPredicate((w) => w is TextField);
