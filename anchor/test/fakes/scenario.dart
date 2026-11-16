// Mika's phone as a real app on screen, paired with a (scripted) Teo over the shared in-memory server.
import 'dart:async';
import 'dart:convert';

import 'package:anchor/core/backend/pod_backend.dart';
import 'package:anchor/core/app_lock.dart';
import 'package:anchor/core/push/push_service.dart';
import 'package:anchor/core/reminders.dart';
import 'package:anchor/core/share.dart';
import 'package:anchor/core/shortcuts.dart';
import 'package:anchor/features/pod/pod_controller.dart';
import 'package:anchor/features/today/solo_controller.dart';
import 'package:anchor/features/urge/contact.dart';
import 'package:anchor/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness.dart';
import 'fake_backend.dart';
import 'fake_lock.dart';

class FakePush implements PushService {
  FakePush({this.supported = true, this.grant = true, this.tok = 'tok-1', this.initial});

  @override
  final bool supported;
  bool grant;
  String? tok;
  PushRoute? initial;
  int permissionRequests = 0;
  final _refresh = StreamController<String>.broadcast();
  final _opened = StreamController<PushRoute>.broadcast();

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grant;
  }

  @override
  Future<String?> token() async => tok;
  @override
  Stream<String> get onTokenRefresh => _refresh.stream;
  @override
  Stream<PushRoute> get onOpened => _opened.stream;
  @override
  Future<PushRoute?> initialRoute() async => initial;

  void refreshToken(String t) => _refresh.add(t);
  void tap(PushRoute r) => _opened.add(r);
}

class FakeReminders implements ReminderService {
  FakeReminders({this.grant = true});

  bool grant;
  int permissionRequests = 0;
  final calls = <({TimeOfDay? at, bool skipToday})>[];

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grant;
  }

  @override
  Future<void> sync(TimeOfDay? at, {required bool skipToday, required String title, required String body}) async =>
      calls.add((at: at, skipToday: skipToday));
}

class FakeShortcuts implements AppShortcuts {
  void Function()? onUrge;

  @override
  Future<void> init(void Function() cb) async => onUrge = cb;

  void press() => onUrge!();
}

class Scenario {
  Scenario._(this.server, this.mika, this.teo, this.podId);

  final FakeServer server;
  final FakeBackend mika;
  final FakeBackend teo;
  final String podId;

  /// Teo has started a pod and Mika has joined it, on the server. Mika's app (this phone) starts onboarded,
  /// with the pod cached as if it had been open before. [paired] false leaves Mika with no pod at all.
  static Future<Scenario> create({bool paired = true, DateTime? started, bool onboarded = true, Map<String, Object> extraPrefs = const {}}) async {
    final server = FakeServer(start: testNow);
    final teo = FakeBackend(server, 'teo');
    final mika = FakeBackend(server, 'mika');
    await teo.setProfile('Teo', 0);
    await mika.setProfile('Mika', 0);
    String podId = '';
    if (paired) {
      final pod = await teo.createPod();
      await mika.joinPod(pod.inviteCode!);
      podId = pod.podId;
    }
    SharedPreferences.setMockInitialValues({
      if (onboarded) 'anchor.solo.v1': jsonEncode(onboardedMika(started: started ?? DateTime.utc(2026, 11, 14)).toJson()),
      if (paired)
        'anchor.pod.v1': jsonEncode({
          'pod': PodInfo(podId: podId, status: PodStatus.active, partnerId: 'teo', partnerName: 'Teo').toJson(),
          'partner': null,
          'backfilled': podId,
        }),
      ...extraPrefs,
    });
    return Scenario._(server, mika, teo, podId);
  }

  /// Teo, on his phone, reaches out. Returns the urge id.
  Future<String> teoReachesOut() async {
    const id = '00000000-0000-4000-8000-0000000000aa';
    await teo.send(UrgeOp(podId: podId, id: id, at: server.now()));
    return id;
  }

  Future<void> launch(
    WidgetTester t, {
    PushService? push,
    AppShortcuts? shortcuts,
    Future<bool> Function(Uri)? opener,
    ReminderService? reminders,
    AppLockService? lock,
    PrivacyService? privacy,
    Future<void> Function(String, String)? share,
    bool online = true,
  }) async {
    mika.online = online;
    t.view.physicalSize = const Size(400, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(server.now),
        backendProvider.overrideWithValue(mika),
        pushServiceProvider.overrideWithValue(push ?? NoPush()),
        shortcutsProvider.overrideWithValue(shortcuts ?? NoShortcuts()),
        reminderServiceProvider.overrideWithValue(reminders ?? FakeReminders()),
        appLockServiceProvider.overrideWithValue(lock ?? FakeAppLock()),
        privacyServiceProvider.overrideWithValue(privacy ?? FakePrivacy()),
        if (share != null) shareFileProvider.overrideWithValue(share),
        if (opener != null) urlOpenerProvider.overrideWithValue(opener),
      ],
      child: const AnchorApp(),
    ));
    await t.pump(); // load storage
    await t.pump(const Duration(milliseconds: 50)); // first refresh from the server
    await t.pump();
  }
}

/// Lets the 300 ms realtime debounce fire and the refetch finish.
Future<void> settleRealtime(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 50));
  await t.pump();
}
