# ARCHITECTURE.md

## Shape of the system

```
 Phone A (Flutter)                      Supabase                         Phone B (Flutter)
 ┌──────────────────┐   HTTPS/WS   ┌──────────────────────┐  HTTPS/WS  ┌──────────────────┐
 │ UI (Material /   │─────────────▶│ Auth (anonymous →    │◀───────────│ UI               │
 │  Cupertino)      │              │  email-linked)       │            │                  │
 │ Riverpod state   │◀─ Realtime ──│ Postgres + RLS       │── Realtime▶│ Riverpod state   │
 │ Outbox (offline) │              │ RPC: create/join/    │            │ Outbox           │
 │ FCM token        │              │      leave pod       │            │ FCM token        │
 └────────▲─────────┘              │ DB webhooks ─▶ Edge  │            └────────▲─────────┘
          │                        │   Function `notify`  │                     │
          └──── FCM / APNs ◀───────┴──────────────────────┴──── FCM / APNs ─────┘
```

Two phones never talk to each other. The pod is a row; both phones watch it.

## Decisions (and what would change them)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Framework | Flutter, one codebase | User's choice; reuses the repo's Flutter experience | — |
| Platforms | Android + iOS, adaptive design | User's choice; see `DESIGN.md` | — |
| Backend | Supabase | User's choice; SQL + RLS fits "only two people may read this" | RLS becomes unmanageable |
| Identity | Anonymous sign-in first, then link email (OTP) via "Secure your pod" | Zero friction and no email needed to start; reinstall recovery once linked | Store review or support load demands accounts up front |
| Push | FCM for both platforms (FCM relays to APNs), sent by an Edge Function | Single sender; Firebase is used **only** for messaging, no Firestore/Analytics | Self-hosting Supabase without Firebase |
| State | `flutter_riverpod` | Small, testable, no codegen required | — |
| Routing | `go_router` | Deep links from notifications, redirect guards (onboarding, app lock) | — |
| Models | Plain Dart classes with hand-written `fromJson` | ~8 small models; no `freezed`/`json_serializable` build step | >15 models or schema churn |
| Offline outbox | JSON list in key-value storage (`core/kv.dart`, shared_preferences underneath) | Only pledges, habit ticks and habit edits queue; a handful of items; ops are idempotent and coalesced by key | Need to queue more than this (move to `drift`) |
| Local secrets | `flutter_secure_storage` (session) | Keychain / Keystore | — |
| App lock | `local_auth` (biometric or device credential) | Discretion on shared phones | — |
| Streaks | Computed on the client in one pure Dart function | One implementation, unit-tested, works offline | A server-side feature (e.g. email digest) needs them |
| l10n | `flutter_localizations` + ARB from day one, English only | Amharic is a candidate; retrofitting strings is painful | — |

Dependencies are exactly: `supabase_flutter`, `flutter_riverpod`, `go_router`, `firebase_core`, `firebase_messaging`, `flutter_local_notifications`, `shared_preferences`, `flutter_secure_storage`, `local_auth`, `intl`, `url_launcher` (call/text), `cupertino_icons` (bundles the font `CupertinoIcons` draws from; added in Phase 0). In so far: Phase 0 `cupertino_icons`, `intl`; Phase 1 `flutter_riverpod`, `shared_preferences`; Phase 2 `supabase_flutter`, `share_plus` (the system share sheet for the invite code). Phase 3 added `firebase_core`, `firebase_messaging`, `url_launcher` (Call/Text), `quick_actions`. Phase 4 added `flutter_local_notifications`, `timezone`; Phase 5 added `local_auth`, `flutter_secure_storage` (and the dev-only `flutter_launcher_icons`). Not used: `go_router`. Adding one needs a reason in the PR.

## Code layout (feature-first)

