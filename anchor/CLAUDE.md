# CLAUDE.md — Anchor

Anchor is a Flutter app (Android + iOS) for **two accountability partners**: one honest pledge a day, a shared habit checklist, an Urge button that pings the partner, and a growth-ring visual language. Backend is Supabase. It is a standalone project inside this repo; the sibling `accountability-agent/` and `accountability_android/` blockers are separate products.

## Read first, in this order

1. `SOUL.md` — why it exists, the voice, words to use and avoid, what is never built.
2. `PRODUCT.md` — users, purpose, constraints (the impeccable product record).
3. `DESIGN.md` — the Growth Ring visual system. Then `.impeccable/surfaces/` for the Today direction contract.
4. `docs/SCREENS.md` — every screen, state and component choice.
5. `docs/ARCHITECTURE.md`, `docs/SCHEMA.md`, `docs/SECURITY.md` — before touching code, data or push.
6. `docs/ROADMAP.md` — find the current phase; don't build ahead of it.

## Non-negotiables

- **Exactly two people per pod.** No groups, feeds, public profiles, comments, leaderboards, badges.
- **Never red for a slip.** Slip = frost ring with a 12 o'clock notch. Never the words failed, relapsed, reset, "lost your streak". Check `SOUL.md` before writing any string.
- **State is never colour alone.** Held = filled, slipped = notched frost, unchecked = hollow dashed. Every ring has a semantic label.
- **History is not erased.** No delete path for check-ins or urge events; same-day edits only.
- **Generic notifications.** Use only the strings in `docs/SECURITY.md`. No explicit words on any lock-screen text, route, log or analytics event.
- **Native controls, adaptive.** Material 3 on Android, Cupertino on iOS via the three seams in `core/adaptive/`. No iOS widgets on Android or the reverse. System Back always works.
- **Urge works offline** and opens instantly (no confirm dialog).
- **No pure white text or pure black ground** in dark themes; night register for the Urge screen.
- **No new dependency** beyond the list in `docs/ARCHITECTURE.md` without a stated reason.
- **RLS is the gate.** The anon key is public; any new table ships with RLS and a test.
- **No personal data in the repo or demo data.** Sample people are Mika and Teo, labelled synthetic.

## Commands

```bash
flutter pub get
flutter analyze                       # must be clean
flutter test                          # domain + golden tests
flutter test --exclude-tags golden    # what CI runs (goldens are pixel-exact per OS)
flutter test --update-goldens         # only when a painter or layout change is intended
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...   # without them, pairing says "not connected"
PGLITE_DIR=<folder with @electric-sql/pglite> node supabase/tests/run.mjs        # migrations + RLS tests, no Docker (see supabase/README.md)
node --test "supabase/functions/notify/*.test.ts" "supabase/functions/delete-account/*.test.ts"                                # push rules, wording, FCM signing; plain Node
```

## Working agreements

- Smallest thing that works; the dependency and layout choices in `ARCHITECTURE.md` already apply that rule. Mark deliberate shortcuts with a `ponytail:` comment naming the ceiling.
- UI never imports Supabase; repositories never import Flutter. Domain rules (streak, local day, ring widths) are pure Dart with table-driven tests.
- Colours, type and spacing come from the theme, never literals in widgets. Hex values live in `app/theme.dart` only, mirroring `DESIGN.md`.
- Every painter change gets golden tests in light + dark, 1× and 2× text.
- Verify UI on an emulator/simulator (and say which): light, dark, 130% and 200% text, Reduce Motion on. Do not claim a screen works from analyzer output alone.
- Any change to design tokens or the ring spec updates `DESIGN.md` in the same PR; any change to tables or policies updates `docs/SCHEMA.md` and its migration.
- When design work is requested, use `/impeccable` (`shape`, `polish`, `audit`, `document`) and keep `PRODUCT.md` as the source of product truth. After the first build, run `/impeccable document` to replace the seed `DESIGN.md` with one derived from code.

## Open decisions (ask the owner, don't guess)

- Curated crisis-resource list per locale (launch blocker).
- Whether the default habit presets include prayer entries (current plan: yes, as removable presets).
- Amharic localisation timing.
- Final display-font check on device (Bricolage Grotesque numerals).
