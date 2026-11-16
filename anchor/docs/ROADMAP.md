# ROADMAP.md

Each phase ends in something a real person can use. Do not start phase N+1 with phase N's acceptance unmet. Phase 0–1 need no backend, so the design can be judged on a device early.

## Phase 0 — Foundations (1–2 days) · built
- `flutter create` (org `com.anchor`, Android + iOS only), dependency set from `ARCHITECTURE.md`, lints on.
- Theme from `DESIGN.md`: light and dark `ColorScheme`, text theme, Cupertino theme; bundled display font.
- `rings/`: `ring_model.dart`, `SlabPainter`, `RingGlyph` with golden tests for held / slipped / unchecked, light and dark, 1× and 2× text.
- Adaptive shell with three empty tabs; Urge FAB / toolbar action wired to a placeholder.
- **Accept:** goldens pass; shell renders correctly on a Pixel emulator and an iPhone simulator; dark mode and 130% font scale checked.

## Phase 1 — The solo loop, local only (2–4 days) · built
- Onboarding name + habits; Today with pledge card, habits, week strip, all against a local fake repository (demo partner data is synthetic and clearly labelled in code).
- Domain: `local_day`, `streak`, pod streak, ring widths with unit tests.
- Slip sheet, calm copy from `SOUL.md`; ring animation honours Remove animations.
- **Accept:** a full day can be logged offline; streak tests cover held/slipped/unchecked/pending/rollover cases; slab semantics read correctly in TalkBack and VoiceOver.
- **Built:** onboarding (welcome, name, habits), Today (pod header, pledge card, habits, week strip), slip sheet, local storage, 04:00 rollover on resume, ring sweep that honours Remove animations. End-to-end tests on both platforms. Not yet checked on a real TalkBack/VoiceOver or an emulator (none available on the dev machine).
- **Carried into Phase 2 (copy is deliberately partner-free while there is no partner):** restore "Held the line. Teo can see it.", the slip sheet's "Tell Teo" and "Teo will see this and can answer you" (`SOUL.md` copy bank); replace `rings/demo_data.dart` (synthetic Teo) with the real partner; the unread-day edge case when a partner joins mid-streak.

## Phase 2 — Pairing (3–5 days) · built, not yet run against a live project
- Supabase project, `SCHEMA.md` applied, RLS test script green.
- Anonymous sign-in, profile, `create_pod` / `join_pod`, waiting screen over Realtime, error mapping.
- Today now reads the partner's real rows; outbox for check-ins and habit ticks.
- **Accept:** two physical phones pair with a code; a third account cannot read the pod; killing connectivity and returning replays without duplicates.
- **Built:** `supabase/migrations/0001_init.sql` and 15 SQL test sections that pass on a real Postgres (PGlite); `PodBackend` interface with a Supabase client and an in-memory fake; anonymous sign-in, profile, create/join (6-char code, rate limited), waiting screen, "Teo is here." moment, partner data on Today over Realtime (refetch on change, cache for offline); outbox for pledges and ticks (coalesced, persisted, replayed in order, refused ops dropped); Phase 1 habit ids migrated to UUIDs; Teo copy restored. Two phones are simulated in tests (own storage, shared in-memory server).
- **Still to do before this is "accepted":** run the migration on a real Supabase project (steps in `supabase/README.md`) and pair two physical phones; test two simultaneous joins on one code. The Supabase client (`supabase_backend.dart`) has never talked to a live server.
- **Deferred from Phase 2, done in Phase 4:** the sync chip, and the ended-pod view that replaced "an archived pod returns you to the pairing choice". Still open: `flutter_secure_storage` for the session moves to Phase 5 with app lock.

## Phase 3 — The hard moment (3–5 days) · built, not accepted (no push has been sent to a real phone)
- Firebase project (messaging only), device registration, `notify` Edge Function, generic wording from `SECURITY.md`.
- Urge flow end to end: instant open, ping, breathing guide, partner reply sheet, retract, end screen. Slip push and reply.
- Android channels, iOS time-sensitive level, app-icon shortcuts, deep links.
- **Built:** the grounding screen (night register, breathing ring, one step a minute, end screen, "that was a mistake"), instant and offline-safe; the urge, retract and resolve ops with urgent ordering and stale-ping dropping; partner signal cards and the prepared-reply sheet (urge replies and slip replies, Call/Text when a number is saved); notification consent with a reason first and a remembered "Not now"; token registration (`register_device`); tap routing; the icon shortcut; the `notify` Edge Function (rules, exact wording, FCM JWT signing: 10 Node tests); Android channels, permission and conditional Google Services plugin; iOS `remote-notification`; `docs/PUSH.md`. 17 SQL sections, 167+ Dart tests.
- **Not done, needs you:** the Firebase project and APNs key, Xcode capabilities on a Mac, deploying `notify` and creating the webhooks (`docs/PUSH.md`), and the acceptance checklist on two real phones. `firebase_messaging` and the Android Gradle change have never been built (SDK licences) or run.
- **Accept:** on real hardware, pressing Urge notifies the partner in <5 s on average; lock-screen text matches the table; Urge works fully offline and sends on reconnect; no flashing or fast motion anywhere (checked against Reduce Motion).

