// The pairing screens, driven like a person would, against the in-memory server.
import 'package:anchor/core/backend/pod_backend.dart';
import 'package:anchor/core/app_lock.dart';
import 'package:anchor/features/pod/pairing_screens.dart';
import 'package:anchor/features/pod/pod_controller.dart';
import 'package:anchor/features/today/solo_controller.dart';
import 'package:anchor/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_backend.dart';
import 'fakes/fake_lock.dart';
import 'harness.dart';

final textField = find.byWidgetPredicate((w) => w is TextField || w is CupertinoTextField);
const bothPlatforms = TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS});

Future<void> launch(WidgetTester t, PodBackend backend) async {
  t.view.physicalSize = const Size(400, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [
      clockProvider.overrideWithValue(() => testNow),
      backendProvider.overrideWithValue(backend),
      appLockServiceProvider.overrideWithValue(FakeAppLock()),
    ],
    child: const AnchorApp(),
  ));
  await t.pumpAndSettle();
}

Future<void> tapText(WidgetTester t, String text) async {
  await t.tap(find.text(text).last);
  await t.pumpAndSettle();
}

/// Teo, on his own phone, creates a pod and returns its code.
Future<String> teoCreatesPod(FakeServer server) async {
  final teo = FakeBackend(server, 'teo');
  await teo.setProfile('Teo', 0);
  return (await teo.createPod()).inviteCode!;
}

void main() {
  setUp(() => seedSolo(onboardedMika(started: DateTime.utc(2026, 11, 14))));

  testWidgets('create a pod, share the code, and the partner arrives', variant: bothPlatforms, (t) async {
    final server = FakeServer();
    await launch(t, FakeBackend(server, 'mika'));

    expect(find.text('Pair with one person you trust'), findsOneWidget);
    expect(find.text('A pod is exactly two people. Nobody else can ever see it.'), findsOneWidget);
    await tapText(t, 'Create a pod');

    // --- waiting: the code, grouped, with its rules, and a way to send it
    final code = server.podOf('mika')!.code!;
    expect(find.text('Share this code with the one person you trust.'), findsOneWidget);
    expect(find.text(groupCode(code)), findsOneWidget);
    expect(find.text('Single use. Expires in 24 hours.'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    String? clipboard; // widget tests have no system clipboard unless we stand one in
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tapText(t, 'Copy');
    expect(find.text('Copied'), findsOneWidget);
    expect(clipboard, code, reason: 'the bare code is copied, not the spaced display form');

    // --- Teo joins from his phone; Mika's phone notices on its own
    final teo = FakeBackend(server, 'teo');
    await teo.setProfile('Teo', 0);
    await teo.joinPod(code);
    await t.pump(const Duration(milliseconds: 400)); // realtime debounce
    await t.pumpAndSettle();
    expect(find.text('Teo is here.'), findsOneWidget);

    await t.pump(const Duration(seconds: 2)); // the moment ends by itself
    await t.pumpAndSettle();
    expect(find.text('Mika & Teo'), findsWidgets);
    expect(find.text('How was today?'), findsOneWidget);
  });

  testWidgets('join with a code: input is cleaned, a wrong code is explained, the right one pairs', variant: bothPlatforms, (t) async {
    final server = FakeServer();
    final code = await teoCreatesPod(server);
    await launch(t, FakeBackend(server, 'mika'));

    await tapText(t, 'I have a code');
    expect(find.text('Enter your partner\'s code'), findsOneWidget);

    // ambiguous characters (0 O 1 I) and punctuation never get in; lowercase is shown uppercase
    await t.enterText(textField, 'a0b1o-i2');
    await t.pump();
    expect(find.text('AB2'), findsOneWidget);

    await t.enterText(textField, 'ABCDEF');
    await t.pump();
    await tapText(t, 'Join');
    expect(find.text("That code doesn't match a pod. Check it with your partner and try again."), findsOneWidget);

    await t.enterText(textField, code);
    await t.pump();
    expect(find.textContaining("doesn't match"), findsNothing, reason: 'the message clears when you type');
    await tapText(t, 'Join');
    expect(find.text('Teo is here.'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();
    expect(find.text('Mika & Teo'), findsWidgets);
  });

  testWidgets('the Join button waits for six characters', (t) async {
    await launch(t, FakeBackend(FakeServer(), 'mika'));
    await tapText(t, 'I have a code');
    await t.enterText(textField, 'ABCDE');
    await t.pump();
    await t.tap(find.text('Join'));
    await t.pumpAndSettle();
    expect(find.textContaining("doesn't match"), findsNothing, reason: 'nothing was sent for 5 characters');
  });

  testWidgets('too many wrong codes: asked to pause', (t) async {
    await launch(t, FakeBackend(FakeServer(), 'mika'));
    await tapText(t, 'I have a code');
    for (var i = 0; i < 6; i++) {
      await t.enterText(textField, 'ABCDE${i + 2}');
      await t.pump();
      await tapText(t, 'Join');
    }
    expect(find.text("Let's pause a bit. Try again in an hour."), findsOneWidget);
  });

  testWidgets('no connection and no server are said plainly, never as a crash', (t) async {
    final server = FakeServer();
    final offline = FakeBackend(server, 'mika')..online = false;
    await launch(t, offline);
    await tapText(t, 'Create a pod');
    expect(find.text('No connection. Check your internet and try again.'), findsOneWidget);
    expect(find.text('Pair with one person you trust'), findsOneWidget, reason: 'still on the choice screen');

    await t.pumpWidget(const SizedBox());
    seedSolo(onboardedMika(started: DateTime.utc(2026, 11, 14)));
    await launch(t, UnconfiguredBackend());
    await tapText(t, 'Create a pod');
    expect(find.text("Anchor isn't connected to a server yet."), findsOneWidget);
  });

  testWidgets('an expired code offers a fresh one', (t) async {
    var clock = testNow; // the app and the server share one controllable clock
    final server = FakeServer(now: () => clock);
    Widget app() => ProviderScope(
          overrides: [
            clockProvider.overrideWithValue(() => clock),
            backendProvider.overrideWithValue(FakeBackend(server, 'mika')),
            appLockServiceProvider.overrideWithValue(FakeAppLock()),
          ],
          child: const AnchorApp(),
        );
    t.view.physicalSize = const Size(400, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(app());
    await t.pumpAndSettle();
    await tapText(t, 'Create a pod');
    final first = server.podOf('mika')!.code!;
    expect(find.text('Single use. Expires in 24 hours.'), findsOneWidget);

    clock = testNow.add(const Duration(hours: 25)); // a day later: reopen the app
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(app()); // storage (with the cached pod) survives
    await t.pumpAndSettle();
    expect(find.text('This code has expired.'), findsOneWidget);
    await tapText(t, 'Get a new code');
    expect(server.podOf('mika')!.code, isNot(first));
    expect(find.text('Single use. Expires in 24 hours.'), findsOneWidget);
  });
}
