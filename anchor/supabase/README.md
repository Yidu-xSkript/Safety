# supabase/

Backend for Anchor. Rules and rationale: [`docs/SCHEMA.md`](../docs/SCHEMA.md).

```
migrations/0001_init.sql   tables, RLS, RPCs, realtime
migrations/0002_push.sql   register_device
functions/notify/          Edge Function: webhook -> who? -> generic push (logic.ts is tested; fcm.ts, index.ts are I/O)
webhooks.example.sql       the five Database Webhooks that call it (template, fill in then run)
tests/stubs.sql            Supabase stand-ins (auth schema, roles) for the local runner only
tests/rls.sql              17 sections of SQL tests
tests/run.mjs              runs migration + tests on PGlite (no Docker)
```

## Run the tests (no account needed)

```bash
npm install @electric-sql/pglite          # once, in a folder outside the repo
PGLITE_DIR=<that folder> node supabase/tests/run.mjs
```

The Edge Function's rules, wording and its FCM JWT signing are tested under plain Node (no Deno, no install):

```bash
node --test "supabase/functions/notify/*.test.ts"
```

## Connect a real project (you do this once)

1. Create a project at [supabase.com](https://supabase.com) (free tier is enough).
2. **Authentication → Providers → Anonymous Sign-Ins: enable.** Anchor starts every user with an anonymous session. Consider enabling CAPTCHA protection there before launch to limit anonymous-account abuse.
3. **SQL Editor:** paste and run `migrations/0001_init.sql`. (Or with the CLI: `supabase link` then `supabase db push`.)
4. **Project Settings → API:** copy the project URL and the publishable (anon) key. Never put the `service_role` / secret key in the app.
5. Run the app against it:

```bash
flutter run --dart-define=SUPABASE_URL=https://<ref>.supabase.co --dart-define=SUPABASE_ANON_KEY=<publishable key>
```

Without those two values the app still runs; pairing then says "Anchor isn't connected to a server yet."

## Before launch

- Two phones, one pod, end to end on real hardware (the Dart client is tested against an in-memory server, not yet a live project).
- Two simultaneous `join_pod` calls on one code: exactly one must win.
- Notifications: follow `docs/PUSH.md` (Firebase project, APNs key, secrets, deploy `notify`, webhooks). Nothing there has run against a live project yet.
- `delete-account` arrives in Phase 5.