## Phase 4 — History and care (2–4 days) · built, not run against a live project or a phone
- History: month heatmap, day detail sheet, two summary numbers.
- Nudge ("Say hello") with one-per-day rule; daily local reminder.
- Pod settings: reminder time, partner's number (device-only), leave pod, "Secure your pod" email linking.
- **Accept:** leave pod ends access both ways, remaining partner sees read-only archive; email link survives reinstall.
- **Built:** History (month grid with two ring glyphs a day, day sheet with pledge/note/habits for both of you, best streak and days held this month for each, a legend in words, month navigation bounded by where it began); the evening "Say hello" (from 18:00, only while they have not checked in, once a day, server-enforced) and the sync chip ("In sync" / "Waiting on Teo", never "behind"); Pod tab as a grouped native list (daily reminder with permission and a time picker, partner's number kept on this phone only, notifications on/off, secure your pod, leave pod with a plain confirmation); leaving ends it both ways and the one who stayed sees an ended pod (readable, not writable, grounding still works and quietly sends nothing, one button to start again); securing the anonymous account with an emailed code, a gentle card from day two (twice at most, never without a server), and "I already have an account" on Welcome, which rebuilds the pod, history and partner on a new phone without uploading anything. 237+ Dart tests incl. a reinstall simulated with two phones.
- **Not done, needs you:** the Supabase email templates must include the 6-digit `{{ .Token }}` (see `supabase/README.md`); the reminder and Android changes (desugaring, boot receiver) have never been built or run; real-phone check of "email link survives reinstall" and of leave/ended against a live project.

## Phase 5 — Hardening and release (3–5 days) · code-only parts built; real-device and store steps remain
- App lock, app-switcher cover, `FLAG_SECURE` setting; account deletion Edge Function; `export_my_data`.
- Accessibility audit: 200% text, TalkBack, VoiceOver, Reduce Motion, contrast spot-checks of both themes.
- Real-device pass: low-end Android, small iPhone, a tablet and iPad (content capped at 600dp).
- Store assets and privacy labels (data collected: name, user content; not used for tracking).
- **Built:** app lock (biometric or passcode, locks after 30 s away, never when the phone cannot lock or before there is a pod, Urge reachable from the lock screen); privacy cover in the app switcher and Android `FLAG_SECURE`, both on by default and switchable; Supabase session in the Keychain/Keystore; in-app **Delete account** (Edge Function `delete-account` + full local wipe; found and fixed a real schema bug: pod creators could not be deleted); **Export my data** (`export_my_data()`, falls back to the copy on the phone when offline); automated accessibility checks on every main screen (tap targets, labels, no overflow at 320dp / 200% text), which found and fixed unlabelled switches, a Welcome overflow, History cells at large text, and an unscrollable grounding screen; CI workflow; a no-logging test; app icon; `docs/STORE.md` (listing, privacy answers, review notes). 19 SQL sections, 10 + 4 Node tests, 300+ Dart tests.
- **Not done, needs a person or a device:** TalkBack/VoiceOver, low-end Android, small iPhone, tablet/iPad; the Android and iOS native changes have never been built (SDK licences); privacy policy and account-deletion URLs; the crisis-resource list; store accounts and signing; the two-simultaneous-join test; the `/impeccable document`, `audit` and `polish` passes on a real build.
- **Launch blockers:** curated, verified crisis-resource list (owner-supplied; see `SECURITY.md`); RLS suite green in CI; no sensitive text in logs.
- Re-run `/impeccable document` to regenerate `DESIGN.md` from code, then `/impeccable audit` and `/impeccable polish`.

## Later (not committed)
- Blocker bridge: the repo's `accountability_android` tamper/attempt events post a quiet entry to the pod timeline, with explicit consent from the protected partner. Needs its own privacy review.
- Home-screen widget showing the two slabs; Wear OS / watch glance.
- Amharic localisation (ARB is in place from Phase 0).
- Weekly gentle summary (local, not a push).
- Re-pairing flow after a pod ends.

## Explicitly never
Groups, feeds, public profiles, leaderboards, badges, paid streak protection, ads, analytics SDKs.
