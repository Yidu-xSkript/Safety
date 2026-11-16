// Goldens for History, the Pod tab and the ended pod (test font = Ahem: layout, glyphs and colour).
@Tags(['golden'])
library;

import 'package:anchor/app/shell.dart';
import 'package:anchor/core/local_day.dart';
import 'package:anchor/features/rings/ring_model.dart';
import 'package:anchor/features/today/domain/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/scenario.dart';
import 'harness.dart';

CheckIn at(PledgeState s, int day, {String? note}) => CheckIn(state: s, at: DateTime(2026, 11, day, 21), note: note);

SoloData mika() => onboardedMika(
      started: dayOf(2026, 11, 3),
      checkIns: {
        '2026-11-03': at(PledgeState.held, 3),
        '2026-11-04': at(PledgeState.held, 4),
        '2026-11-05': at(PledgeState.held, 5),
        '2026-11-06': at(PledgeState.slipped, 6, note: 'Hard night'),
        '2026-11-07': at(PledgeState.held, 7),
        '2026-11-08': at(PledgeState.held, 8),
        // 9: silent
        '2026-11-10': at(PledgeState.held, 10),
        '2026-11-11': at(PledgeState.held, 11),
        '2026-11-12': at(PledgeState.held, 12),
        '2026-11-13': at(PledgeState.held, 13),
      },
    );

Future<void> shot(WidgetTester t, String file, Future<void> Function() act,
    {TargetPlatform platform = TargetPlatform.android, Brightness brightness = Brightness.light, double textScale = 1}) async {
  seedSolo(mika(), true);
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
  addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
  debugDefaultTargetPlatformOverride = platform;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  t.view.devicePixelRatio = 2;
  t.view.physicalSize = const Size(390, 900) * 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(harness(const AnchorShell(), platform: platform, brightness: brightness, textScale: textScale));
  await t.pumpAndSettle();
  await act();
  await expectLater(find.byType(AnchorShell), matchesGoldenFile('goldens/$file.png'));
  debugDefaultTargetPlatformOverride = null;
}

Future<void> tab(WidgetTester t, String name) async {
  await t.tap(find.text(name).last);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('history, Android light', (t) => shot(t, 'history_android_light', () => tab(t, 'History')));
  testWidgets('history, Android dark', (t) => shot(t, 'history_android_dark', () => tab(t, 'History'), brightness: Brightness.dark));
  testWidgets('history, iOS', (t) => shot(t, 'history_ios', () => tab(t, 'History'), platform: TargetPlatform.iOS));
  testWidgets('history day sheet', (t) => shot(t, 'history_day', () async {
        await tab(t, 'History');
        await t.tap(find.bySemanticsLabel(RegExp(r'Nov 6')));
        await t.pumpAndSettle();
      }));
  testWidgets('pod tab, Android', (t) => shot(t, 'pod_android', () => tab(t, 'Pod')));
  testWidgets('pod tab, iOS', (t) => shot(t, 'pod_ios', () => tab(t, 'Pod'), platform: TargetPlatform.iOS));
  testWidgets('pod tab, dark', (t) => shot(t, 'pod_dark', () => tab(t, 'Pod'), brightness: Brightness.dark));

  testWidgets('today after the partner left', (t) async {
    final s = await Scenario.create();
    await s.launch(t);
    t.view.devicePixelRatio = 2;
    t.view.physicalSize = const Size(390, 900) * 2;
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
    await s.teo.leavePod();
    await settleRealtime(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/today_ended.png'));
  });
}
