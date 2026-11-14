<!-- SEED: established with the user before implementation; re-run /impeccable document once there's code to capture the actual tokens and components. -->
---
name: Anchor
description: A two-person accountability pod where every day is a growth ring and an honest slip is a scar the tree grows past.
---

# Design System: Anchor

Surface mode: **Operate**. Platform: **adaptive** (Android Material 3, iOS HIG). Direction: **Growth Rings** (chosen by the user, seed key `2ae865dd`). The world supplies type, palette, density and one signature move. It never supplies navigation, layout model or controls: those are the platform's own.

Values below marked *(start)* are committed starting values, chosen against contrast math but not yet seen on a device. Verify them in the first build, then regenerate this file from code.

## Overview

**Creative North Star: "The Growth Ring"**

A tree does not keep a tally of its good days. It lays down one ring per season, wide when conditions were kind, narrow when they were not, and it keeps the scar of every fire it has survived. Anchor borrows that honesty. Each person is a slab of wood seen end-on; each day adds a ring; a day's habits set the ring's width; and a slip leaves a notch at twelve o'clock that stays in the record while the next ring grows past it. Nothing is erased, nothing is punished, nothing is celebrated with confetti.

The screen reads as a calm wellness app so it is safe to open in public: tinted ground, tonal layers, native controls. The rings are the only illustration. Two slabs always sit side by side at identical size, because the product has exactly two people and neither is the hero.

**Key Characteristics:**
- One signature move: concentric day-rings, drawn flat in two person-hues, with a 12 o'clock scar for a slip.
- Two person-hues only (cambium teal = you, sap amber = partner). Everything else is neutral or a scar.
- Tonal layering, no drop shadows. Platform navigation, sheets, switches and dialogs.
- State is never colour alone: held, slipped and unchecked each have their own *shape*.
- A separate **night register** for the Urge screen: darker, one dim warm hue, no pure white, no flashing.

## Colors

Strategy: **Committed shell, two person-hues.** A green-grey tinted ground carries the shell, cambium carries action and "you", sap carries "partner". Frost is reserved for the scar. System red (error) exists only for genuine errors such as network or auth failure and is **never** used for a slip.

### Primary
- **Cambium** (`#0A6556` light / `#4CCDB0` dark) *(start)*: you, the primary action, selected nav item, your rings. The living layer under the bark. 5.9:1 on Lichen, so it also works as button text.
- **Cambium Deep** (`#064A3E` light / `#1E6B5C` dark) *(start)*: your heartwood core and filled-tonal containers.

### Secondary
- **Sap** (`#B8721B` light / `#E9A94A` dark) *(start)*: your partner, in rings, their name chip and their habit ticks. 3.2:1 on Lichen: graphics and large numerals only, never body text. Text beside it uses on-surface.
- **Sap Deep** (`#7A4A0B` light / `#8A5C1C` dark) *(start)*: partner heartwood core.

### Tertiary
- **Frost** (`#6E8497` light / `#9DB3C6` dark) *(start)*: the scar. A slipped day's ring, its notch, and the "slipped" glyph. Cool and quiet on purpose; it must read as *marked*, not *alarmed*.

### Neutral
- **Lichen** (`#E9EEE7`) *(start)*: light ground. **Lichen Raised** (`#F4F7F2`): cards and sheets (tonal step up).
- **Spruce Night** (`#0F1A17`): dark ground. **Spruce Raised** (`#16241F`) and **Spruce High** (`#1D2D27`): dark tonal steps.
- **Spruce Ink** (`#14201C`) text on light, **Mist** (`#E3EBE6`) text on dark. Secondary text at 70% of these.
- **Hollow** (`#7B8781` light / `#6F7E77` dark): outlines for "not checked in" rings and dividers. Light value darkened from the first draft to clear 3:1 on Lichen (enforced in `contrast_test.dart`).

