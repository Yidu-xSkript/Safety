// Today screen goldens (text renders in the Ahem test font, so these check layout, rings and states),
// plus the Remove-animations contract for the ring sweep.
import 'package:anchor/app/shell.dart';
import 'package:anchor/core/local_day.dart';
import 'package:anchor/features/rings/ring_model.dart';
import 'package:anchor/features/rings/slab.dart';
import 'package:anchor/features/rings/slab_painter.dart';
import 'package:anchor/features/today/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

CheckIn at(PledgeState s, int day, {String? note}) => CheckIn(state: s, at: DateTime(2026, 11, day, 21), note: note);

/// Six days of history with every state: held, slipped (with a note), silent, and today still pending.
SoloData week() => onboardedMika(
      started: dayOf(2026, 11, 8),
      checkIns: {
        '2026-11-08': at(PledgeState.held, 8),
        '2026-11-09': at(PledgeState.held, 9),
        '2026-11-10': at(PledgeState.slipped, 10, note: 'Hard night'),
        '2026-11-11': at(PledgeState.held, 11),
        // 11-12: silent (hollow, not a slip)
        '2026-11-13': at(PledgeState.held, 13),
      },
      logs: {
        '2026-11-08': {'read', 'gym'},
        '2026-11-09': {'read'},
        '2026-11-10': {'gym'},
        '2026-11-11': {'read', 'gym'},
        '2026-11-13': {'read'},
        '2026-11-14': {'read'},
      },
    );

Future<void> shot(WidgetTester t, String file,
    {Brightness brightness = Brightness.light, TargetPlatform platform = TargetPlatform.android, double textScale = 1, SoloData? data}) async {
  seedSolo(data ?? week());
  // Desktop hosts default to keyboard-focus highlighting, which draws a focus ring on the FAB. Phones don't.
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
  addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
  t.view.devicePixelRatio = 2;
  t.view.physicalSize = const Size(390, 1100) * 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(harness(const AnchorShell(), brightness: brightness, platform: platform, textScale: textScale));
  await t.pumpAndSettle();
  await expectLater(find.byType(AnchorShell), matchesGoldenFile('goldens/$file.png'));
}

void main() {
  testWidgets('today, Android, light', (t) => shot(t, 'today_android_light'));
  testWidgets('today, Android, dark', (t) => shot(t, 'today_android_dark', brightness: Brightness.dark));
  testWidgets('today, iOS, light', (t) => shot(t, 'today_ios_light', platform: TargetPlatform.iOS));
  testWidgets('today, Android, 200% text', (t) => shot(t, 'today_android_2x', textScale: 2));
  testWidgets('today, Android, slipped with a note', (t) {
    final d = week();
    return shot(t, 'today_android_slipped',
        data: d.copyWith(checkIns: {...d.checkIns, '2026-11-14': at(PledgeState.slipped, 14, note: 'Hard night')}));
  });

  group('ring sweep and Remove animations', () {
    SlabData slab(int done) => SlabData(
          initial: 'M',
          daysHeld: 0,
          lastDays: const [],
          today: DayRing(pledge: PledgeState.unchecked, done: done, total: 4),
        );
    Widget show(SlabData d, {required bool reduce}) =>
        harness(Scaffold(body: Slab(name: 'M', data: d, person: Person.you)), disableAnimations: reduce);

    testWidgets('instant when the system asks for no animation', (t) async {
      await t.pumpWidget(show(slab(1), reduce: true));
      await t.pumpWidget(show(slab(3), reduce: true));
      await t.pump();
      expect(t.hasRunningAnimations, isFalse);
    });

    testWidgets('animates for 400ms otherwise', (t) async {
      await t.pumpWidget(show(slab(1), reduce: false));
      await t.pumpWidget(show(slab(3), reduce: false));
      await t.pump(const Duration(milliseconds: 100));
      expect(t.hasRunningAnimations, isTrue);
      await t.pump(const Duration(milliseconds: 400));
      expect(t.hasRunningAnimations, isFalse);
    });
  });
}
