# ROADMAP.md

Each phase ends in something a real person can use. Do not start phase N+1 with phase N's acceptance unmet. Phase 0–1 need no backend, so the design can be judged on a device early.

## Phase 0 — Foundations (1–2 days)
- `flutter create` (org `com.anchor`, Android + iOS only), dependency set from `ARCHITECTURE.md`, lints on.
- Theme from `DESIGN.md`: light and dark `ColorScheme`, text theme, Cupertino theme; bundled display font.
- `rings/`: `ring_model.dart`, `SlabPainter`, `RingGlyph` with golden tests for held / slipped / unchecked, light and dark, 1× and 2× text.
- Adaptive shell with three empty tabs; Urge FAB / toolbar action wired to a placeholder.
- **Accept:** goldens pass; shell renders correctly on a Pixel emulator and an iPhone simulator; dark mode and 130% font scale checked.

## Phase 1 — The solo loop, local only (2–4 days)
- Onboarding name + habits; Today with pledge card, habits, week strip, all against a local fake repository (demo partner data is synthetic and clearly labelled in code).
- Domain: `local_day`, `streak`, pod streak, ring widths with unit tests.
- Slip sheet, calm copy from `SOUL.md`; ring animation honours Remove animations.
- **Accept:** a full day can be logged offline; streak tests cover held/slipped/unchecked/pending/rollover cases; slab semantics read correctly in TalkBack and VoiceOver.

## Phase 2 — Pairing (3–5 days)
- Supabase project, `SCHEMA.md` applied, RLS test script green.
- Anonymous sign-in, profile, `create_pod` / `join_pod`, waiting screen over Realtime, error mapping.
- Today now reads the partner's real rows; outbox for check-ins and habit ticks.
- **Accept:** two physical phones pair with a code; a third account cannot read the pod; killing connectivity and returning replays without duplicates.

## Phase 3 — The hard moment (3–5 days)
- Firebase project (messaging only), device registration, `notify` Edge Function, generic wording from `SECURITY.md`.
- Urge flow end to end: instant open, ping, breathing guide, partner reply sheet, retract, end screen. Slip push and reply.
- Android channels, iOS time-sensitive level, app-icon shortcuts, deep links.
- **Accept:** on real hardware, pressing Urge notifies the partner in <5 s on average; lock-screen text matches the table; Urge works fully offline and sends on reconnect; no flashing or fast motion anywhere (checked against Reduce Motion).

## Phase 4 — History and care (2–4 days)
- History: month heatmap, day detail sheet, two summary numbers.
- Nudge ("Say hello") with one-per-day rule; daily local reminder.
- Pod settings: reminder time, partner's number (device-only), leave pod, "Secure your pod" email linking.
- **Accept:** leave pod ends access both ways, remaining partner sees read-only archive; email link survives reinstall.

## Phase 5 — Hardening and release (3–5 days)
- App lock, app-switcher cover, `FLAG_SECURE` setting; account deletion Edge Function; `export_my_data`.
- Accessibility audit: 200% text, TalkBack, VoiceOver, Reduce Motion, contrast spot-checks of both themes.
- Real-device pass: low-end Android, small iPhone, a tablet and iPad (content capped at 600dp).
- Store assets and privacy labels (data collected: name, user content; not used for tracking).
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
