// Run with: node --test supabase/functions/notify/   (Node 22.6+ strips the types; no install needed)
import assert from 'node:assert/strict';
import { generateKeyPairSync, verify } from 'node:crypto';
import { test } from 'node:test';
import { signJwt } from './fcm.ts';
import { decide, fcmBody, FORBIDDEN, message, type Event, type Webhook } from './logic.ts';

const w = (table: string, type: Webhook['type'], record: any, old_record: any = null): Webhook => ({ table, type, record, old_record });

test('an urge insert pings the partner, urgently, with only an id in the data', () => {
  const e = decide(w('urge_events', 'INSERT', { id: 'u1', pod_id: 'p', user_id: 'mika', retracted_at: null }));
  assert.deepEqual(e, { kind: 'urge', podId: 'p', actor: 'mika', urgeId: 'u1' });
  const m = message(e!, 'Mika');
  assert.equal(m.body, 'Mika is reaching out.');
  assert.equal(m.channel, 'urge');
  assert.equal(m.timeSensitive, true);
  assert.deepEqual(m.data, { route: 'urge', id: 'u1' });
});

test('an urge that arrives already retracted is silent; retracting later says all clear', () => {
  assert.equal(decide(w('urge_events', 'INSERT', { id: 'u1', pod_id: 'p', user_id: 'm', retracted_at: '2026-01-01' })), null);
  const e = decide(w('urge_events', 'UPDATE', { id: 'u1', pod_id: 'p', user_id: 'mika', retracted_at: 'now' }, { retracted_at: null }));
  assert.equal(e?.kind, 'urge_retracted');
  assert.equal(message(e!, 'Mika').body, 'Mika is okay.');
  assert.equal(message(e!, 'Mika').channel, 'pod', 'an all-clear is not an alarm');
});

test('resolving an urge (not retracting) sends nothing', () => {
  assert.equal(decide(w('urge_events', 'UPDATE', { pod_id: 'p', user_id: 'm', retracted_at: null, outcome: 'passed' }, { retracted_at: null })), null);
});

test('a slip pings once, at the moment it becomes a slip, not on every edit', () => {
  assert.equal(decide(w('check_ins', 'INSERT', { pod_id: 'p', user_id: 'm', status: 'slipped' }))?.kind, 'slip');
  assert.equal(decide(w('check_ins', 'UPDATE', { pod_id: 'p', user_id: 'm', status: 'slipped' }, { status: 'held' }))?.kind, 'slip');
  assert.equal(decide(w('check_ins', 'UPDATE', { pod_id: 'p', user_id: 'm', status: 'slipped', note: 'x' }, { status: 'slipped' })), null);
  assert.equal(decide(w('check_ins', 'INSERT', { pod_id: 'p', user_id: 'm', status: 'held' })), null, 'held is not worth a push');
  assert.equal(message(decide(w('check_ins', 'INSERT', { pod_id: 'p', user_id: 'm', status: 'slipped' }))!, 'Teo').body, 'Teo posted an update.');
});

test('replies go to the named recipient; a nudge says hello', () => {
  const reply = decide(w('encouragements', 'INSERT', { pod_id: 'p', from_user: 'teo', to_user: 'mika', kind: 'urge_reply' }));
  assert.deepEqual(reply, { kind: 'reply', podId: 'p', actor: 'teo', recipient: 'mika', nudge: false });
  assert.equal(message(reply!, 'Teo').body, 'Teo sent you a message.');
  const nudge = decide(w('encouragements', 'INSERT', { pod_id: 'p', from_user: 'teo', to_user: 'mika', kind: 'nudge' }));
  assert.equal(message(nudge!, 'Teo').body, 'Teo says hello.');
  assert.equal(decide(w('encouragements', 'UPDATE', { pod_id: 'p', from_user: 'teo', to_user: 'mika', seen_at: 'now' }, {})), null, 'marking seen is silent');
});

test('joining and a pod ending', () => {
  const j = decide(w('pod_members', 'INSERT', { pod_id: 'p', user_id: 'teo' }));
  assert.equal(message(j!, 'Teo').body, 'Teo joined your pod.');
  const ended = decide(w('pods', 'UPDATE', { id: 'p', status: 'archived' }, { status: 'active' }));
  assert.deepEqual(ended, { kind: 'pod_changed', podId: 'p' });
  assert.equal(message(ended!, 'x').body, 'Your pod has changed.');
  assert.equal(decide(w('pods', 'UPDATE', { id: 'p', status: 'archived' }, { status: 'archived' })), null);
  assert.equal(decide(w('pods', 'UPDATE', { id: 'p', status: 'active' }, { status: 'open' })), null);
});

test('unrelated tables and deletes are ignored', () => {
  assert.equal(decide(w('habits', 'INSERT', { pod_id: 'p' })), null);
  assert.equal(decide(w('check_ins', 'DELETE', null, { pod_id: 'p', status: 'slipped' })), null);
});

test('no lock-screen text ever names the behaviour or what the app is for', () => {
  const events: Event[] = [
    { kind: 'urge', podId: 'p', actor: 'a', urgeId: 'u' },
    { kind: 'urge_retracted', podId: 'p', actor: 'a' },
    { kind: 'slip', podId: 'p', actor: 'a' },
    { kind: 'reply', podId: 'p', actor: 'a', recipient: 'b', nudge: false },
    { kind: 'reply', podId: 'p', actor: 'a', recipient: 'b', nudge: true },
    { kind: 'joined', podId: 'p', actor: 'a' },
    { kind: 'pod_changed', podId: 'p' },
  ];
  for (const e of events) {
    const m = message(e, 'Teo');
    assert.equal(m.title, 'Anchor');
    for (const word of FORBIDDEN) {
      assert.ok(!`${m.title} ${m.body}`.toLowerCase().includes(word), `"${m.body}" must not contain "${word}"`);
    }
    for (const v of Object.values(m.data)) assert.ok(!v.includes('Teo'), 'data carries ids, never names');
  }
});

test('the FCM body asks for the right channel, priority and iOS interruption level', () => {
  const urgent = fcmBody('tok', message({ kind: 'urge', podId: 'p', actor: 'a', urgeId: 'u' }, 'Teo')).message;
  assert.equal(urgent.token, 'tok');
  assert.equal(urgent.android.priority, 'HIGH');
  assert.equal(urgent.android.notification.channel_id, 'urge');
  assert.equal(urgent.apns.payload.aps['interruption-level'], 'time-sensitive');
  const calm = fcmBody('tok', message({ kind: 'slip', podId: 'p', actor: 'a' }, 'Teo')).message;
  assert.equal(calm.android.notification.channel_id, 'pod');
  assert.equal(calm.apns.payload.aps['interruption-level'], 'active');
});

test('the service-account JWT is well formed and its signature verifies', async () => {
  const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const pem = privateKey.export({ type: 'pkcs8', format: 'pem' }) as string;
  const jwt = await signJwt({ client_email: 'sa@proj.iam.gserviceaccount.com', private_key: pem, project_id: 'proj' }, 1_700_000_000);

  const [h, c, s] = jwt.split('.');
  const dec = (x: string) => JSON.parse(Buffer.from(x, 'base64url').toString());
  assert.deepEqual(dec(h), { alg: 'RS256', typ: 'JWT' });
  assert.deepEqual(dec(c), {
    iss: 'sa@proj.iam.gserviceaccount.com',
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: 1_700_000_000,
    exp: 1_700_003_600,
  });
  const ok = verify('sha256', Buffer.from(`${h}.${c}`), publicKey, Buffer.from(s, 'base64url'));
  assert.ok(ok, 'Google would accept this signature');
});