```
anchor/
├── lib/
│   ├── main.dart                   # init Supabase, Firebase, ProviderScope
│   ├── app/
│   │   ├── router.dart             # go_router, guards: signedIn → hasPod → appLock
│   │   ├── theme.dart              # ThemeData (M3) + CupertinoThemeData from DESIGN.md tokens
│   │   └── shell.dart              # NavigationBar / NavigationRail / CupertinoTabScaffold
│   ├── core/
│   │   ├── adaptive/               # 4 helpers: adaptiveSheet, adaptiveDialog, adaptiveSwitch, AdaptiveScaffold
│   │   ├── supabase_client.dart
│   │   ├── local_day.dart          # day-rollover maths (04:00 default)
│   │   ├── outbox.dart             # queue + replay
│   │   ├── push.dart               # token registration, foreground handling, notification channels
│   │   └── errors.dart             # RPC error code → calm copy key
│   ├── features/
│   │   ├── onboarding/             # welcome, name, habits, create/join, waiting, secure-account
│   │   ├── today/                  # pod header, pledge card, habits, partner glance
│   │   ├── pledge/                 # held / slipped flow and slip sheet
│   │   ├── urge/                   # trigger, grounding screen, partner reply sheet
│   │   ├── history/                # week strip, month heatmap
│   │   ├── pod/                    # partner, reminders, app lock, leave, delete, export
│   │   └── rings/                  # SlabPainter, RingGlyph, ring_model.dart (signature component)
│   └── l10n/app_en.arb
├── test/                           # streak, local_day, outbox, ring_model, golden tests for painters
├── supabase/
│   ├── migrations/0001_init.sql    # copy of docs/SCHEMA.md
│   ├── functions/notify/           # Deno Edge Function: webhook → FCM v1
│   ├── functions/delete-account/
│   └── tests/rls.sql
└── android/ ios/                   # platform config (push entitlements, app shortcuts)
```

Each feature folder splits `data/` (repository, Supabase calls), `domain/` (pure Dart models and rules), `ui/` (widgets). UI never imports Supabase; repositories never import Flutter.

## Pairing and sync (as built in Phase 2)

- **`core/backend/pod_backend.dart`** is the only contract the app has with a server: sign in, profile, `myPod`, `createPod`, `joinPod`, `leavePod`, `fetchPartner`, a `changes` stream and `send(SyncOp)`. `SupabaseBackend` implements it; tests use an in-memory `FakeBackend` that shares one `FakeServer` between two phones. When `SUPABASE_URL`/`SUPABASE_ANON_KEY` are not supplied, `UnconfiguredBackend` makes pairing fail with a calm message.
- **Local data stays the source of truth for *your* side.** `SoloController` writes locally first, then `PodController.record()` queues a `SyncOp` (`CheckInOp`, `HabitOp`, `TickOp`) if a pod is active. Nothing waits on the network to show an answer.
- **Outbox rules:** ops are idempotent (server upserts); a newer op with the same key replaces the pending one (change your answer offline and only the last goes up); flushed in order; stops at the first *unreachable* error and retries every 30 s, on resume and after each new op; an op the server *refuses* is dropped so it cannot block the queue. The queue and the pod/partner cache persist in key-value storage, so closing the app loses nothing.
- **Partner data** is fetched (not streamed): Realtime only says "something changed in this pod" and the app refetches the partner's last 60 days, debounced 300 ms. It is cached, so Today opens instantly and offline. The partner's data has the same shape as yours (`SoloData`), so slab, streak and week-strip code is shared.
- **Activation backfill:** when a pod becomes active (either side), habits get real UUIDs (Phase 1 ids are migrated) and today's and yesterday's pledge/ticks are queued once. Older solo days stay on this phone because the server only accepts the last two days.
- **Root routing** (`main.dart`): not onboarded → onboarding; no/archived pod → pairing choice; open pod → waiting for the partner; just paired → "X is here." for ~2 s; active → the app.
- **Errors** are sorted into `PodErrorKind` (`invalidCode`, `tooManyAttempts`, `alreadyInPod`, `offline`, `notConfigured`, `other`) and each has one calm sentence (`SOUL.md`).

## Domain rules (pure Dart, `test/` covers each)

**Local day.** `localDate(now, tz, dayStartHour)` as in `SCHEMA.md`. A day is "closed" when `now` passes the next day's start.

