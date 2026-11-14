# SCHEMA.md — Supabase / Postgres

**The source of truth is [`supabase/migrations/0001_init.sql`](../supabase/migrations/0001_init.sql).** This file explains it; it does not repeat it. If they disagree, the migration wins and this file is stale. Rules are proven by [`supabase/tests/rls.sql`](../supabase/tests/rls.sql) (see "Tests").

Conventions: `uuid` keys, `timestamptz` for instants, `date` for **local days**, RLS on every table, no delete policy unless stated, least-privilege table grants, and writes that need an upsert go through RPCs.

## Local day

A user's day does not end at midnight: an urge at 01:30 belongs to the evening before.

```
local_date = ((now() at time zone 'utc') + utc_offset_min - day_start_hour hours)::date     -- day_start_hour defaults to 4
```

`profiles.utc_offset_min` is the phone's offset, sent by `set_profile` on every pairing action and refreshed by the client at launch (so DST is picked up at the next open). It is an offset, not an IANA zone, because Dart exposes the offset with no plugin. The client computes `local_date` itself; the server only checks it falls within today or yesterday.

## Tables

| Table | Holds | Notes |
|---|---|---|
| `profiles` | display name (≤24), `utc_offset_min`, `day_start_hour` | readable by you and your partner |
| `pods` | status `open → active → archived`, invite code, expiry | no client writes; RPCs only |
| `pod_members` | who is in which pod, `left_at` | max **two** rows per pod (trigger); one active pod per person (unique index) |
| `habits` | per-user habits; `created_day`, `archived_day` (dates) | `id` is **client-generated** so the outbox can replay safely; archived habits keep old rings intact |
| `habit_logs` | one row per habit per day ticked | `pod_id` repeated so Realtime can filter on it |
| `check_ins` | the daily pledge: `held` / `slipped` + note ≤500 | unique `(user_id, local_date)`; **never deleted**; editable only on the same local day (trigger `day_closed`) |
| `urge_events` | Phase 3 | no delete |
| `encouragements` | prepared replies only (template keys, no free text) | one `nudge` per sender per day (unique index) |
| `devices` | push tokens | private to the owner; the Edge Function reads them with the service role |
| `join_attempts` | invite-code brute-force limiter | no policies: RPC-only |

## Security model (all enforced in SQL)

- **Reads:** your own rows, plus your partner's rows while you are both in the pod (`is_pod_member`). An outsider sees nothing, in any table.
- **Writes:** only your own rows (`user_id = auth.uid()`), only while the pod is `active` (`is_active_pod_member`), and pledges/ticks only for today or yesterday.
- **Column grants:** clients can update only `status, note` on `check_ins`, `title, icon_key, sort_order, archived_day` on `habits`, `display_name, utc_offset_min` on `profiles`, and so on. Key columns are not updatable.
- **History:** no `delete` on `check_ins` or `urge_events`; a closed day cannot be edited; leaving a pod ends access both ways (you keep reading your own rows).
- **Anonymous callers:** no table or RPC access.

## RPCs (the only way in)

| Function | Runs as | Purpose |
|---|---|---|
| `set_profile(name, offset)` | caller | upsert own profile |
| `create_pod()` | definer | new open pod + 6-char single-use code (24 h); `already_in_pod` if you are in one |
| `join_pod(code)` | definer | pairs you; returns `{pod_id}` or `{error: 'invalid_code'}` (see below); raises `too_many_attempts` (5 wrong in an hour), `already_in_pod`, `pod_full` |
| `leave_pod()` | definer | ends your membership, archives the pod |
| `my_pod()` | caller | pod id, status, code, partner id and name in one call |
| `upsert_check_in(pod, day, status, note)` | caller | the pledge; replaces the same day's answer |
| `upsert_habit(id, pod, title, created, archived)` | caller | create or rename/archive a habit |
| `register_device(platform, token)` | definer | (`0002_push.sql`) store this phone's push token; the newest registration wins, so a shared phone or reinstall never collides with the old owner |

Codes use a 31-symbol alphabet without `0 O 1 I` (~887M codes), generated from a v4 UUID's random bytes.

### Two bugs the tests caught, worth remembering

1. **A raise rolls back the rate limiter.** `join_pod` first raised `invalid_code`; but the exception also undid the `join_attempts` row, so the limit never counted. A wrong code now *returns* `{error: 'invalid_code'}` (the row commits) and only hard conditions raise.
2. **PostgREST upserts need update rights on key columns.** An upsert's `SET` list includes the conflict columns, which the column grants correctly forbid. So pledges and habits go through the invoker RPCs above, which run under the caller's RLS and grants.

## Realtime

`pods, pod_members, check_ins, habit_logs, habits, urge_events, encouragements` are in the `supabase_realtime` publication. The client subscribes per pod (`postgres_changes`, filtered on `pod_id`/`id`) and just refetches when anything fires; Realtime applies RLS, so a partner only receives rows they may already read.

## Push triggers (Phase 3: Database Webhooks → Edge Function `notify`, see `docs/PUSH.md`)

| Event | Recipient |
|---|---|
| insert `urge_events` (not retracted) | partner |
| update `urge_events` set `retracted_at` | partner (all clear) |
| insert/update `check_ins` where `status = 'slipped'` | partner |
| insert `encouragements` | `to_user` |
| update `pods` set `status = 'archived'` | other member |
| insert `pod_members` (second member) | creator |

Wording is fixed in `SECURITY.md`.

## Account deletion and export (Phase 5)

`delete-account` Edge Function (service role: `auth.admin.deleteUser`) cascades the user's rows after `leave_pod()`. `export_my_data()` returns the caller's data as JSON.

## Tests

`supabase/tests/run.mjs` runs the migration and `rls.sql` (17 sections) on an in-process Postgres (PGlite) with Supabase stand-ins from `stubs.sql`. No Docker or Supabase needed:

```bash
# once, anywhere outside the repo:  npm install @electric-sql/pglite
PGLITE_DIR=<that folder> node supabase/tests/run.mjs
```

`urge_events` insert, retract and resolve are owner-only (the partner updates 0 rows; key columns are not updatable). Covered: code format and single use; wrong-code rate limit; two-member trigger; expiry; partner visibility; an outsider sees nothing in any table; no writing as someone else or outside the two-day window; closed days locked; no deletes; urge/encouragement scoping; private push tokens; leaving ends access; anonymous callers refused. The tests were checked for teeth by weakening four rules (open `select`, removed limiter insert, removed day-lock trigger, granted `delete`) and confirming each failed.

Not covered here: two *simultaneous* joins (serialised by the `for update` row lock; PGlite has a single connection). Test that against a real project before launch.
