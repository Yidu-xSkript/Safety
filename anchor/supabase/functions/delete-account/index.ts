// Edge Function `delete-account`: the signed-in caller deletes their own account. Verify JWT stays ON (the default):
// the platform rejects calls without a valid session, and we then read *who* from that session, never from the body.
// NOT yet run against a live project.
import { createClient } from 'npm:@supabase/supabase-js@2';
import { bearer, deleteAccount, type AccountDb } from './logic.ts';

const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
  auth: { persistSession: false },
});

const accountDb: AccountDb = {
  async leaveAllPods(userId) {
    const { data, error } = await db
      .from('pod_members')
      .update({ left_at: new Date().toISOString() })
      .eq('user_id', userId)
      .is('left_at', null)
      .select('pod_id');
    if (error) throw error;
    const podIds = (data ?? []).map((r) => r.pod_id as string);
    if (podIds.length > 0) {
      const { error: e2 } = await db
        .from('pods')
        .update({ status: 'archived', archived_at: new Date().toISOString(), invite_code: null })
        .in('id', podIds)
        .neq('status', 'archived');
      if (e2) throw e2;
    }
  },
  async deleteUser(userId) {
    const { error } = await db.auth.admin.deleteUser(userId);
    if (error) throw error;
  },
};

Deno.serve(async (req) => {
  const jwt = bearer(req.headers.get('Authorization'));
  if (!jwt) return new Response('unauthorized', { status: 401 });
  const { data, error } = await db.auth.getUser(jwt);
  if (error || !data.user) return new Response('unauthorized', { status: 401 });
  try {
    await deleteAccount(accountDb, data.user.id);
    return Response.json({ deleted: true });
  } catch (_) {
    return new Response('could not delete', { status: 500 }); // nothing is logged: it could name a person
  }
});