**Day state per person.** `held`, `slipped`, or `unchecked`. A day that closed `unchecked` is drawn as a hollow dashed ring and does **not** count as slipped (silence is not confession).

**Streak (days held).** Walk back from the most recent day. Today with no check-in yet is *pending* and skipped (does not break). Count consecutive `held` days; stop at the first `slipped` or closed-`unchecked` day. A slip resets the count to 0; the rings keep the scar.

**Pod streak.** Same walk, counting days on which **both** people are `held`.

**Ring width.** `habitsDone / habitsTotal` for that day, where `habitsTotal` = habits that existed and were not archived on that day (`created_at` ≤ day < `archived_at`), so archiving a habit never reshapes the past.

**Sync chip.** "In sync" = both checked in today or yesterday; otherwise "Waiting on Teo" (neutral wording, never "behind").

## Offline

- Reads: last known state is cached in memory and persisted per pod in `shared_preferences` (JSON, ≤60 days) so the app opens instantly and offline.
- Writes: check-in, habit tick/untick and urge events go to the outbox first, are applied optimistically, and replay on connectivity or app resume. Each carries an idempotency key (`user_id + local_date` for check-ins, client-generated `uuid` for urge events), so replays upsert instead of duplicating.
- The grounding screen works with zero network. The partner ping queues and shows "Teo will be told as soon as you're back online" (calm, truthful).
- Conflict rule: the server wins except for same-day pledge edits by the owner (last write wins).

## Push (as built in Phase 3; full walkthrough in `docs/PUSH.md`)

1. **Consent:** Today shows *why* first (a card), and the system permission dialog appears only after "Turn on notifications". "Not now" is remembered (`anchor.push.asked`). A build without Firebase (`NoPush`) never asks.
2. **Token:** `PushController` registers the FCM token via `register_device` after consent, on every launch/resume, when a pod becomes active, and when Firebase rotates it.
3. **Send:** Database Webhooks call the `notify` Edge Function (`decide` → recipients → `message` → `fcmBody` → FCM HTTP v1). Fixed generic wording only; ids in `data`.
4. **Receive:** foreground: Realtime refetches and a Today card appears (no duplicate banner). Background/closed: the system shows the notification; a tap refreshes, then opens the reply sheet if the urge is still open (`main.dart` `_route`).
5. **Android:** channels `urge` (high), `pod`, `reminders` are created in `MainActivity` (no plugin); `POST_NOTIFICATIONS` is requested at runtime. **iOS:** `time-sensitive` for urges; Critical Alerts are not used.
6. **Icon shortcut:** `quick_actions` (`core/shortcuts.dart`) opens the grounding screen; `urgeOpenProvider` makes a second press a no-op.
7. **Urgent ops:** urge creation/retraction and replies are queued ahead of ordinary ops (in order among themselves); a queued ping older than 30 minutes is dropped, never delivered as a fresh alarm.
8. **Local daily reminder** (`flutter_local_notifications`) arrives in Phase 4.

## Care features (as built in Phase 4)

