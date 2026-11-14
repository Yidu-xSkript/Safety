# PROMPT.md — build prompts for Claude Code

The original idea came from a video analysis plus a React/Artifacts prompt (a two-person habit tracker with invite-code pairing). This replaces it for the real product: a **Flutter** app with a Supabase backend and a distinct design language. Use the master prompt once to start, then a phase prompt per session.

## Master prompt (paste into a fresh Claude Code session in `anchor/`)

```
You are building Anchor, a Flutter app (Android + iOS) for two accountability partners.
Before writing code, read in order: SOUL.md, PRODUCT.md, DESIGN.md, docs/SCREENS.md,
docs/ARCHITECTURE.md, docs/SCHEMA.md, docs/SECURITY.md, docs/ROADMAP.md, CLAUDE.md.
They are authoritative. If something here conflicts with them, they win; tell me about the conflict.

Product in one paragraph: two people pair with a 6-character invite code. Each day each
logs one honest pledge ("Held the line" / "I slipped"), ticks a few daily habits, and sees the
other's state in real time. An Urge button pings the partner instantly and opens a calm
three-minute grounding screen that works offline. Visual language: every day is a growth ring;
a slip is a notched frost ring, never red. Look like a wellness app; speak gently; never shame.

Rules: exactly two people per pod; native adaptive controls (Material 3 / Cupertino through
core/adaptive); state never by colour alone; no confetti, badges or gamification; generic
notification text only; RLS on every table; smallest dependency set in docs/ARCHITECTURE.md.

Work one ROADMAP phase at a time. Start with Phase 0. For each phase:
1) restate the acceptance criteria, 2) implement, 3) write the tests the phase names,
4) run flutter analyze and flutter test, 5) run the app on an emulator/simulator in light, dark,
   130% and 200% text and report what you actually saw,
6) update DESIGN.md / SCHEMA.md if you changed tokens or tables.
Stop at the end of the phase and summarise: done, not done, risks, what you need from me.
Never invent crisis-resource phone numbers or URLs; leave the feature-flagged placeholder.
Never put personal names, emails or real data in files; demo people are Mika and Teo.
```

## Phase prompts

**Phase 0** — "Do ROADMAP Phase 0. Create the Flutter project in `anchor/`, theme from DESIGN.md (hex values only in `app/theme.dart`), the `rings/` feature with `SlabPainter` and `RingGlyph` per the DESIGN.md spec, golden tests for all three states in light and dark at 1× and 2× text, and the adaptive shell with three empty tabs and the Urge entry point."

**Phase 1** — "Do ROADMAP Phase 1. Build onboarding (name, habits) and the Today screen against a fake local repository. Implement `local_day`, `streak`, pod streak and ring widths as pure Dart with table-driven tests that cover held, slipped, unchecked, pending-today, and day-rollover at 04:00. Use the copy bank in SOUL.md verbatim where it exists."

**Phase 2** — "Do ROADMAP Phase 2. Create `supabase/migrations/0001_init.sql` from docs/SCHEMA.md exactly, plus `supabase/tests/rls.sql` for the seven tests listed there. Then anonymous auth, `create_pod`/`join_pod`, the waiting screen over Realtime, error-code mapping, and the check-in/habit outbox with idempotent replay."

**Phase 3** — "Do ROADMAP Phase 3. Implement the Urge flow per docs/SCREENS.md (screen 9, 10), the `notify` Edge Function with the exact strings from docs/SECURITY.md, Android channels, iOS time-sensitive level, app-icon shortcuts and deep links. The breathing guide must respect Remove animations / Reduce Motion with a text-and-haptic fallback and never flash."

**Phase 4** — "Do ROADMAP Phase 4: History (month heatmap with two ring glyphs per day, 40dp tap targets, day detail sheet), nudge with one-per-day, daily reminder, Pod settings, leave pod, email linking."

**Phase 5** — "Do ROADMAP Phase 5: app lock, switcher cover, account deletion, export, accessibility audit, store assets. Then run /impeccable document, /impeccable audit and /impeccable polish and apply the findings."

## Design-review prompt (any time after Phase 1)

```
/impeccable critique Today screen on both platforms. Judge against DESIGN.md and the Today
direction contract in .impeccable/surfaces/. Check: slabs equal weight, scar never red,
state not by colour alone, touch targets (48dp / 44pt), 200% text, Reduce Motion, night
register on Urge. Return ordered fixes only.
```

## Why this prompt differs from the original

- **Flutter + Supabase, not React Artifacts:** a real two-device product needs real sync, push and offline.
- **"Urge", not "SOS"; "slipped", not "relapsed":** discreet and non-shaming (see `SOUL.md`).
- **No free-text relay, no feed, no third viewer:** prepared words only, to keep the channel safe.
- **Honest streaks:** slips stay in the record as scars; silence is not counted as a slip.
- **Design is specified, not left to taste:** the ring system, palette, shapes and motion are in `DESIGN.md`.
