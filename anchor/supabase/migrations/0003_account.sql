-- Anchor 0003: deleting an account, and exporting your data.

-- Someone who started a pod must be deletable. The pod belongs to both people, so when its creator's account goes
-- the pod stays (archived, for the partner who remains) and just forgets who created it.
alter table pods alter column created_by drop not null;
alter table pods drop constraint pods_created_by_fkey;
alter table pods add constraint pods_created_by_fkey foreign key (created_by) references profiles(id) on delete set null;

-- Everything the server holds that is *yours*, as JSON, for the "Export my data" row. Runs as the caller, so RLS
-- applies; every query is also explicitly filtered to the caller, because the policies deliberately let you read
-- your partner's rows too. Never includes: push tokens, your partner's data, anyone's ids.
create function export_my_data() returns jsonb
language sql stable as $$
  select jsonb_build_object(
    'exported_at', now(),
    'profile', (select to_jsonb(p) - 'id' from profiles p where p.id = auth.uid()),
    'habits', coalesce((select jsonb_agg(to_jsonb(h) - 'user_id' - 'pod_id' order by h.created_day) from habits h where h.user_id = auth.uid()), '[]'),
    'habit_logs', coalesce((select jsonb_agg(to_jsonb(l) - 'user_id' - 'pod_id' order by l.local_date) from habit_logs l where l.user_id = auth.uid()), '[]'),
    'check_ins', coalesce((select jsonb_agg(to_jsonb(c) - 'user_id' - 'pod_id' - 'id' order by c.local_date) from check_ins c where c.user_id = auth.uid()), '[]'),
    'urge_events', coalesce((select jsonb_agg(to_jsonb(u) - 'user_id' - 'pod_id' - 'id' order by u.created_at) from urge_events u where u.user_id = auth.uid()), '[]'),
    'replies_sent', coalesce((select jsonb_agg(jsonb_build_object('kind', e.kind, 'template', e.template_key, 'at', e.created_at) order by e.created_at) from encouragements e where e.from_user = auth.uid()), '[]'),
    'replies_received', coalesce((select jsonb_agg(jsonb_build_object('kind', e.kind, 'template', e.template_key, 'at', e.created_at) order by e.created_at) from encouragements e where e.to_user = auth.uid()), '[]')
  );
$$;

revoke execute on function export_my_data() from public, anon;
grant execute on function export_my_data() to authenticated;
