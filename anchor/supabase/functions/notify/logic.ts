// Pure rules for push notifications: which database change deserves one, and the exact words it may use.
// No I/O here, so it is unit-tested (logic.test.ts) and shared by index.ts. Wording is fixed by docs/SECURITY.md.

export type Webhook = {
  type: 'INSERT' | 'UPDATE' | 'DELETE';
  table: string;
  schema?: string;
  record: Record<string, any> | null;
  old_record: Record<string, any> | null;
};

export type Event =
  | { kind: 'urge'; podId: string; actor: string; urgeId: string }
  | { kind: 'urge_retracted'; podId: string; actor: string }
  | { kind: 'slip'; podId: string; actor: string }
  | { kind: 'reply'; podId: string; actor: string; recipient: string; nudge: boolean }
  | { kind: 'joined'; podId: string; actor: string }
  | { kind: 'pod_changed'; podId: string };

/** Which events an INSERT/UPDATE webhook turns into. Anything else is ignored. */
export function decide(w: Webhook): Event | null {
  const r = w.record ?? {};
  const o = w.old_record ?? {};
  switch (w.table) {
    case 'urge_events':
      if (w.type === 'INSERT' && !r.retracted_at) return { kind: 'urge', podId: r.pod_id, actor: r.user_id, urgeId: r.id };
      if (w.type === 'UPDATE' && r.retracted_at && !o.retracted_at) return { kind: 'urge_retracted', podId: r.pod_id, actor: r.user_id };
      return null;
    case 'check_ins':
      // Only the moment it becomes a slip: editing the note afterwards must not ping again.
      if (r.status === 'slipped' && (w.type === 'INSERT' || (w.type === 'UPDATE' && o.status !== 'slipped'))) {
        return { kind: 'slip', podId: r.pod_id, actor: r.user_id };
      }
      return null;
    case 'encouragements':
      return w.type === 'INSERT'
        ? { kind: 'reply', podId: r.pod_id, actor: r.from_user, recipient: r.to_user, nudge: r.kind === 'nudge' }
        : null;
    case 'pod_members':
      return w.type === 'INSERT' ? { kind: 'joined', podId: r.pod_id, actor: r.user_id } : null;
    case 'pods':
      return w.type === 'UPDATE' && r.status === 'archived' && o.status !== 'archived' ? { kind: 'pod_changed', podId: r.id } : null;
    default:
      return null;
  }
}

export type Channel = 'urge' | 'pod';

export type Message = {
  title: string;
  body: string;
  channel: Channel; // Android notification channel; "urge" is the high-importance one
  timeSensitive: boolean; // iOS interruption level
  data: Record<string, string>; // ids only, never content
};

/** Words visible on a lock screen. Never mention what the app is for. */
export function message(e: Event, actorName: string): Message {
  const base = { title: 'Anchor', channel: 'pod' as Channel, timeSensitive: false };
  switch (e.kind) {
    case 'urge':
      return { ...base, body: `${actorName} is reaching out.`, channel: 'urge', timeSensitive: true, data: { route: 'urge', id: e.urgeId } };
    case 'urge_retracted':
      return { ...base, body: `${actorName} is okay.`, data: { route: 'today' } };
    case 'slip':
      return { ...base, body: `${actorName} posted an update.`, data: { route: 'today' } };
    case 'reply':
      return { ...base, body: e.nudge ? `${actorName} says hello.` : `${actorName} sent you a message.`, data: { route: 'today' } };
    case 'joined':
      return { ...base, body: `${actorName} joined your pod.`, data: { route: 'today' } };
    case 'pod_changed':
      return { ...base, body: 'Your pod has changed.', data: { route: 'pod' } };
  }
}

/** The FCM HTTP v1 request body for one device token. */
export function fcmBody(token: string, m: Message) {
  return {
    message: {
      token,
      notification: { title: m.title, body: m.body },
      data: m.data,
      android: { priority: 'HIGH', notification: { channel_id: m.channel } },
      apns: {
        headers: { 'apns-priority': '10' },
        payload: { aps: { sound: 'default', 'interruption-level': m.timeSensitive ? 'time-sensitive' : 'active' } },
      },
    },
  };
}

/** Words that must never appear in anything shown on a lock screen. */
export const FORBIDDEN = ['porn', 'relapse', 'slip', 'urge', 'struggl', 'clean', 'addict'];