### Night register (Urge screen and after-22:00 check-ins)
- **Night Ground** (`#0A1210`), **Ember** (`#C98A3A`, dim sap) as the single annotation hue, **Lamp Text** (`#D9C6A5`) for copy. No pure white, no saturated red, maximum 15% of the screen carries Ember.

### Named Rules
**The Two Hues Rule.** Only two colours ever mean a person: cambium is you, sap is your partner, on both phones, in both themes. On your partner's phone the assignment flips (they see themselves as cambium) so each person always reads "me" as teal. Pod-level things (sync, streak line) use neutral ink.

**The Scar Is Not Red Rule.** A slip is never drawn in red, never in a warning triangle, never with a broken-chain icon. It is frost with a notch.

**The Not-Color-Alone Rule.** Every state pairs hue with shape: held = filled ring, slipped = frost ring with a notch, unchecked = hollow dashed ring. Screen readers get the same words.

**The Dynamic Color Rule.** Material You wallpaper colour is **off**. Two phones must show the same two hues or the metaphor breaks. (Offer it, if ever, only for surfaces that carry no person-state.)

## Typography

**Display Font:** Bricolage Grotesque *(start; bundled asset, OFL licence)* with system fallback, for numerals and headlines only.
**Body Font:** the platform system face (Roboto on Android, SF Pro on iOS), untouched.
**Label/Mono Font:** system face with tabular figures for heatmap and counts.

**Character:** The display face has slightly eccentric, hand-cut numerals that make "14 days" feel like a carved mark rather than a dashboard metric; everything functional stays in the face the OS user already trusts. Verify tabular/lining figure support on device; if absent, keep numerals in system tabular figures and use Bricolage for words only.

### Hierarchy (Material roles; iOS maps to Dynamic Type styles)
- **Display** (Bricolage 700, 56sp, 60 line): streak numerals under each slab only.
- **Headline** (Bricolage 600, 28sp, 34): screen titles on Pod and History, onboarding headings. iOS: large title.
- **Title** (system 600, 20sp, 28): card headings ("Today", "Habits").
- **Body** (system 400, 16sp, 24): all running copy, habit labels. Max 60ch.
- **Body Small** (system 400, 14sp, 20): partner glance lines, helper text.
- **Label** (system 500, 12sp, 16, +0.4 tracking): chips, nav labels, glyph legends. Never below 11pt on iOS.

### Named Rules
**The Sp Rule.** All sizes follow system font scale (Android sp, iOS Dynamic Type). Layout must survive 200%: slabs shrink before numerals clip, cards grow in height, nothing is fixed-height.
**The One Face Per Job Rule.** Bricolage is for numerals and headlines; it never sets buttons, inputs, labels or lists.

## Layout

Single column on phones, 16dp side gutters, 4dp base unit with steps 4 / 8 / 12 / 16 / 24 / 32 / 48. Content is capped at 600dp and centred on tablets and iPad; on Android expanded widths (≥600dp) the NavigationBar becomes a NavigationRail, on iPad the tab bar stays a top/floating tab bar per iPadOS convention. Edge-to-edge with window insets applied (status bar, gesture bar, cutout, keyboard). Back works everywhere: Android predictive back, iOS edge swipe.

Density is **calm**: three tonal card levels per screen at most, 24dp between groups, 12dp inside groups. The Today first viewport order is fixed: app bar, pod header (slabs), pledge card, habits. The Urge action is persistent on all three tabs.

Touch targets: 48dp Android, 44pt iOS, 8dp minimum gaps. Heatmap cells render at 40dp tap area even when the glyph is 20dp.

## Elevation & Depth

Flat by default. Depth is **tonal layering**: ground → raised card → high container (sheets, dialogs), using the neutral steps above. No drop shadows on cards or rings. The only shadow-like device is the platform's own scrim behind modal sheets. Slabs sit directly on the ground with no frame.

### Named Rules
**The Flat Ring Rule.** Rings are flat ink: no gradients, no glow, no inner shadow, no 3D bevel. Wood grain in the heartwood is hairlines, not texture.

## Shapes

