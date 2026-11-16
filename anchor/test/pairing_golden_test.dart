// Goldens for the pairing screens (test font = Ahem: layout and shapes, not typography).
@Tags(['golden'])
library;

import 'package:anchor/features/pod/pod_controller.dart';
import 'package:anchor/features/today/solo_controller.dart';
import 'package:anchor/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_backend.dart';
import 'harness.dart';

Future<void> shot(WidgetTester t, String file, Future<void> Function() act,
    {TargetPlatform platform = TargetPlatform.android, Brightness brightness = Brightness.light}) async {
  seedSolo(onboardedMika(started: DateTime.utc(2026, 11, 14)));
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
  addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
  debugDefaultTargetPlatformOverride = platform;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  t.view.devicePixelRatio = 2;
  t.view.physicalSize = const Size(390, 760) * 2;
  addTearDown(t.view.reset);
  final server = FakeServer(now: () => testNow);
  await t.pumpWidget(ProviderScope(
    overrides: [clockProvider.overrideWithValue(() => testNow), backendProvider.overrideWithValue(FakeBackend(server, 'mika'))],
    child: _Themed(brightness: brightness, child: const AnchorApp()),
  ));
  await t.pumpAndSettle();
  await act();
  await t.pumpAndSettle();
  await expectLater(find.byType(AnchorApp), matchesGoldenFile('goldens/$file.png'));
  debugDefaultTargetPlatformOverride = null;
}

/// AnchorApp owns its MaterialApp, so dark mode is requested through the platform brightness.
class _Themed extends StatelessWidget {
  const _Themed({required this.brightness, required this.child});

  final Brightness brightness;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      MediaQuery(data: MediaQuery.of(context).copyWith(platformBrightness: brightness), child: child);
}

void main() {
  testWidgets('pod choice, Android', (t) => shot(t, 'pair_choice_android', () async {}));
  testWidgets('pod choice, iOS', (t) => shot(t, 'pair_choice_ios', () async {}, platform: TargetPlatform.iOS));
  testWidgets('waiting with a code, Android light', (t) => shot(t, 'pair_waiting_light', () async {
        await t.tap(find.text('Create a pod'));
      }));
  testWidgets('waiting with a code, Android dark', (t) => shot(t, 'pair_waiting_dark', () async {
        await t.tap(find.text('Create a pod'));
      }, brightness: Brightness.dark));
  testWidgets('waiting with a code, iOS', (t) => shot(t, 'pair_waiting_ios', () async {
        await t.tap(find.text('Create a pod'));
      }, platform: TargetPlatform.iOS));
  testWidgets('join with a wrong code', (t) => shot(t, 'pair_join_error', () async {
        await t.tap(find.text('I have a code'));
        await t.pumpAndSettle();
        await t.enterText(find.byType(TextField), 'ABCDEF');
        await t.pump();
        await t.tap(find.text('Join'));
      }));
}
