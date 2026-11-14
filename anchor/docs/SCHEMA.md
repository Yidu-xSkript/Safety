# SCHEMA.md — Supabase / Postgres

Single source of truth for the backend. Put this in `supabase/migrations/0001_init.sql` when the project is created (split into numbered migrations as it grows). Anything not here does not exist.

Conventions: `uuid` primary keys, `timestamptz` for instants, `date` for **local days** (see "Local day" below), every table has RLS enabled, no table has a `delete` policy unless stated (so deletes are denied by default), and clients write through column-limited grants.

## Local day

A user's day does not end at midnight: an urge at 01:30 belongs to the evening before. `profiles.day_start_hour` (default 4) shifts the boundary.

```
local_date(now, tz, day_start_hour) = ((now at time zone tz) - day_start_hour hours)::date
```

The client computes `local_date` for writes; the server **verifies** it (insert policy below) so a client cannot back-date more than one day.

## Enums

```sql
create type pod_status         as enum ('open', 'active', 'archived');
create type pledge_status      as enum ('held', 'slipped');
create type urge_outcome       as enum ('passed', 'slipped', 'need_more');
create type device_platform    as enum ('android', 'ios');
create type encouragement_kind as enum ('urge_reply', 'slip_reply', 'nudge', 'cheer');
```

## Tables

```sql
create table profiles (
  id             uuid primary key references auth.users on delete cascade,
  display_name   text not null check (char_length(display_name) between 1 and 24),
  timezone       text not null default 'UTC',
  day_start_hour smallint not null default 4 check (day_start_hour between 0 and 6),
  created_at     timestamptz not null default now()
);

create table pods (
  id                uuid primary key default gen_random_uuid(),
  created_by        uuid not null references profiles(id),
  status            pod_status not null default 'open',
  invite_code       text unique,                 -- null once the pod is active
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
-- v1: one active pod per person
create unique index one_active_pod_per_user on pod_members (user_id) where left_at is null;

create table habits (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  pod_id      uuid not null references pods(id) on delete cascade,
  title       text not null check (char_length(title) between 1 and 40),
  icon_key    text not null default 'dot',
  sort_order  smallint not null default 0,
  archived_at timestamptz,                       -- soft delete: old rings keep their width
  created_at  timestamptz not null default now()
);

create table habit_logs (
  habit_id     uuid not null references habits(id) on delete cascade,
  user_id      uuid not null references profiles(id) on delete cascade,
  pod_id       uuid not null references pods(id) on delete cascade,  -- denormalised for Realtime filtering
  local_date   date not null,
  completed_at timestamptz not null default now(),
  primary key (habit_id, local_date)
);

create table check_ins (                          -- the daily pledge
  id         uuid primary key default gen_random_uuid(),
  pod_id     uuid not null references pods(id) on delete cascade,
  user_id    uuid not null references profiles(id) on delete cascade,
  local_date date not null,
  status     pledge_status not null,
  note       text check (char_length(note) <= 500),   -- visible to partner only
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, local_date)
);

create table urge_events (
  id           uuid primary key default gen_random_uuid(),
  pod_id       uuid not null references pods(id) on delete cascade,
  user_id      uuid not null references profiles(id) on delete cascade,
  created_at   timestamptz not null default now(),
  retracted_at timestamptz,                       -- "that was a mistake"
  resolved_at  timestamptz,
  outcome      urge_outcome
);

create table encouragements (                     -- prepared words only in v1, never free text
  id          uuid primary key default gen_random_uuid(),
  pod_id      uuid not null references pods(id) on delete cascade,
  from_user   uuid not null references profiles(id) on delete cascade,
  to_user     uuid not null references profiles(id) on delete cascade,
  kind        encouragement_kind not null,
  template_key text not null check (template_key in
     ('here','call_me','walk','proud','thank_you','new_ring','thinking_of_you','hello')),
  urge_id     uuid references urge_events(id) on delete set null,
  check_in_id uuid references check_ins(id)  on delete set null,
  created_at  timestamptz not null default now(),
  seen_at     timestamptz
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

create table join_attempts (                      -- invite-code brute-force limiter
  user_id uuid not null,
  at      timestamptz not null default now()
);
create index on join_attempts (user_id, at desc);
```

## Helpers and guards

