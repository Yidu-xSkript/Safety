-- RLS, RPC and trigger tests. Plain SQL: each "-- @test" section is run in order by run.mjs.
-- A failed ASSERT or an unexpected error fails the section. Users: 1 Mika, 2 Teo (the pod), 3 outsider,
-- 4 brute-forcer, 5 and 6 (expiry).

-- @test setup helpers and users
create schema t;
grant usage on schema t to public;
create function t.u(i int) returns uuid language sql immutable as $$ select ('00000000-0000-0000-0000-' || lpad(i::text, 12, '0'))::uuid $$;
create function t.as_user(i int) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', t.u(i))::text, false);
  execute 'set role authenticated';
end $$;
-- Succeeds only if [q] fails with a message containing [expected].
create function t.throws(q text, expected text) returns void language plpgsql as $$
begin
  begin
    execute q;
  exception when others then
    if sqlerrm like '%' || expected || '%' then return; end if;
    raise exception 'expected error "%" but got "%" for: %', expected, sqlerrm, q;
  end;
  raise exception 'expected error "%" but the statement succeeded: %', expected, q;
end $$;
grant execute on all functions in schema t to public;
create table t.ctx (k text primary key, v text);
grant all on t.ctx to public;
insert into auth.users (id) select t.u(i) from generate_series(1, 6) i;
select t.as_user(1); select set_profile('Mika', 180);
select t.as_user(2); select set_profile('Teo', 180);
select t.as_user(3); select set_profile('Sam', 0);
select t.as_user(4); select set_profile('Bo', 0);
select t.as_user(5); select set_profile('Eli', 0);
select t.as_user(6); select set_profile('Kai', 0);
reset role;

-- @test create_pod returns a well-formed single-use code
select t.as_user(1);
insert into t.ctx select 'code', out_code from create_pod();
insert into t.ctx select 'pod', id::text from pods;
do $$ begin
  assert (select v from t.ctx where k = 'code') ~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$', 'code is 6 unambiguous characters';
  assert (select status from pods) = 'open', 'new pod is open';
end $$;
select t.throws('select create_pod()', 'already_in_pod');
-- the creator is already a member, so their own code is refused before it is even looked up
select t.throws($q$ select join_pod((select v from t.ctx where k = 'code')) $q$, 'already_in_pod');
reset role;

-- @test join_pod: wrong codes are rate limited, the right code pairs, the code is then dead
select t.as_user(4);
do $$ declare r jsonb; begin
  for i in 1..5 loop
    r := join_pod('AAAAAA');
    assert r->>'error' = 'invalid_code', 'a wrong code returns invalid_code, not an exception';
  end loop;
end $$;
select t.throws($q$ select join_pod((select v from t.ctx where k = 'code')) $q$, 'too_many_attempts');
select t.as_user(2);
do $$ declare r jsonb; begin
  r := join_pod(lower(' ' || (select v from t.ctx where k = 'code') || ' '));
  assert r->>'pod_id' = (select v from t.ctx where k = 'pod'), 'code is case and whitespace tolerant';
  assert (select status from pods) = 'active', 'pod becomes active';
  assert (select invite_code from pods) is null, 'code is cleared on join';
end $$;
select t.as_user(3);
do $$ begin
  assert (join_pod((select v from t.ctx where k = 'code')))->>'error' = 'invalid_code', 'a used code is dead';
end $$;
reset role;

-- @test exactly two members, ever (trigger)
select t.throws($q$ insert into pod_members (pod_id, user_id) values ((select v::uuid from t.ctx where k = 'pod'), t.u(3)) $q$, 'pod_full');

-- @test expired invite codes are rejected
select t.as_user(5);
insert into t.ctx select 'code5', out_code from create_pod();
reset role;
update pods set invite_expires_at = now() - interval '1 hour' where created_by = t.u(5);
select t.as_user(6);
do $$ begin
  assert (join_pod((select v from t.ctx where k = 'code5')))->>'error' = 'invalid_code', 'expired code is invalid';
end $$;
reset role;

-- @test my_pod reports the partner
select t.as_user(1);
do $$ begin
  assert (select partner_name from my_pod()) = 'Teo', 'Mika sees Teo';
  assert (select status from my_pod()) = 'active', 'status active';
end $$;
select t.as_user(2);
do $$ begin assert (select partner_name from my_pod()) = 'Mika', 'Teo sees Mika'; end $$;
reset role;

