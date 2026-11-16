// Automated accessibility checks on every main screen: tap targets (48dp Android / 44pt iOS), every tappable thing
// labelled, text contrast, and no layout overflow at 200% text or on a 320dp-wide phone. This is the part of an
// accessibility audit a machine can do; TalkBack and VoiceOver on real devices still need a person.
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_lock.dart';
import 'fakes/scenario.dart';

const bothPlatforms = TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS});

Future<void> audit(WidgetTester t, {String? what}) async {
  final handle = t.ensureSemantics(); // disposed before the test ends, as the framework requires
  try {
    await t.pump();
    final platform = defaultTargetPlatform == TargetPlatform.iOS ? iOSTapTargetGuideline : androidTapTargetGuideline;
    await expectLater(t, meetsGuideline(platform), reason: '$what: tap targets');
    await expectLater(t, meetsGuideline(labeledTapTargetGuideline), reason: '$what: every control has a label');
    // Text contrast is NOT checked here: flutter_test's contrast guideline samples pixels, and the test font (Ahem) draws
    // every glyph as a solid block, which reads as ~1.2:1 on every screen. Contrast is proven from the colour tokens
    // instead (contrast_test.dart: every text/background pair >= 4.5:1, every meaningful graphic >= 3:1, both themes + night).
  } finally {
    handle.dispose();
  }
}

Future<void> tapText(WidgetTester t, String text) async {
  await t.tap(find.text(text).last);
  await t.pumpAndSettle();
}

void main() {
  group('onboarding and pairing', () {
    testWidgets('welcome, name, habits', variant: bothPlatforms, (t) async {
      final s = await Scenario.create(onboarded: false, paired: false);
      await s.launch(t);
      await audit(t, what: 'welcome');
      await tapText(t, 'Get started');
      await audit(t, what: 'name');
      await t.enterText(find.byWidgetPredicate((w) => w is TextField || w is EditableText).first, 'Mika');
      await t.pump();
      await tapText(t, 'Continue');
      await audit(t, what: 'habits');
    });

    testWidgets('pairing choice, join, waiting', variant: bothPlatforms, (t) async {
      final s = await Scenario.create(paired: false);
      await s.launch(t);
      await audit(t, what: 'pairing choice');
      await tapText(t, 'I have a code');
      await audit(t, what: 'join');
      await t.pageBack();
      await t.pumpAndSettle();
      await tapText(t, 'Create a pod');
      await audit(t, what: 'waiting');
    });
  });

  group('the app', () {
    testWidgets('Today with a reaching-out card and the notification prompt', variant: bothPlatforms, (t) async {
      final s = await Scenario.create();
      await s.launch(t, push: FakePush());
      await s.teoReachesOut();
      await settleRealtime(t);
      await audit(t, what: 'today');
    });

    testWidgets('History, Pod, and the day sheet', variant: bothPlatforms, (t) async {
      final s = await Scenario.create(started: DateTime.utc(2026, 11, 8));
      await s.launch(t, lock: FakeAppLock(supported: true));
      await tapText(t, 'History');
      await audit(t, what: 'history');
      await t.tap(find.byType(InkWell).at(10));
      await t.pumpAndSettle();
      await audit(t, what: 'day sheet');
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      await tapText(t, 'Pod');
      await audit(t, what: 'pod');
    });

    testWidgets('the reply sheet and the slip sheet', variant: bothPlatforms, (t) async {
      final s = await Scenario.create();
      await s.launch(t);
      await s.teoReachesOut();
      await settleRealtime(t);
      await tapText(t, 'Reply');
      await audit(t, what: 'reply sheet');
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      await tapText(t, 'I slipped');
      await audit(t, what: 'slip sheet');
    });

    testWidgets('the grounding screen and its end screen', variant: bothPlatforms, (t) async {
      final s = await Scenario.create();
      await s.launch(t);
      await t.tap(find.text('Urge').last);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await audit(t, what: 'grounding');
      for (var i = 0; i < 181; i++) {
        await t.pump(const Duration(seconds: 1));
      }
      await t.pumpAndSettle();
      await audit(t, what: 'end of grounding');
    });

    testWidgets('the lock screen', variant: bothPlatforms, (t) async {
      final s = await Scenario.create();
      await s.launch(t, lock: FakeAppLock(supported: true, result: false));
      await t.pumpAndSettle();
      await audit(t, what: 'lock');
    });
  });

  group('large text and small screens: nothing overflows, nothing is cut off', () {
    Future<void> sized(WidgetTester t, double w, double scale, Future<void> Function() body) async {
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await body();
      expect(t.takeException(), isNull, reason: 'at ${w.toInt()}dp wide and ${(scale * 100).toInt()}% text');
    }

    for (final (w, scale) in [(320.0, 1.0), (320.0, 2.0), (390.0, 2.0)]) {
      testWidgets('Today, History, Pod at ${w.toInt()}dp and ${(scale * 100).toInt()}%', (t) async {
        final s = await Scenario.create(started: DateTime.utc(2026, 11, 8));
        await sized(t, w, scale, () async {
          await s.launch(t, push: FakePush());
          t.view.physicalSize = Size(w, 1400);
          t.view.devicePixelRatio = 1;
          await s.teoReachesOut();
          await settleRealtime(t);
          await t.pumpAndSettle();
          for (final tab in ['History', 'Pod', 'Today']) {
            await tapText(t, tab);
          }
        });
      });

      testWidgets('Urge and the sheets at ${w.toInt()}dp and ${(scale * 100).toInt()}%', (t) async {
        final s = await Scenario.create();
        await sized(t, w, scale, () async {
          await s.launch(t);
          t.view.physicalSize = Size(w, 1400);
          t.view.devicePixelRatio = 1;
          await t.pumpAndSettle();
          await t.tap(find.text('Urge').last);
          await t.pump();
          await t.pump(const Duration(milliseconds: 400));
          for (var i = 0; i < 181; i++) {
            await t.pump(const Duration(seconds: 1));
          }
          await t.pumpAndSettle();
        });
      });

      testWidgets('onboarding and pairing at ${w.toInt()}dp and ${(scale * 100).toInt()}%', (t) async {
        final s = await Scenario.create(onboarded: false, paired: false);
        await sized(t, w, scale, () async {
          await s.launch(t);
          t.view.physicalSize = Size(w, 1400);
          t.view.devicePixelRatio = 1;
          await t.pumpAndSettle();
          await tapText(t, 'Get started');
          await t.enterText(find.byWidgetPredicate((w) => w is TextField || w is EditableText).first, 'Mika');
          await t.pump();
          await tapText(t, 'Continue');
          await tapText(t, 'Just the pledge for now');
          await tapText(t, 'I have a code');
        });
      });
    }
  });
}