```sql
create function is_pod_member(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from pod_members
                 where pod_id = p and user_id = auth.uid() and left_at is null);
$$;

create function is_active_pod_member(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select is_pod_member(p) and exists (select 1 from pods where id = p and status = 'active');
$$;

create function current_local_date(uid uuid) returns date
language sql stable security definer set search_path = public as $$
  select ((now() at time zone p.timezone) - make_interval(hours => p.day_start_hour))::date
  from profiles p where p.id = uid;
$$;

-- exactly two people per pod, ever
create function enforce_two_members() returns trigger language plpgsql as $$
begin
  if (select count(*) from pod_members where pod_id = new.pod_id) >= 2 then
    raise exception 'pod_full';
  end if;
  return new;
end $$;
create trigger pod_members_max_two before insert on pod_members
  for each row execute function enforce_two_members();

-- a day's pledge can be changed only on the same local day
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
```

## Row Level Security

```sql
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

-- profiles: me, or my partner in a shared pod
create policy profiles_select on profiles for select using (
  id = auth.uid() or exists (
    select 1 from pod_members a join pod_members b on a.pod_id = b.pod_id
    where a.user_id = auth.uid() and a.left_at is null
      and b.user_id = profiles.id and b.left_at is null));
create policy profiles_insert on profiles for insert with check (id = auth.uid());
create policy profiles_update on profiles for update using (id = auth.uid());

-- pods and members: read only; every write goes through the RPCs below
create policy pods_select on pods for select using (is_pod_member(id));
create policy pod_members_select on pod_members for select using (is_pod_member(pod_id));

-- habits / habit_logs / check_ins / urge_events: I read mine and my partner's; I write only mine, only in an active pod
create policy habits_select on habits for select using (user_id = auth.uid() or is_pod_member(pod_id));
create policy habits_write  on habits for insert with check (user_id = auth.uid() and is_active_pod_member(pod_id));
create policy habits_update on habits for update using (user_id = auth.uid());

create policy habit_logs_select on habit_logs for select using (user_id = auth.uid() or is_pod_member(pod_id));
create policy habit_logs_insert on habit_logs for insert with check (
  user_id = auth.uid() and is_active_pod_member(pod_id)
  and exists (select 1 from habits h where h.id = habit_id and h.user_id = auth.uid() and h.pod_id = habit_logs.pod_id)
  and local_date between current_local_date(auth.uid()) - 1 and current_local_date(auth.uid()));
create policy habit_logs_delete on habit_logs for delete using (   -- un-tick, same local day only
  user_id = auth.uid() and local_date = current_local_date(auth.uid()));

create policy check_ins_select on check_ins for select using (user_id = auth.uid() or is_pod_member(pod_id));
create policy check_ins_insert on check_ins for insert with check (
  user_id = auth.uid() and is_active_pod_member(pod_id)
  and local_date between current_local_date(auth.uid()) - 1 and current_local_date(auth.uid()));
create policy check_ins_update on check_ins for update using (user_id = auth.uid());
-- no delete policy on check_ins or urge_events: history is never silently removed

create policy urge_select on urge_events for select using (user_id = auth.uid() or is_pod_member(pod_id));
create policy urge_insert on urge_events for insert with check (user_id = auth.uid() and is_active_pod_member(pod_id));
create policy urge_update on urge_events for update using (user_id = auth.uid());

-- encouragements: send to my partner only; only the recipient marks seen
create policy enc_select on encouragements for select using (from_user = auth.uid() or to_user = auth.uid());
create policy enc_insert on encouragements for insert with check (
  from_user = auth.uid() and to_user <> auth.uid() and is_active_pod_member(pod_id)
  and exists (select 1 from pod_members m where m.pod_id = encouragements.pod_id
              and m.user_id = to_user and m.left_at is null));
create policy enc_update on encouragements for update using (to_user = auth.uid());

-- devices: mine only
create policy devices_all on devices for all using (user_id = auth.uid()) with check (user_id = auth.uid());
```

Column-limited writes, so a policy can stay simple and a client cannot rewrite what it should not:

```sql
revoke update on check_ins, urge_events, encouragements, habits from authenticated;
grant  update (status, note)                       on check_ins      to authenticated;
grant  update (retracted_at, resolved_at, outcome) on urge_events    to authenticated;
grant  update (seen_at)                            on encouragements to authenticated;
grant  update (title, icon_key, sort_order, archived_at) on habits   to authenticated;
```

