// Edge Function `notify`: a Database Webhook fires it on certain row changes; it works out who should hear
// about it, and sends a short, generic push. Rules and wording live in logic.ts (tested); this file only does I/O.
// NOT yet run against a live project. Setup: docs/PUSH.md.
//
// Secrets: WEBHOOK_SECRET, FCM_SERVICE_ACCOUNT (the service-account JSON), plus the SUPABASE_URL and
// SUPABASE_SERVICE_ROLE_KEY that Supabase injects. The service role never leaves this function.
import { createClient } from 'npm:@supabase/supabase-js@2';
import { sendFcm, type ServiceAccount } from './fcm.ts';
import { decide, fcmBody, message, type Webhook } from './logic.ts';

const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
  auth: { persistSession: false },
});

Deno.serve(async (req) => {
  if (req.headers.get('x-webhook-secret') !== Deno.env.get('WEBHOOK_SECRET')) return new Response('forbidden', { status: 403 });

  const event = decide((await req.json()) as Webhook);
  if (!event) return Response.json({ sent: 0, reason: 'ignored' });

  // Who hears about it.
  const { data: members } = await db.from('pod_members').select('user_id').eq('pod_id', event.podId).is('left_at', null);
  const all = (members ?? []).map((m) => m.user_id as string);
  let recipients: string[];
  switch (event.kind) {
    case 'reply':
      recipients = [event.recipient];
      break;
    case 'pod_changed':
      recipients = all; // whoever is still in it (the leaver has left_at set)
      break;
    case 'joined':
      if (all.length < 2) return Response.json({ sent: 0, reason: 'first member' }); // the creator joining their own pod
      recipients = all.filter((u) => u !== event.actor);
      break;
    default:
      recipients = all.filter((u) => u !== event.actor);
  }
  if (recipients.length === 0) return Response.json({ sent: 0, reason: 'no recipient' });

  const actor = 'actor' in event ? event.actor : null;
  const { data: profile } = actor ? await db.from('profiles').select('display_name').eq('id', actor).single() : { data: null };
  const msg = message(event, profile?.display_name ?? 'Your partner');

  const { data: devices } = await db.from('devices').select('id,push_token').in('user_id', recipients);
  const sa = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT')!) as ServiceAccount;
  let sent = 0;
  for (const d of devices ?? []) {
    const r = await sendFcm(sa, fcmBody(d.push_token as string, msg));
    if (r.ok) sent++;
    else if (r.gone) await db.from('devices').delete().eq('id', d.id); // uninstalled or rotated: stop sending to it
  }
  return Response.json({ sent });
});
