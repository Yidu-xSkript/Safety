// Two phones, one in-memory server. Each phone has its own storage and its own provider container, so this
// exercises the real controllers end to end: pair, sync both ways, work offline, restart, replay.
import 'package:anchor/core/backend/pod_backend.dart';
import 'package:anchor/core/kv.dart';
import 'package:anchor/core/local_day.dart';
import 'package:anchor/core/uuid.dart';
import 'package:anchor/features/pod/pod_controller.dart';
import 'package:anchor/features/rings/ring_model.dart';
import 'package:anchor/features/today/solo_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_backend.dart';
import 'fakes/memory_kv.dart';
import 'harness.dart' show testNow;

final today = localDate(testNow);

/// One phone: its own storage, its own app state, talking to the shared [server].
class Phone {
  Phone(this.server, this.id) : kv = MemoryKV() {
    backend = FakeBackend(server, id);
    boot();
  }

  final FakeServer server;
  final String id;
  final MemoryKV kv;
  late final FakeBackend backend;
  late ProviderContainer c;

  /// (Re)starts the app over the same storage, like closing and reopening it.
  void boot() {
    c = ProviderContainer(overrides: [
      kvProvider.overrideWith((_) async => kv),
      backendProvider.overrideWithValue(backend),
      clockProvider.overrideWithValue(() => testNow),
    ]);
  }

  Future<void> ready() async {
    await c.read(soloProvider.future);
    await c.read(podProvider.future);
  }

  SoloController get solo => c.read(soloProvider.notifier);
  PodController get pod => c.read(podProvider.notifier);
  SoloState get s => c.read(soloProvider).requireValue;
  PodState get p => c.read(podProvider).requireValue;

  Future<void> onboard(String name, List<String> habits) async {
    await ready();
    await solo.completeOnboarding(name, habits);
  }

  void stop() => c.dispose();
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));
Future<void> realtime() => Future<void>.delayed(const Duration(milliseconds: 450)); // 300ms debounce + slack

Matcher podError(PodErrorKind k) => throwsA(isA<PodError>().having((e) => e.kind, 'kind', k));

/// Mika creates a pod, Teo joins with its code.
Future<(Phone, Phone, FakeServer)> pair() async {
  final server = FakeServer();
  final mika = Phone(server, 'mika'), teo = Phone(server, 'teo');
  await mika.onboard('Mika', ['Reading', 'Workout']);
  await teo.onboard('Teo', ['Prayer']);
  await mika.pod.createPod();
  await teo.pod.joinPod(mika.p.pod!.inviteCode!);
  await mika.pod.refresh();
  await settle();
  return (mika, teo, server);
}

