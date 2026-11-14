-- Anchor 0001: tables, guards, RLS, RPCs, realtime. Mirrors docs/SCHEMA.md (that file explains the why).
-- Runs on Supabase as-is. supabase/tests/ runs it against a local Postgres (PGlite) with auth stubs.

-- ---------------------------------------------------------------- enums
create type pod_status         as enum ('open', 'active', 'archived');
create type pledge_status      as enum ('held', 'slipped');
create type urge_outcome       as enum ('passed', 'slipped', 'need_more');
create type device_platform    as enum ('android', 'ios');
create type encouragement_kind as enum ('urge_reply', 'slip_reply', 'nudge', 'cheer');

-- ---------------------------------------------------------------- tables
create table profiles (
  id             uuid primary key references auth.users on delete cascade,
  display_name   text not null check (char_length(display_name) between 1 and 24),
  -- Offset, not an IANA zone: Dart exposes the offset without a plugin. Refreshed on every launch, so DST is
  -- picked up at the next open.
  utc_offset_min smallint not null default 0 check (utc_offset_min between -840 and 840),
  day_start_hour smallint not null default 4 check (day_start_hour between 0 and 6),
  created_at     timestamptz not null default now()
);

create table pods (
  id                uuid primary key default gen_random_uuid(),
  created_by        uuid not null references profiles(id),
  status            pod_status not null default 'open',
  invite_code       text unique,
  invite_expires_at timestamptz,
  created_at        timestamptz not null default now(),
  archived_at       timestamptz
);

create table pod_members (
  pod_id    uuid not null references pods(id) on delete cascade,
  user_id   uuid not null references profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  left_at   timestamptz,
  primary key (pod_id, user_id)
);
create unique index one_active_pod_per_user on pod_members (user_id) where left_at is null;

create table habits (
  id           uuid primary key,                       -- client-generated, so the outbox can replay safely
  user_id      uuid not null references profiles(id) on delete cascade,
  pod_id       uuid not null references pods(id) on delete cascade,
  title        text not null check (char_length(title) between 1 and 40),
  icon_key     text not null default 'dot',
  sort_order   smallint not null default 0,
  created_day  date not null,
  archived_day date,                                    -- soft delete: old rings keep their width
  created_at   timestamptz not null default now()
);

create table habit_logs (
  habit_id     uuid not null references habits(id) on delete cascade,
  user_id      uuid not null references profiles(id) on delete cascade,
  pod_id       uuid not null references pods(id) on delete cascade,  -- denormalised for Realtime filtering
  local_date   date not null,
  completed_at timestamptz not null default now(),
  primary key (habit_id, local_date)
);

create table check_ins (
  id         uuid primary key default gen_random_uuid(),
  pod_id     uuid not null references pods(id) on delete cascade,
  user_id    uuid not null references profiles(id) on delete cascade,
  local_date date not null,
  status     pledge_status not null,
  note       text check (char_length(note) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, local_date)
);

create table urge_events (
  id           uuid primary key default gen_random_uuid(),
  pod_id       uuid not null references pods(id) on delete cascade,
  user_id      uuid not null references profiles(id) on delete cascade,
  created_at   timestamptz not null default now(),
  retracted_at timestamptz,
  resolved_at  timestamptz,
  outcome      urge_outcome
);

create table encouragements (
  id           uuid primary key default gen_random_uuid(),
  pod_id       uuid not null references pods(id) on delete cascade,
  from_user    uuid not null references profiles(id) on delete cascade,
  to_user      uuid not null references profiles(id) on delete cascade,
  kind         encouragement_kind not null,
  template_key text not null check (template_key in
     ('here','call_me','walk','proud','thank_you','new_ring','thinking_of_you','hello')),
  urge_id      uuid references urge_events(id) on delete set null,
  check_in_id  uuid references check_ins(id) on delete set null,
  created_at   timestamptz not null default now(),
  seen_at      timestamptz
);
create unique index one_nudge_per_day on encouragements (from_user, ((created_at at time zone 'utc')::date))
  where kind = 'nudge';

create table devices (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references profiles(id) on delete cascade,
  platform   device_platform not null,
  push_token text not null unique,
  updated_at timestamptz not null default now()
);

create table join_attempts (
  user_id uuid not null,
  at      timestamptz not null default now()
);
create index on join_attempts (user_id, at desc);

-- ---------------------------------------------------------------- helpers and guards
create function is_pod_member(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from pod_members
                 where pod_id = p and user_id = auth.uid() and left_at is null);
$$;

