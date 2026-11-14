// The hard moment between two phones: the ping, the reply, the retraction, the offline queue.
import 'package:anchor/core/backend/pod_backend.dart';
import 'package:anchor/features/rings/ring_model.dart';
import 'package:anchor/features/urge/replies.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/phone.dart';

void main() {
  test('pressing Urge tells the partner, who sees it and can answer', () async {
    final (mika, teo, server) = await pair();
    final id = mika.pod.beginUrge();
    await settle();

    expect(server.urges[id]!.user, 'mika', reason: 'the ping reached the server');
    expect(mika.p.pending, 0);

    await teo.pod.refresh();
    expect(teo.p.partnerUrge?.id, id, reason: 'Teo sees Mika is reaching out');

    teo.pod.reply(ReplyTemplate.here, urgeId: id);
    await settle();
    expect(server.replies.single.template, 'here');
    expect(server.replies.single.urgeId, id);

    await mika.pod.refresh();
    final got = mika.p.replies.single;
    expect(got.fromMe, isFalse);
    expect(got.template, 'here');
    expect(got.urgeId, id, reason: 'it is tied to the urge, so it shows on that grounding screen');
  });

  test('"That was a mistake" retracts it, so the partner sees an all-clear', () async {
    final (mika, teo, _) = await pair();
    final id = mika.pod.beginUrge();
    await settle();
    await teo.pod.refresh();
    expect(teo.p.partnerUrge, isNotNull);

    mika.pod.retractUrge(id);
    await settle();
    await teo.pod.refresh();
    expect(teo.p.partnerUrge, isNull);
  });

  test('how it ended resolves it; the card goes away', () async {
    final (mika, teo, server) = await pair();
    final id = mika.pod.beginUrge();
    mika.pod.finishUrge(id, 'passed');
    await settle();
    expect(server.urges[id]!.outcome, 'passed');
    await teo.pod.refresh();
    expect(teo.p.partnerUrge, isNull);
  });

  test('offline: the ping waits in the queue and goes out the moment the phone is back', () async {
    final (mika, teo, server) = await pair();
    mika.backend.online = false;
    final id = mika.pod.beginUrge();
    await settle();
    expect(mika.p.pendingKeys, contains('u:$id'), reason: 'the screen can tell the ping is still queued');
    expect(server.urges, isEmpty);

    mika.backend.online = true;
    await mika.pod.flush();
    expect(mika.p.pending, 0);
    expect(server.urges[id], isNotNull);
    await teo.pod.refresh();
    expect(teo.p.partnerUrge?.id, id);
  });

  test('a ping stuck offline for hours is dropped, never delivered as a fresh alarm', () async {
    final (mika, teo, server) = await pair();
    mika.backend.online = false;
    final id = mika.pod.beginUrge();
    await settle();

    server.advance(const Duration(hours: 1)); // the phone comes back an hour later (all clocks move together)
    mika.stop();
    mika.boot();
    await mika.ready();
    expect(mika.p.pendingKeys, contains('u:$id'));
    mika.backend.online = true;
    await mika.pod.flush();
    expect(server.urges, isEmpty, reason: 'a stale ping must not reach Teo');
    expect(mika.p.pending, 0, reason: 'and it does not block the queue');
    await teo.pod.refresh();
    expect(teo.p.partnerUrge, isNull);
  });

  test('urgent things jump ahead of ordinary ones but keep their own order', () async {
    final (mika, _, _) = await pair();
    mika.backend.online = false;
    await mika.solo.toggleHabit(mika.s.data.habits.first); // ordinary
    await mika.solo.setPledge(PledgeState.held); // ordinary
    final id = mika.pod.beginUrge(); // urgent
    mika.pod.retractUrge(id); // urgent, must stay after its own creation
    await settle();
    final keys = mika.p.pendingKeys.toList();
    expect(keys.indexOf('u:$id'), lessThan(keys.indexOf('uu:$id')), reason: 'created before retracted');
    expect(keys.indexOf('uu:$id'), lessThan(keys.indexWhere((k) => k.startsWith('t:'))), reason: 'ahead of the habit tick');
    expect(keys.indexOf('uu:$id'), lessThan(keys.indexWhere((k) => k.startsWith('ci:'))), reason: 'and the pledge');
  });

  test('replies are prepared words only, and the kind follows the context', () async {
    final (mika, teo, server) = await pair();
    final id = mika.pod.beginUrge();
    await settle();
    await teo.pod.refresh();

    teo.pod.reply(ReplyTemplate.walk, urgeId: id);
    teo.pod.reply(ReplyTemplate.thankYou); // a slip reply has no urge
    await settle();
    expect(server.replies.map((r) => r.template), ['walk', 'thank_you']);
    expect(server.replies.map((r) => r.urgeId), [id, null]);
    expect({for (final t in ReplyTemplate.values) t.key}, {'here', 'call_me', 'walk', 'proud', 'thank_you', 'new_ring'});
    await mika.pod.refresh();
    expect(mika.p.replies.length, 2);
  });

  test('with no pod, Urge still works: nothing is queued', () async {
    final server = (await pair()).$3;
    final solo = Phone(server, 'solo');
    await solo.onboard('Sam', []);
    final id = solo.pod.beginUrge();
    await settle();
    expect(id, isNotEmpty);
    expect(solo.p.pending, 0);
  });

  test('ops survive being saved and loaded', () {
    final ops = <SyncOp>[
      UrgeOp(podId: 'p', id: 'u1', at: DateTime.utc(2026, 11, 14, 12)),
      const UrgeUpdateOp(id: 'u1', retract: true),
      const UrgeUpdateOp(id: 'u2', outcome: 'passed'),
      const ReplyOp(podId: 'p', id: 'r1', toUser: 'x', kind: 'urge_reply', template: 'here', urgeId: 'u1'),
    ];
    for (final o in ops) {
      expect(SyncOp.fromJson(o.toJson()).toJson(), o.toJson());
    }
  });
}