-- @test writing own data, reading the partner's
select t.as_user(1);
insert into t.ctx select 'today1', current_local_date(t.u(1))::text;
select upsert_habit('11111111-1111-1111-1111-111111111111', (select v::uuid from t.ctx where k = 'pod'), 'Reading',
                    (select v::date from t.ctx where k = 'today1'), null);
select upsert_check_in((select v::uuid from t.ctx where k = 'pod'), (select v::date from t.ctx where k = 'today1'), 'held', null);
insert into habit_logs (habit_id, user_id, pod_id, local_date)
  values ('11111111-1111-1111-1111-111111111111', t.u(1), (select v::uuid from t.ctx where k = 'pod'), (select v::date from t.ctx where k = 'today1'));
-- upserting again changes the answer (same local day) and does not duplicate
select upsert_check_in((select v::uuid from t.ctx where k = 'pod'), (select v::date from t.ctx where k = 'today1'), 'slipped', 'Hard night');
do $$ begin
  assert (select count(*) from check_ins where user_id = t.u(1)) = 1, 'upsert does not duplicate';
  assert (select status from check_ins where user_id = t.u(1)) = 'slipped', 'same-day answer can change';
  assert (select note from check_ins where user_id = t.u(1)) = 'Hard night', 'note saved';
end $$;
select t.as_user(2);
select upsert_check_in((select v::uuid from t.ctx where k = 'pod'), current_local_date(t.u(2)), 'held', '  ');
do $$ begin
  assert (select count(*) from check_ins) = 2, 'Teo sees both pledges';
  assert (select note from check_ins where user_id = t.u(2)) is null, 'blank note is stored as null';
  assert (select count(*) from habits) = 1 and (select count(*) from habit_logs) = 1, 'Teo sees Mika''s habit and tick';
  assert (select display_name from profiles where id = t.u(1)) = 'Mika', 'partner name is readable';
end $$;
reset role;

-- @test an outsider sees nothing
select t.as_user(3);
do $$ begin
  assert (select count(*) from pods) = 0, 'pods';
  assert (select count(*) from pod_members) = 0, 'pod_members';
  assert (select count(*) from habits) = 0, 'habits';
  assert (select count(*) from habit_logs) = 0, 'habit_logs';
  assert (select count(*) from check_ins) = 0, 'check_ins';
  assert (select count(*) from urge_events) = 0, 'urge_events';
  assert (select count(*) from encouragements) = 0, 'encouragements';
  assert (select count(*) from profiles) = 1, 'profiles: only their own';
end $$;
select t.throws($q$ select upsert_check_in((select v::uuid from t.ctx where k = 'pod'), current_local_date(t.u(3)), 'held', null) $q$, 'row-level security');
reset role;

-- @test nobody writes as someone else, or outside the two-day window
select t.as_user(1);
select t.throws($q$ insert into check_ins (pod_id, user_id, local_date, status) values ((select v::uuid from t.ctx where k = 'pod'), t.u(2), current_local_date(t.u(1)) - 1, 'held') $q$, 'row-level security');
select t.throws($q$ select upsert_check_in((select v::uuid from t.ctx where k = 'pod'), current_local_date(t.u(1)) - 5, 'held', null) $q$, 'row-level security');
select t.throws($q$ select upsert_check_in((select v::uuid from t.ctx where k = 'pod'), current_local_date(t.u(1)) + 2, 'held', null) $q$, 'row-level security');
-- a tick on someone else's habit
select t.as_user(2);
select upsert_habit('22222222-2222-2222-2222-222222222222', (select v::uuid from t.ctx where k = 'pod'), 'Workout', current_local_date(t.u(2)), null);
select t.as_user(1);
select t.throws($q$ insert into habit_logs (habit_id, user_id, pod_id, local_date) values ('22222222-2222-2222-2222-222222222222', t.u(1), (select v::uuid from t.ctx where k = 'pod'), current_local_date(t.u(1))) $q$, 'row-level security');
-- the partner's pledge cannot be edited: not visible to update (0 rows) and key columns are not grantable
do $$ declare n int; begin
  update check_ins set status = 'held' where user_id = t.u(2);
  get diagnostics n = row_count;
  assert n = 0, 'cannot update partner''s pledge';
end $$;
select t.throws($q$ update check_ins set user_id = t.u(2) where user_id = t.u(1) $q$, 'permission denied');
select t.throws($q$ update check_ins set local_date = local_date - 1 where user_id = t.u(1) $q$, 'permission denied');
reset role;