create function is_active_pod_member(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select is_pod_member(p) and exists (select 1 from pods where id = p and status = 'active');
$$;

-- The user's local day: UTC + their offset, minus the day-start shift (04:00 by default).
create function current_local_date(uid uuid) returns date
language sql stable security definer set search_path = public as $$
  select (((now() at time zone 'utc') + make_interval(mins => p.utc_offset_min))
          - make_interval(hours => p.day_start_hour))::date
  from profiles p where p.id = uid;
$$;

create function enforce_two_members() returns trigger language plpgsql as $$
begin
  if (select count(*) from pod_members where pod_id = new.pod_id) >= 2 then
    raise exception 'pod_full';
  end if;
  return new;
end $$;
create trigger pod_members_max_two before insert on pod_members
  for each row execute function enforce_two_members();

create function lock_past_check_ins() returns trigger language plpgsql as $$
begin
  if old.local_date < current_local_date(old.user_id) then
    raise exception 'day_closed';
  end if;
  new.updated_at := now();
  return new;
end $$;
create trigger check_ins_lock before update on check_ins
  for each row execute function lock_past_check_ins();

-- ---------------------------------------------------------------- row level security
alter table profiles       enable row level security;
alter table pods           enable row level security;
alter table pod_members    enable row level security;
alter table habits         enable row level security;
alter table habit_logs     enable row level security;
alter table check_ins      enable row level security;
alter table urge_events    enable row level security;
alter table encouragements enable row level security;
alter table devices        enable row level security;
alter table join_attempts  enable row level security;  -- no policies: RPC-only

create policy profiles_select on profiles for select using (
  id = auth.uid() or exists (
    select 1 from pod_members a join pod_members b on a.pod_id = b.pod_id
    where a.user_id = auth.uid() and a.left_at is null
      and b.user_id = profiles.id and b.left_at is null));
create policy profiles_insert on profiles for insert with check (id = auth.uid());
create policy profiles_update on profiles for update using (id = auth.uid());

create policy pods_select        on pods        for select using (is_pod_member(id));
create policy pod_members_select on pod_members for select using (is_pod_member(pod_id));

create policy habits_select on habits for select using (user_id = auth.uid() or is_pod_member(pod_id));
create policy habits_insert on habits for insert with check (user_id = auth.uid() and is_active_pod_member(pod_id));
create policy habits_update on habits for update using (user_id = auth.uid());

create policy habit_logs_select on habit_logs for select using (user_id = auth.uid() or is_pod_member(pod_id));
create policy habit_logs_insert on habit_logs for insert with check (
  user_id = auth.uid() and is_active_pod_member(pod_id)
  and exists (select 1 from habits h where h.id = habit_id and h.user_id = auth.uid() and h.pod_id = habit_logs.pod_id)
  and local_date between current_local_date(auth.uid()) - 1 and current_local_date(auth.uid()));
create policy habit_logs_delete on habit_logs for delete using (
  user_id = auth.uid() and local_date = current_local_date(auth.uid()));

create policy check_ins_select on check_ins for select using (user_id = auth.uid() or is_pod_member(pod_id));
create policy check_ins_insert on check_ins for insert with check (
  user_id = auth.uid() and is_active_pod_member(pod_id)
  and local_date between current_local_date(auth.uid()) - 1 and current_local_date(auth.uid()));
create policy check_ins_update on check_ins for update using (user_id = auth.uid());

create policy urge_select on urge_events for select using (user_id = auth.uid() or is_pod_member(pod_id));
create policy urge_insert on urge_events for insert with check (user_id = auth.uid() and is_active_pod_member(pod_id));
create policy urge_update on urge_events for update using (user_id = auth.uid());

create policy enc_select on encouragements for select using (from_user = auth.uid() or to_user = auth.uid());
create policy enc_insert on encouragements for insert with check (
  from_user = auth.uid() and to_user <> auth.uid() and is_active_pod_member(pod_id)
  and exists (select 1 from pod_members m where m.pod_id = encouragements.pod_id
              and m.user_id = to_user and m.left_at is null));
create policy enc_update on encouragements for update using (to_user = auth.uid());

create policy devices_all on devices for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------------------------------------------------------------- table privileges (least needed, explicit)
revoke all on all tables in schema public from anon, authenticated;
grant select                         on pods, pod_members                   to authenticated;
grant select, insert                 on profiles                            to authenticated;
grant update (display_name, utc_offset_min)  on profiles                    to authenticated;
grant select, insert                 on habits                              to authenticated;
grant update (title, icon_key, sort_order, archived_day) on habits          to authenticated;
grant select, insert, delete         on habit_logs                          to authenticated;
grant select, insert                 on check_ins                           to authenticated;
grant update (status, note)          on check_ins                           to authenticated;
grant select, insert                 on urge_events                         to authenticated;
grant update (retracted_at, resolved_at, outcome) on urge_events            to authenticated;
grant select, insert                 on encouragements                      to authenticated;
grant update (seen_at)               on encouragements                      to authenticated;
grant select, insert, update, delete on devices                             to authenticated;
-- no delete on check_ins or urge_events: history is never silently removed

-- ---------------------------------------------------------------- RPCs
-- Writes go through functions, not PostgREST upserts: an upsert's SET list would include the key columns,
-- which the column grants above rightly forbid. These run as the caller, so RLS and grants still apply.
create function set_profile(p_name text, p_offset int) returns void
language sql as $$
  insert into profiles (id, display_name, utc_offset_min) values (auth.uid(), p_name, p_offset)
  on conflict (id) do update set display_name = excluded.display_name, utc_offset_min = excluded.utc_offset_min;
$$;

create function upsert_check_in(p_pod uuid, p_day date, p_status pledge_status, p_note text) returns void
language sql as $$
  insert into check_ins (pod_id, user_id, local_date, status, note)
  values (p_pod, auth.uid(), p_day, p_status, nullif(trim(p_note), ''))
  on conflict (user_id, local_date) do update set status = excluded.status, note = excluded.note;
$$;

create function upsert_habit(p_id uuid, p_pod uuid, p_title text, p_created date, p_archived date) returns void
language sql as $$
  insert into habits (id, user_id, pod_id, title, created_day, archived_day)
  values (p_id, auth.uid(), p_pod, p_title, p_created, p_archived)
  on conflict (id) do update set title = excluded.title, archived_day = excluded.archived_day;
$$;

-- What the client needs to know about its pod in one call.
create function my_pod() returns table (
  pod_id uuid, status pod_status, invite_code text, invite_expires_at timestamptz,
  partner_id uuid, partner_name text, partner_joined_at timestamptz)
language sql stable as $$
  select p.id, p.status, p.invite_code, p.invite_expires_at, o.user_id, pr.display_name, o.joined_at
  from pod_members m
  join pods p on p.id = m.pod_id
  left join pod_members o on o.pod_id = m.pod_id and o.user_id <> m.user_id and o.left_at is null
  left join profiles pr on pr.id = o.user_id
  where m.user_id = auth.uid() and m.left_at is null;
$$;

create function create_pod() returns table (out_pod uuid, out_code text, out_expires timestamptz)
language plpgsql security definer set search_path = public as $$
declare code text; pid uuid; b bytea;
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  if exists (select 1 from pod_members where user_id = auth.uid() and left_at is null) then
    raise exception 'already_in_pod';
  end if;
  loop  -- 31-symbol alphabet without 0/O/1/I: ~887M codes. Bytes come from a v4 uuid (CSPRNG-backed).
    b := uuid_send(gen_random_uuid());
    code := (select string_agg(substr('ABCDEFGHJKMNPQRSTUVWXYZ23456789', 1 + (get_byte(b, i) % 31), 1), '')
             from generate_series(0, 5) i);
    exit when not exists (select 1 from pods where invite_code = code);
  end loop;
  insert into pods (created_by, invite_code, invite_expires_at)
    values (auth.uid(), code, now() + interval '24 hours') returning id into pid;
  insert into pod_members (pod_id, user_id) values (pid, auth.uid());
  return query select pid, code, now() + interval '24 hours';
end $$;

-- A wrong code *returns* an error instead of raising: a raise would roll back the join_attempts row that
-- the rate limit depends on.
create function join_pod(code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare p pods;
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  if (select count(*) from join_attempts where user_id = auth.uid() and at > now() - interval '1 hour') >= 5 then
    raise exception 'too_many_attempts';
  end if;
  if exists (select 1 from pod_members where user_id = auth.uid() and left_at is null) then
    raise exception 'already_in_pod';
  end if;
  select * into p from pods
    where invite_code = upper(trim(code)) and status = 'open' and invite_expires_at > now()
    for update;                                   -- serialises two simultaneous joins
  if not found then
    insert into join_attempts (user_id) values (auth.uid());
    return jsonb_build_object('error', 'invalid_code');
  end if;
  insert into pod_members (pod_id, user_id) values (p.id, auth.uid());   -- trigger enforces max two
  update pods set status = 'active', invite_code = null, invite_expires_at = null where id = p.id;
  return jsonb_build_object('pod_id', p.id);
end $$;

create function leave_pod() returns void
language plpgsql security definer set search_path = public as $$
declare pid uuid;
begin
  select pod_id into pid from pod_members where user_id = auth.uid() and left_at is null;
  if pid is null then return; end if;
  update pod_members set left_at = now() where pod_id = pid and user_id = auth.uid();
  update pods set status = 'archived', archived_at = now(), invite_code = null where id = pid;
end $$;

revoke execute on function set_profile(text, int), upsert_check_in(uuid, date, pledge_status, text),
  upsert_habit(uuid, uuid, text, date, date), my_pod(), create_pod(), join_pod(text), leave_pod()
  from public, anon;
grant execute on function set_profile(text, int), upsert_check_in(uuid, date, pledge_status, text),
  upsert_habit(uuid, uuid, text, date, date), my_pod(), create_pod(), join_pod(text), leave_pod()
  to authenticated;

-- ---------------------------------------------------------------- realtime
alter publication supabase_realtime add table pods, pod_members, check_ins, habit_logs, habits, urge_events, encouragements;
