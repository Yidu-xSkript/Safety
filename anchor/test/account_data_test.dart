// Your data is yours: exporting it, and deleting it for good.
import 'dart:convert';

import 'package:anchor/core/backend/pod_backend.dart';
import 'package:anchor/features/pod/account_controller.dart';
import 'package:anchor/core/kv.dart';
import 'package:anchor/features/pod/pod_controller.dart';
import 'package:anchor/features/today/solo_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/memory_kv.dart';
import 'fakes/scenario.dart';
import 'harness.dart' show testNow;

const bothPlatforms = TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS});

Future<void> podTab(WidgetTester t) async {
  await t.tap(find.text('Pod').last);
  await t.pumpAndSettle();
}

Future<void> tapText(WidgetTester t, String text) async {
  await t.tap(find.text(text).last);
  await t.pumpAndSettle();
}

void main() {
  group('export', () {
    testWidgets('hands a JSON file of your data to the share sheet', variant: bothPlatforms, (t) async {
      final s = await Scenario.create();
      final shared = <(String, String)>[];
      await s.launch(t, share: (n, c) async => shared.add((n, c)));
      await podTab(t);
      expect(find.text('Export my data'), findsOneWidget);
      await tapText(t, 'Export my data');

      expect(shared.single.$1, 'anchor-export.json');
      final json = jsonDecode(shared.single.$2) as Map<String, dynamic>;
      expect((json['profile'] as Map)['display_name'], 'Mika');
    });

    testWidgets('with no connection it exports what is on this phone, and says where it came from', (t) async {
      final s = await Scenario.create();
      final shared = <String>[];
      await s.launch(t, share: (n, c) async => shared.add(c));
      s.mika.online = false;
      await podTab(t);
      await tapText(t, 'Export my data');
      final json = jsonDecode(shared.single) as Map<String, dynamic>;
      expect(json['source'], 'this phone');
      expect((json['data'] as Map)['name'], 'Mika');
    });

    testWidgets('if sharing itself fails, a plain message, not a crash', (t) async {
      final s = await Scenario.create();
      await s.launch(t, share: (n, c) async => throw StateError('no share sheet'));
      await podTab(t);
      await tapText(t, 'Export my data');
      expect(find.text("Couldn't prepare your data. Check your connection and try again."), findsOneWidget);
    });
  });

  group('delete account', () {
    testWidgets('a clear question first; cancel deletes nothing', variant: bothPlatforms, (t) async {
      final s = await Scenario.create();
      await s.launch(t);
      await podTab(t);
      await tapText(t, 'Delete account');
      expect(find.text('Delete your account?'), findsOneWidget);
      expect(find.textContaining("Teo will be told your pod has changed. This can't be undone."), findsOneWidget);
      await tapText(t, 'Cancel');
      expect(s.mika.deleteCalls, 0);
      expect(find.text('Delete your account?'), findsNothing);
    });

    testWidgets('confirming erases it on the server and on the phone, and returns to Welcome', variant: bothPlatforms, (t) async {
      final s = await Scenario.create();
      await s.launch(t);
      await t.tap(find.text('Held the line'));
      await t.pumpAndSettle();
      await podTab(t);
      await tapText(t, 'Delete account');
      await tapText(t, 'Delete everything');
      await t.pumpAndSettle();

      expect(s.mika.deleteCalls, 1);
      expect(s.server.checkIns['mika'], isNull, reason: 'her pledges are gone from the server');
      expect(s.server.names.containsKey('mika'), isFalse);
      expect(s.server.podOf('teo')!.status, PodStatus.archived, reason: 'Teo keeps an ended pod');
      expect(s.server.names['teo'], 'Teo', reason: "and nothing of Teo's was touched");

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty, reason: 'the phone holds nothing of hers any more');
      expect(find.text('Two people. One honest line a day.'), findsOneWidget);
    });

    testWidgets('with no connection nothing is wiped, and it says so', (t) async {
      final s = await Scenario.create();
      await s.launch(t);
      await podTab(t);
      s.mika.online = false;
      await tapText(t, 'Delete account');
      await tapText(t, 'Delete everything');
      expect(find.text('No connection. Check your internet and try again.'), findsOneWidget);
      await tapText(t, 'OK');

      expect(s.mika.deleteCalls, 0);
      expect((await SharedPreferences.getInstance()).getString('anchor.solo.v1'), contains('Mika'), reason: 'her data is still hers');
      expect(find.text('Delete account'), findsOneWidget, reason: 'still on the Pod tab, free to try again');
    });

    test('a phone with no server wipes only itself, and does not complain', () async {
      final kv = MemoryKV();
      final c = ProviderContainer(overrides: [
        kvProvider.overrideWith((_) async => kv),
        backendProvider.overrideWithValue(UnconfiguredBackend()),
        clockProvider.overrideWithValue(() => testNow),
      ]);
      addTearDown(c.dispose);
      await c.read(soloProvider.future);
      await c.read(soloProvider.notifier).completeOnboarding('Mika', ['Reading']);
      expect(kv.values, isNotEmpty);

      await c.read(accountProvider.notifier).deleteAccount();
      expect(kv.values, isEmpty);
    });
  });
}
