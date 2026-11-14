# Anchor

A two-person accountability pod. Once a day each partner logs one honest line, ticks a few daily habits, and sees the other's state in real time. A single Urge button pings your partner and walks you through three calm minutes. Every day is a growth ring; an honest slip is a scar the tree grows past.

Flutter (Android + iOS) · Supabase · adaptive Material 3 / Cupertino. Status: **Phases 0-2 built: theme, ring painters, adaptive shell, the daily loop, and pairing with offline sync. The SQL is tested; the Supabase client has not yet met a live project (see supabase/README.md). See docs/ROADMAP.md.**

> A tool, not treatment. Anchor supports recovery; it doesn't replace counselling, a support group or professional help.

## Document map

| File | What it answers |
|---|---|
| [SOUL.md](SOUL.md) | Why it exists, the voice, copy bank, what is never built |
| [PRODUCT.md](PRODUCT.md) | Users, purpose, positioning, constraints, principles |
| [DESIGN.md](DESIGN.md) | The Growth Ring visual system: colour, type, shapes, rules |
| [CLAUDE.md](CLAUDE.md) | Instructions and non-negotiables for Claude Code |
| [docs/SCREENS.md](docs/SCREENS.md) | Every screen, state, flow and component choice |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Stack decisions, code layout, domain rules, offline, push |
| [docs/SCHEMA.md](docs/SCHEMA.md) | Postgres tables, RLS, RPCs, triggers, tests |
| [docs/SECURITY.md](docs/SECURITY.md) | Privacy, notification wording, threat model |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Phases with acceptance criteria |
| [docs/PROMPT.md](docs/PROMPT.md) | Master and per-phase prompts to build it with Claude Code |
| [supabase/README.md](supabase/README.md) | Backend files, running the SQL tests, connecting a project |
| `.impeccable/surfaces/` | Direction contract for the Today screen |

## Start building

Open a Claude Code session in this folder and paste the master prompt from [docs/PROMPT.md](docs/PROMPT.md), starting at Phase 0.

## Design provenance

Direction chosen from an impeccable direction round (seed key `2ae865dd`, Operate mode): *Growth Rings*, a tree cross-section. `DESIGN.md` is a seed written before any code; once the app exists, run `/impeccable document` to regenerate it from the real tokens.
