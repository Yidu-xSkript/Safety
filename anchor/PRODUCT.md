# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Stack

Flutter (Dart) for one codebase shipping to Android and iOS. Backend: Supabase (Postgres, Row Level Security, Realtime, Edge Functions, Auth). Push via FCM (Android) and APNs (iOS), sent from a Supabase Edge Function. Confirmed by the user.

## Users

Two people who have chosen each other as accountability partners, typically to quit porn or another compulsive habit while building a few positive daily disciplines (prayer, exercise, reading, sleep). Each is equal: there is no "protected" and "witness" role (that asymmetry belongs to the separate blocker app in this repo). They use the app in short moments: a morning or evening check-in, and in a crisis, an urge in the middle of the night with a phone in hand. They are often in public or shared spaces, so the app must not look like an addiction app.

## Product Purpose

Anchor is a two-person pod. Once a day each partner logs one honest status ("held the line" or "slipped") and ticks their daily disciplines; both see the other's state in real time. An urge button pings the partner instantly and walks the user through a grounding timer. Success: both people check in most days, a relapse gets reported within hours instead of hidden for weeks, and a partner's response arrives before the urge is acted on.

## Positioning

Not a solo streak tracker, not a community or feed. The mechanism is a mutual, closed pair paired by a short invite code: nobody else can ever see it, and neither person can quietly drop off because the other sees the silence. A slip is a status the partner is prepared to answer with a pre-written word of encouragement, not a punishment or a broken-streak failure screen. A neighbouring wellness or habit app could not truthfully copy this: it would need a closed two-person trust model, not an audience.

## Operating Context

- Pairing: partner A creates a pod and gets a 6-character invite code; partner B enters it; they are linked instantly. Exactly two members per pod, ever.
- Daily ritual: one check-in per local day (clean / slipped with optional private-to-partner note) plus a checklist of habits.
- Crisis ritual: Urge button → partner push notification + a 3-minute grounding screen (breathing guide, water/stand-up prompts) on the user's phone.
- Partner responses: one-tap prepared encouragements and a "call" / "text" shortcut that opens the phone's own dialer or messaging app.
- Notifications must be discreet on the lock screen (generic wording, no explicit text).
- Related but separate: the repo's `accountability-agent` and `accountability_android` blocker. Anchor is standalone. An integration (blocker events to the pod timeline) is a possible later phase, not part of v1.

## Capabilities and Constraints

- v1: onboarding, pod create/join/leave, daily pledge, habit checklist with presets and custom habits, streaks (personal and shared pod streak), urge button and grounding timer, partner encouragements, weekly heatmap and calendar history, discreet push notifications, light and dark themes.
- Hard rule: a pod has exactly two members. No groups, feeds, comments, public profiles, or leaderboards.
- Hard rule: relapse data is only ever visible to the two pod members. RLS enforces this server-side, not just the UI.
- Honest-by-design: a slip can be reset but history is never silently rewritten by the app; users may add a note, not delete the record. (Edits within the same local day are allowed.)
- Terminology: "Pod" (the pair), "Partner", "Check-in", "Held the line" / "Slipped", "Urge" (not "SOS" in user-facing copy: calmer, discreet), "Anchor" is the product name.
- Offline: check-ins queue locally and sync when back online; the Urge button must still show the grounding screen offline and push when connectivity returns.
- Undecided: whether faith-specific copy ships by default (prayer is a preset habit, fully editable or removable), localisation (Amharic is a candidate second language), whether the pod can be re-paired after one partner leaves (v1: leaving archives the pod, partner is told, a new pod starts clean).

## Brand Commitments

Product name: Anchor. Tone: honest, steady, never shaming and never cheerleading. No confetti, no "you failed" screens. Must look like a calm wellness or fitness app in public. No personal names, emails, or real user data in any shipped file or demo data; all sample people are synthetic.

## Evidence on Hand

No real users, metrics, or testimonials exist. None may be fabricated. Source brief: the pasted video-analysis and prompt (two-player shared habit tracker, invite-code pairing, paper-prototype-to-AI workflow) summarised in `docs/PROMPT.md`. The sibling blocker app in the repo (`accountability_android/`) is Flutter and its patterns (platform channels, config) are reference, not dependency.

## Product Principles

1. Two people, not an audience. Every feature must strengthen the trust between exactly two partners; anything that adds a third viewer is out.
2. Honesty over streaks. A truthful slip with a note is a better outcome than a perfect-looking streak; the UI must make telling the truth the easy, unpunished path.
3. Fast when it matters. Check-in is under ten seconds; the Urge button is reachable in two taps from anywhere, including the lock-screen notification path, and works offline.
4. Discreet by default. Looks like a wellness app, speaks in neutral words on lock screens, never exposes content to a bystander glancing at the phone.
5. Replace, don't just resist. Positive disciplines sit beside the pledge so the day is more than not-doing.

## Accessibility & Inclusion

WCAG 2.2 AA minimum; target sizes 48dp (Android) / 44pt (iOS); respects system font scale/Dynamic Type, Reduce Motion/Remove animations, screen readers (status is never colour-only: every green/red dot also carries a shape or label). The breathing guide must work without relying on visual motion alone (haptics and text cadence). Crisis states use calm language and low visual intensity: no red alarms, no flashing.
