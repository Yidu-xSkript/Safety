---
version: 1
slug: "lib-features-today-today-screen-dart"
primary_target: "lib/features/today/today_screen.dart"
related_targets: []
---

# Surface brief: Today (pod home)

Scope: the Today tab of Anchor, the first screen a paired user sees. Visitor mode: Operate (a person completing a 10-second daily ritual, or glancing at their partner).

Audience and job: one of two accountability partners, usually on a phone, often in public or late at night. Job: log today's honest pledge, tick disciplines, see the partner's state, and reach the Urge action without hunting.

Proof/content: all demo data is synthetic (Mika and Teo, streaks 14 and 22). No real users or metrics exist.

Memorable moment: the pod header, two equal tree slabs whose rings are the last seven days; a slip leaves a scar notch and the tree keeps growing.

Unresolved: whether Dynamic Color is ever offered as an opt-in (default: off, state hues must match across both phones); Bricolage Grotesque numerals need an on-device legibility check at 56sp.

## Direction contract

THESIS: A day is a ring. The Today screen owns one idea: two people's recent days drawn as growth rings, equal in weight, with an honest slip drawn as a scar the tree grows past. It refuses the category default of a streak counter, confetti, and a red failure screen.

OWN-WORLD: Spruce-night and lichen grounds; cambium teal (you) and sap amber (partner) as the only two person hues, frost slate for a scar; flat tonal layers, no drop shadows; Bricolage Grotesque for numerals and headlines over the platform system face; concentric ring strokes and a 12 o'clock notch recognisable with all copy removed.

STORY: The visitor understands in one glance whether both of them held the line today and how many days each has; believes the app will meet a slip with a prepared kind word, not a penalty; acts by tapping one pledge button, ticking habits, or the Urge action.

FIRST VIEWPORT: Small top app bar with pod name and a sync chip. Directly below, two equal slabs (about 156dp each) side by side, numerals beneath ("14", "22" days held), a thin pod-streak line between them. Then the pledge card (two native buttons: Held the line filled, I slipped outlined). Habits list begins above the fold edge. Urge extended FAB bottom-trailing on Android, trailing toolbar action on iOS. Material NavigationBar or Cupertino tab bar with Today, History, Pod.

FORM: Growth Rings (tree cross-section), candidate 5 of 7 on my ordered grounded list, assigned by the roll. Seed key 2ae865dd.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