void main() {
  test('creating a pod gives a code; joining it pairs both phones', () async {
    final server = FakeServer();
    final mika = Phone(server, 'mika'), teo = Phone(server, 'teo');
    await mika.onboard('Mika', []);
    await teo.onboard('Teo', []);

    await mika.pod.createPod();
    expect(mika.p.pod!.status, PodStatus.open);
    final code = mika.p.pod!.inviteCode!;
    expect(code, matches(RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$')));

    await teo.pod.joinPod(' ${code.toLowerCase()} '); // tolerant of case and spaces
    expect(teo.p.pod!.status, PodStatus.active);
    expect(teo.p.pod!.partnerName, 'Mika');
    expect(teo.p.justPaired, isTrue, reason: 'the joiner gets the "is here" moment');

    await mika.pod.refresh(); // what the realtime event or app resume does
    expect(mika.p.pod!.status, PodStatus.active);
    expect(mika.p.pod!.partnerName, 'Teo');
    expect(mika.p.justPaired, isTrue, reason: 'so does the creator, when the partner arrives');

    await teo.pod.acknowledgePaired();
    expect(teo.p.justPaired, isFalse);
  });

  test('errors are sorted into calm kinds, and wrong codes are rate limited', () async {
    final server = FakeServer();
    final bo = Phone(server, 'bo');
    await bo.onboard('Bo', []);
    for (var i = 0; i < 5; i++) {
      await expectLater(bo.pod.joinPod('AAAAAA'), podError(PodErrorKind.invalidCode));
    }
    await expectLater(bo.pod.joinPod('AAAAAA'), podError(PodErrorKind.tooManyAttempts));
    expect(bo.p.pod, isNull, reason: 'a failed join leaves no pod behind');

    final mika = Phone(server, 'mika');
    await mika.onboard('Mika', []);
    await mika.pod.createPod();
    await expectLater(mika.pod.createPod(), podError(PodErrorKind.alreadyInPod));
  });

  test('with no connection, pairing says so instead of crashing', () async {
    final server = FakeServer();
    final p = Phone(server, 'x');
    await p.onboard('X', []);
    p.backend.online = false;
    await expectLater(p.pod.createPod(), podError(PodErrorKind.offline));
  });

  test('on activation, habits get real UUIDs and today is uploaded exactly once', () async {
    final server = FakeServer();
    final mika = Phone(server, 'mika'), teo = Phone(server, 'teo');
    await mika.onboard('Mika', ['Reading', 'Workout']);
    await teo.onboard('Teo', []);
    // a pledge and a tick made before pairing:
    await mika.solo.setPledge(PledgeState.held);
    await mika.solo.toggleHabit(mika.s.data.habits.first);
    expect(mika.s.data.habits.every((h) => isUuid(h.id)), isTrue, reason: 'new habits are UUIDs from the start');

    await mika.pod.createPod();
    await teo.pod.joinPod(mika.p.pod!.inviteCode!);
    await mika.pod.refresh();
    await settle();

    expect(server.habits['mika']!.length, 2);
    expect(server.checkIns['mika']![dayKey(today)]!.state, PledgeState.held);
    expect(server.ticks['mika']![dayKey(today)]!.length, 1);
    expect(mika.p.pending, 0, reason: 'everything was acknowledged');

    final before = server.accepted.length; // a second refresh must not upload it all again
    await mika.pod.refresh();
    await settle();
    expect(server.accepted.length, before);
  });

  test('old non-UUID habit ids from Phase 1 are migrated, ticks included', () async {
    final server = FakeServer();
    final mika = Phone(server, 'mika'), teo = Phone(server, 'teo');
    await mika.onboard('Mika', []);
    await teo.onboard('Teo', []);
    // simulate a Phase 1 install: ids like "h123-0"
    mika.kv.values['anchor.solo.v1'] =
        '{"name":"Mika","onboarded":true,"start":"2026-11-14","habits":[{"id":"h123-0","title":"Reading","created":"2026-11-14"}],'
        '"checkIns":{},"logs":{"2026-11-14":["h123-0"]}}';
    mika.stop();
    mika.boot();
    await mika.ready();
    await mika.pod.createPod();
    await teo.pod.joinPod(mika.p.pod!.inviteCode!);
    await mika.pod.refresh();
    await settle();

    final id = mika.s.data.habits.single.id;
    expect(isUuid(id), isTrue);
    expect(mika.s.data.logs[dayKey(today)], {id}, reason: 'the tick follows the habit to its new id');
    expect(server.ticks['mika']![dayKey(today)], {id});
  });

  test('a pledge, a note and a tick on one phone appear on the other', () async {
    final (mika, teo, _) = await pair();
    await mika.solo.setPledge(PledgeState.slipped, note: 'Hard night');
    await mika.solo.toggleHabit(mika.s.data.habits.first);
    await settle();

    await teo.pod.refresh();
    final seen = teo.p.partner!;
    expect(seen.pledgeOn(today), PledgeState.slipped);
    expect(seen.checkIns[dayKey(today)]!.note, 'Hard night');
    expect(seen.countsOn(today), (done: 1, total: 2));

    final view = TodayView(teo.s, teo.p); // Teo's Today derives a slab and pod streak from it
    expect(view.partnerName, 'Mika');
    expect(view.partner.today.pledge, PledgeState.slipped);
    expect(view.podStreak, 0, reason: 'a slip by either person ends the pod streak');
  });

  test('realtime: the other phone updates itself without being asked', () async {
    final (mika, teo, _) = await pair();
    await teo.pod.refresh(); // starts Teo's subscription
    expect(teo.p.partner!.pledgeOn(today), isNull);

    await mika.solo.setPledge(PledgeState.held);
    await realtime();
    expect(teo.p.partner!.pledgeOn(today), PledgeState.held, reason: 'pushed by the change event, no manual refresh');
  });

  test('offline: changes queue, show as pending, and replay exactly once when back online', () async {
    final (mika, teo, server) = await pair();
    await mika.pod.refresh();
    await settle();
    final sentBefore = server.accepted.length;

    mika.backend.online = false;
    await mika.solo.setPledge(PledgeState.held);
    await mika.solo.setPledge(PledgeState.slipped, note: 'Changed my answer'); // replaces the held one in the queue
    await mika.solo.toggleHabit(mika.s.data.habits.first);
    await settle();
    expect(mika.p.pending, 2, reason: 'one pledge (the newest) + one tick');
    expect(server.accepted.length, sentBefore, reason: 'nothing reached the server');
    expect(mika.s.pledge!.state, PledgeState.slipped, reason: 'the phone itself already shows the answer');

    mika.backend.online = true;
    await mika.pod.flush();
    expect(mika.p.pending, 0);
    expect(server.accepted.skip(sentBefore).where((k) => k.startsWith('ci:')).length, 1, reason: 'the replaced answer was never sent');
    expect(server.checkIns['mika']![dayKey(today)]!.state, PledgeState.slipped);
    expect(server.checkIns['mika']![dayKey(today)]!.note, 'Changed my answer');

    await teo.pod.refresh();
    expect(teo.p.partner!.pledgeOn(today), PledgeState.slipped);
  });

  test('ticking then unticking offline sends only the final state', () async {
    final (mika, _, server) = await pair();
    final habit = mika.s.data.habits.first;
    final before = server.accepted.length;
    mika.backend.online = false;
    await mika.solo.toggleHabit(habit);
    await mika.solo.toggleHabit(habit);
    await settle();
    expect(mika.p.pending, 1, reason: 'the newer "off" replaces the pending "on"');
    mika.backend.online = true;
    await mika.pod.flush();
    expect(server.ticks['mika']?[dayKey(today)] ?? <String>{}, isEmpty);
    expect(server.accepted.length - before, 1);
  });

  test('the queue survives closing the app: pending changes are replayed after a restart', () async {
    final (mika, _, server) = await pair();
    mika.backend.online = false;
    await mika.solo.setPledge(PledgeState.held);
    await settle();
    expect(mika.p.pending, 1);

    mika.stop();
    mika.boot(); // same storage, fresh process
    await mika.ready();
    expect(mika.p.pending, 1, reason: 'the outbox was on disk');
    expect(mika.p.pod!.active, isTrue, reason: 'and so was the pod, so Today opens offline');
    expect(mika.p.partner!.name, 'Teo', reason: "with the partner's last known data");

    mika.backend.online = true;
    await mika.pod.flush();
    expect(mika.p.pending, 0);
    expect(server.checkIns['mika']![dayKey(today)]!.state, PledgeState.held);
  });

  test('an op the server refuses for good is dropped, not retried forever', () async {
    final (mika, _, server) = await pair();
    server.podOf('mika')!.status = PodStatus.archived; // the pod ended: every write is now refused
    await mika.solo.setPledge(PledgeState.held);
    await settle();
    expect(mika.p.pending, 0, reason: 'refused ops must not block the queue');
  });

  test('solo data written before a pod exists is not queued', () async {
    final server = FakeServer();
    final mika = Phone(server, 'mika');
    await mika.onboard('Mika', ['Reading']);
    await mika.solo.setPledge(PledgeState.held);
    await settle();
    expect(mika.p.pending, 0);
    expect(mika.s.pledge!.state, PledgeState.held);
  });
}