Material 3 shape scale on Android, continuous corners on iOS:
- Cards and sheets: 20dp radius (sheets 28dp top corners).
- Buttons and chips: stadium/pill on Android; iOS uses `CupertinoButton` shapes (capsule for the primary pledge button, rounded rectangle elsewhere).
- Inputs: 12dp, outlined.

### Signature: The Growth Ring (CustomPainter, shared by both platforms)

A **slab** is 156dp across (scales to 120dp at 200% text and on 320dp-wide screens). From centre outward:
1. **Heartwood**: a filled disc, radius 20dp, in the person's *Deep* hue. Holds the person's initial (Title role, on-hue). Fine hairlines suggest compressed older days. Its presence is constant; the streak numeral beneath it says how many days it represents.
2. **Seven day-rings**: the last seven completed days, oldest innermost. Each ring is a stroke whose width = `lerp(2dp, 5dp, habitsDone / habitsTotal)` (a day with no habits still gets 2dp), with a 1.5dp gap between rings. Seven full days plus today fit inside the 156dp slab (asserted in `ring_model_test.dart`).
3. **Today ring**: outermost, 5dp. A faint full-circle track plus a sweep arc from 12 o'clock clockwise; sweep angle = habit completion for today. Before the pledge the track is **dashed**; held makes it **solid**; slipped makes it frost with the notch.

Per-ring pledge state:
| State | Stroke | Shape cue |
|---|---|---|
| Held | person hue, solid | continuous ring |
| Slipped | Frost | 14° notch cut at 12 o'clock ("the scar") |
| No check-in | Hollow outline | dashed, 2dp dash / 3dp gap |

A slip is permanent in the ring record. The ring after it is drawn normally: **the tree grows past the scar.**

**Ring glyph** (heatmap and week strip): the same three states at 20dp, as a filled disc, a frost disc with a 50° wedge removed at 12 o'clock (14° would vanish at that size), and a dashed hollow circle (3dp dash, 3dp gap). History shows two glyphs per day, yours left, partner's right.

**Pod line**: a 1.5dp neutral hairline joining the two slabs at their vertical centres: the "graft" between two trees. The pod streak ("Pod streak 14") is a quiet pill centred beneath both day counts; at 360dp there is no room for it on the line itself.

Accessibility: each slab exposes one semantic label: "Mika: 14 days held. Today: habits 3 of 4, pledge not yet made. Last seven days: held, held, held, slipped, held, held, held."

## Do's and Don'ts

### Do:
- **Do** draw two slabs at identical size and weight on every pod-level view. Neither partner is the hero.
- **Do** keep the scar in the record: a slipped day is drawn as a notched frost ring in history, forever.
- **Do** use native controls: M3 `NavigationBar`, `FilledButton`, `Checkbox`, `showModalBottomSheet`; Cupertino tab bar, `CupertinoSwitch`, action sheets.
- **Do** make the Urge screen the quietest screen in the app: night register, one instruction at a time, slow 4 s in / 6 s out breathing ring.
- **Do** write state in words as well as shape: "Held the line", "Slipped", "Not checked in".
- **Do** honour Reduce Motion / Remove animations: ring sweeps become instant, the breathing guide becomes a text cadence plus haptic ticks.

### Don't:
- **Don't** use red for a slip, a warning triangle, a broken-chain icon, a sad face, or the words "failed", "relapsed", "reset", "lost your streak".
- **Don't** add confetti, fireworks, trophies, badges, levels, XP, or leaderboards.
- **Don't** apply gradients, glows, inner shadows or textures to rings.
- **Don't** let any dark-mode screen use pure `#FFFFFF` text or pure `#000000` ground; the night register is dimmer still.
- **Don't** reinvent navigation, switches, dialogs or sheets; no iOS controls on Android or the reverse.
- **Don't** flash, strobe or pulse faster than 0.2 Hz anywhere, least of all in a crisis state.
- **Don't** show explicit words on anything visible without unlocking the app (see SECURITY.md notification table).
