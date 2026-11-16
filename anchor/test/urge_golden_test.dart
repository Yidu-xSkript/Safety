// Goldens for the hard moment (test font = Ahem: layout, ring and colour, not typography).
@Tags(['golden'])
library;

import 'package:anchor/core/backend/pod_backend.dart';
import 'package:anchor/features/urge/contact.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/scenario.dart';

Future<void> shot(WidgetTester t, String file, Future<void> Function(Scenario s) act,
    {TargetPlatform platform = TargetPlatform.android, Map<String, Object> prefs = const {}, FakePush? push}) async {
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
  addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
  debugDefaultTargetPlatformOverride = platform;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  final s = await Scenario.create(extraPrefs: prefs);
  await s.launch(t, push: push);
  t.view.devicePixelRatio = 2;
  t.view.physicalSize = const Size(390, 800) * 2;
  await t.pump();
  await act(s);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$file.png'));
  debugDefaultTargetPlatformOverride = null;
}

Future<void> openUrge(WidgetTester t) async {
  await t.tap(find.text('Urge').last);
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('grounding, Android', (t) => shot(t, 'urge_android', (s) async {
        await openUrge(t);
        await t.pump(const Duration(seconds: 2)); // two seconds into the in-breath
      }));
  testWidgets('grounding, iOS', (t) => shot(t, 'urge_ios', (s) async {
        await openUrge(t);
        await t.pump(const Duration(seconds: 6)); // mid out-breath
      }, platform: TargetPlatform.iOS));
  testWidgets('grounding with a reply and a saved number', (t) => shot(t, 'urge_reply', (s) async {
        await openUrge(t);
        await t.pump(const Duration(seconds: 1));
        final id = s.server.urges.keys.single;
        await s.teo.send(ReplyOp(podId: s.podId, id: 'r-1', toUser: 'mika', kind: 'urge_reply', template: 'call_me', urgeId: id));
        await settleRealtime(t);
      }, prefs: {kPartnerPhoneKey: '+251911000000'}));
  testWidgets('after three minutes', (t) => shot(t, 'urge_end', (s) async {
        await openUrge(t);
        for (var i = 0; i < 181; i++) {
          await t.pump(const Duration(seconds: 1));
        }
        await t.pumpAndSettle();
      }));
  testWidgets('Today: Teo is reaching out, and the notification prompt', (t) => shot(t, 'today_reaching_out', (s) async {
        await s.teoReachesOut();
        await settleRealtime(t);
      }, push: FakePush()));
  testWidgets('the reply sheet', (t) => shot(t, 'reply_sheet', (s) async {
        await s.teoReachesOut();
        await settleRealtime(t);
        await t.tap(find.text('Reply'));
        await t.pumpAndSettle();
      }));
}