- **Pure rules** (`features/history/domain/history.dart`, `features/pod/domain/care.dart`): month grid cells for any weekday start, best streak, days held in a month, the sync state, when "hello" is offered, the next reminder time. All table-tested.
- **Settings** (`settings_controller.dart`): reminder time, partner's number, secure-card dismissals; key-value storage on this phone only. `reminderSyncProvider` reschedules the daily local notification whenever the setting or today's check-in changes, and on every app resume.
- **Reminders** (`core/reminders.dart`): `flutter_local_notifications`, a repeating daily notification scheduled in UTC (no timezone plugin; re-anchored at every launch) with inexact timing (no exact-alarm permission). Android needs core-library desugaring and a boot receiver (already in the Gradle/manifest files). Not yet run on a device.
- **Leaving:** `PodController.leavePod()` calls `leave_pod()` (archives the pod, ends both memberships' read access as the SQL tests prove), clears the queue and the pod cache, keeps your own history. The one who stayed gets an archived pod; `refresh()` keeps the partner's identity (the server stops naming them once they have left) and keeps reading their history, which `is_pod_member` still allows.
- **Account:** `AccountController` + `EmailCodeScreen`: `updateUser(email)` then `verifyOTP(emailChange)` to secure; `signInWithOtp(shouldCreateUser: false)` then `verifyOTP(email)` to come back. `PodController.restoreFromServer()` rebuilds our own name, habits, pledges and ticks plus the pod and partner, marks the pod as already uploaded so nothing is sent again.
- **History window:** both people's data is fetched for the last 366 days (`kHistoryDays`).

## Hardening (as built in Phase 5)

- **Lock** (`core/app_lock.dart`, `features/lock/`): `LockController` decides `locked` once at start (onboarded + a pod + the phone can lock + not turned off), then on resume after `kLockAfter` (30 s) away. `LockScreen` replaces the app inside `_Root`, so routes pushed on top (the Urge screen from its button or the icon shortcut) still work while locked. Turning the lock on or off requires a successful system prompt. Android needs `FlutterFragmentActivity`, `USE_BIOMETRIC` and an AppCompat launch theme (done); iOS needs `NSFaceIDUsageDescription` (done).
- **Cover:** `AnchorApp` overlays `PrivacyCover` while the lifecycle is `inactive`; `privacySyncProvider` mirrors the setting to Android's `FLAG_SECURE` through a method channel in `MainActivity`.
- **Session storage:** `SecureSessionStorage` (Keychain / Android Keystore) replaces Supabase's default preference storage.
- **Account data:** `AccountController.deleteAccount()` (server first, then `KV.clear()`), then the Pod page invalidates every provider so the app reloads empty at Welcome. `PodController.exportJson()` prefers `export_my_data()` and falls back to local data; sharing goes through `core/share.dart` (overridable in tests).
- **Tests that guard this:** `lock_test`, `account_data_test`, `accessibility_test` (tap targets, labels, overflow at 320dp / 200%), `no_logging_test`; text contrast is proven from the tokens in `contrast_test` (the pixel-sampling guideline is meaningless with the test font).
- **CI** (`.github/workflows/anchor.yml`): analyze + tests (goldens excluded via `dart_test.yaml`), SQL/RLS tests on PGlite, Edge Function tests on Node.

## Adaptive UI

One widget tree, three adaptive seams, all in `core/adaptive/`:

- **Shell:** `Theme.of(context).platform == iOS` ⇒ `CupertinoTabScaffold` + large-title sliver nav; otherwise `NavigationBar` (<600dp) or `NavigationRail` (≥600dp).
- **Overlays:** `adaptiveSheet` (`showModalBottomSheet` vs `showCupertinoModalPopup`/sheet), `adaptiveDialog` (`showAdaptiveDialog`), action sheets on iOS.
- **Controls:** use the framework's `.adaptive` constructors (`Switch.adaptive`, `Checkbox.adaptive`, `CircularProgressIndicator.adaptive`). The Urge entry point is an extended FAB on Android and a trailing toolbar button on iOS.

Everything else (cards, rings, lists, type, colour) is shared. If a screen needs a third platform branch, stop and rethink it.

## Testing

| Layer | What | How |
|---|---|---|
| Domain | streak, pod streak, local day, ring widths, outbox replay | `flutter test`, table-driven |
| Painters | slab and glyph in each state, light/dark, 1.0× and 2.0× text | golden tests |
| Widgets | pledge flow, slip sheet, urge flow | `flutter test` with fake repositories |
| Backend | RLS, RPCs, triggers | SQL test script against a local Supabase (`supabase test db`) |
| Device | push on real hardware, Dynamic Type, Reduce Motion, TalkBack/VoiceOver | manual checklist in `ROADMAP.md` Phase 5 |

## Environments and config

`--dart-define` for `SUPABASE_URL` and `SUPABASE_ANON_KEY`; never commit service keys. The anon key is public by design; RLS is the real gate. Firebase config files (`google-services.json`, `GoogleService-Info.plist`) are git-ignored; commit `*.example` placeholders.