-- @test a closed day cannot be changed
insert into check_ins (pod_id, user_id, local_date, status)
  values ((select v::uuid from t.ctx where k = 'pod'), t.u(1), current_local_date(t.u(1)) - 3, 'held');
select t.as_user(1);
select t.throws($q$ update check_ins set note = 'rewrite' where local_date = current_local_date(t.u(1)) - 3 $q$, 'day_closed');
reset role;

-- @test history cannot be deleted
select t.as_user(1);
select t.throws('delete from check_ins', 'permission denied');
select t.throws('delete from urge_events', 'permission denied');
reset role;
do $$ begin assert (select count(*) from check_ins) = 3, 'rows are still there'; end $$;

-- @test urge events and encouragements stay inside the pod
select t.as_user(1);
select t.throws($q$ insert into urge_events (pod_id, user_id) values ((select v::uuid from t.ctx where k = 'pod'), t.u(2)) $q$, 'row-level security');
insert into urge_events (pod_id, user_id) values ((select v::uuid from t.ctx where k = 'pod'), t.u(1));
insert into encouragements (pod_id, from_user, to_user, kind, template_key)
  values ((select v::uuid from t.ctx where k = 'pod'), t.u(1), t.u(2), 'nudge', 'hello');
select t.throws($q$ insert into encouragements (pod_id, from_user, to_user, kind, template_key) values ((select v::uuid from t.ctx where k = 'pod'), t.u(1), t.u(2), 'nudge', 'hello') $q$, 'one_nudge_per_day');
select t.throws($q$ insert into encouragements (pod_id, from_user, to_user, kind, template_key) values ((select v::uuid from t.ctx where k = 'pod'), t.u(1), t.u(3), 'cheer', 'proud') $q$, 'row-level security');
select t.throws($q$ insert into encouragements (pod_id, from_user, to_user, kind, template_key) values ((select v::uuid from t.ctx where k = 'pod'), t.u(2), t.u(1), 'cheer', 'proud') $q$, 'row-level security');
select t.throws($q$ insert into encouragements (pod_id, from_user, to_user, kind, template_key) values ((select v::uuid from t.ctx where k = 'pod'), t.u(1), t.u(2), 'cheer', 'free text') $q$, 'violates check constraint');
select t.as_user(2);
do $$ declare n int; begin
  assert (select count(*) from urge_events) = 1, 'Teo sees Mika''s urge';
  update encouragements set seen_at = now() where to_user = t.u(2);
  get diagnostics n = row_count;
  assert n = 1, 'recipient marks seen';
end $$;
select t.as_user(1);
do $$ declare n int; begin
  update encouragements set seen_at = null where to_user = t.u(2);
  get diagnostics n = row_count;
  assert n = 0, 'sender cannot touch seen_at';
end $$;
reset role;

-- @test devices are private
select t.as_user(1);
insert into devices (user_id, platform, push_token) values (t.u(1), 'android', 'tok-mika');
select t.as_user(2);
do $$ begin assert (select count(*) from devices) = 0, 'Teo cannot see Mika''s push token'; end $$;
reset role;

-- @test leaving ends access both ways and archives the pod
select t.as_user(1);
select leave_pod();
do $$ begin
  assert (select count(*) from my_pod()) = 0, 'leaver has no pod';
  assert (select count(*) from check_ins where user_id = t.u(2)) = 0, 'leaver cannot read the partner';
  assert (select count(*) from check_ins where user_id = t.u(1)) >= 1, 'leaver keeps their own data';
end $$;
select t.as_user(2);
do $$ begin
  assert (select status from my_pod()) = 'archived', 'remaining partner sees an archived pod';
  assert (select count(*) from check_ins where user_id = t.u(1)) >= 1, 'remaining partner can still read';
end $$;
select t.throws($q$ select upsert_check_in((select v::uuid from t.ctx where k = 'pod'), current_local_date(t.u(2)), 'held', null) $q$, 'row-level security');
select t.as_user(1);
insert into t.ctx select 'code2', out_code from create_pod();  -- and the leaver can start over
reset role;

-- @test anonymous callers cannot use the RPCs
set role anon;
select t.throws('select create_pod()', 'permission denied');
select t.throws($q$ select join_pod('AAAAAA') $q$, 'permission denied');
select t.throws('select count(*) from check_ins', 'permission denied');
reset role;