## RPCs (the only way to create, join or leave a pod)

```sql
create function create_pod() returns table (out_pod uuid, out_code text, out_expires timestamptz)
language plpgsql security definer set search_path = public as $$
declare code text; pid uuid;
begin
  if exists (select 1 from pod_members where user_id = auth.uid() and left_at is null) then
    raise exception 'already_in_pod';
  end if;
  loop  -- 31-char alphabet, no 0/O/1/I; ~887M codes
    code := (select string_agg(substr('ABCDEFGHJKMNPQRSTUVWXYZ23456789',
              1 + (get_byte(gen_random_bytes(1), 0) % 31), 1), '') from generate_series(1, 6));
    exit when not exists (select 1 from pods where invite_code = code);
  end loop;
  insert into pods (created_by, invite_code, invite_expires_at)
    values (auth.uid(), code, now() + interval '24 hours') returning id into pid;
  insert into pod_members (pod_id, user_id) values (pid, auth.uid());
  return query select pid, code, now() + interval '24 hours';
end $$;

create function join_pod(code text) returns uuid
language plpgsql security definer set search_path = public as $$
declare p pods;
begin
  if (select count(*) from join_attempts where user_id = auth.uid() and at > now() - interval '1 hour') >= 5 then
    raise exception 'too_many_attempts';
  end if;
  if exists (select 1 from pod_members where user_id = auth.uid() and left_at is null) then
    raise exception 'already_in_pod';
  end if;
  select * into p from pods
    where invite_code = upper(trim(code)) and status = 'open' and invite_expires_at > now()
    for update;                                  -- serialises two simultaneous joins
  if not found then
    insert into join_attempts (user_id) values (auth.uid());
    raise exception 'invalid_code';
  end if;
  if p.created_by = auth.uid() then raise exception 'own_code'; end if;
  insert into pod_members (pod_id, user_id) values (p.id, auth.uid());   -- trigger enforces max two
  update pods set status = 'active', invite_code = null, invite_expires_at = null where id = p.id;
  return p.id;
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

grant execute on function create_pod(), join_pod(text), leave_pod() to authenticated;
```

Error strings (`already_in_pod`, `invalid_code`, `too_many_attempts`, `own_code`, `pod_full`, `day_closed`) are part of the contract; the client maps each to a calm sentence from `SOUL.md`.

## Realtime

```sql
alter publication supabase_realtime add table pods, pod_members, check_ins, habit_logs, urge_events, encouragements;
```

Clients subscribe with `postgres_changes` filtered by `pod_id`; Realtime applies RLS, so a partner only receives rows they may already read.

## Push triggers (Database Webhooks → Edge Function `notify`)

| Event | Recipient | Rationale |
|---|---|---|
| insert `urge_events` (not retracted) | partner | crisis ping |
| update `urge_events` set `retracted_at` | partner | "all clear" |
| insert/update `check_ins` where `status = 'slipped'` | partner | slip report |
| insert `encouragements` | `to_user` | reply or nudge |
| update `pods` set `status = 'archived'` | other member | partner left |
| insert `pod_members` (second member) | creator | partner joined |

Payload wording is fixed in `SECURITY.md` (generic on the lock screen).

## Account deletion and export

- `delete-account` Edge Function (service role): `auth.admin.deleteUser(uid)`. Foreign keys cascade the user's rows; the partner's pod is archived first via `leave_pod()`. Required by Apple App Review.
- `export_my_data()` (planned, Phase 5): returns the caller's check-ins, habits and habit logs as JSON.

## Test plan (pgTAP or SQL script in CI)

1. A third user cannot `select` any row of a pod they are not in.
2. A user cannot insert a check-in for a partner (`user_id` mismatch).
3. `join_pod` with a wrong code 6 times: the 6th raises `too_many_attempts`.
4. Two concurrent `join_pod` calls on one code: exactly one succeeds.
5. Updating yesterday's check-in raises `day_closed`.
6. `delete from check_ins` as an authenticated user affects 0 rows.
7. After `leave_pod()`, the leaver cannot read the partner's rows; the remaining partner can read, not write.
