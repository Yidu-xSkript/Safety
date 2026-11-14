# SCREENS.md — screen inventory, flows and component map

Voice and copy: `SOUL.md`. Visual rules: `DESIGN.md`. Names below (Mika = you, Teo = partner) are **synthetic demo data**; no real people appear anywhere.

## Navigation

Three destinations, always visible: **Today · History · Pod**. Android: `NavigationBar` (<600dp) / `NavigationRail` (≥600dp). iOS: tab bar; large titles on History and Pod. System back always works; no screen traps the user.

The **Urge** action is persistent: Android extended FAB (label "Urge", `anchor` icon) bottom-trailing above the nav bar on all three tabs; iOS trailing toolbar button (`CupertinoIcons.hand_raised`, label "Urge"; Flutter ships no SF Symbols, and a raised hand reads as "reaching out") on all three. Also an app-icon shortcut (Android static shortcut, iOS quick action).

## Flow map

```
Launch ─▶ (no session)  Welcome ─▶ Your name ─▶ Pick habits ─▶ Create pod ─▶ Waiting (code) ─▶ Today
                                                         └──▶ Join pod  (enter code) ───────────▶ Today
       ─▶ (session, pod active)  [App lock] ─▶ Today
Today ─▶ Pledge: Held ─▶ (card collapses)         Today ─▶ Pledge: Slipped ─▶ Slip sheet ─▶ Today
Any tab ─▶ Urge ─▶ Grounding (3:00) ─▶ How are you now? ─▶ Today / Slip sheet
Notification: urge ─▶ Reply sheet · slip ─▶ Today (partner card + reply) · nudge ─▶ Today
Pod ─▶ Settings ─▶ Reminders · App lock · Partner's number · Leave pod · Delete account · Help
```

## Screens

### 1. Welcome
Purpose: one sentence of promise, one button. "Two people. One honest line a day." Buttons: **Get started** (filled), **I have a code** (text). Disclaimer line: not treatment, not a crisis service. No account wall: starts an anonymous session silently on Get started.

### 2. Your name
Text field, hint "A nickname is fine." Helper: "Your partner sees this. It also appears on notifications." Continue disabled until 1–24 chars.

### 3. Pick habits
Preset list with native checkboxes, all optional: Morning prayer, Night prayer, Workout (30 min), Reading, Phone away by 22:00. "Add your own" (≤40 chars, max 8 total). Prayer entries are plain presets: removable, renamable. Skip allowed ("Just the pledge for now").

### 4a. Create pod → 5. Waiting
Large code in the Display role, grouped `7K3 M2P`, with **Copy**, **Share** (system share sheet; message text is generic: "Join me on Anchor: 7K3M2P"). Caption: "Single use. Expires in 24 hours." When the partner joins (Realtime), transition to a short "Teo is here." moment, then Today. Option to regenerate a code.

### 4b. Join pod
6-cell code entry (auto-uppercase, paste-friendly, ambiguous characters rejected inline). Errors per `SOUL.md`. Success: "You and Teo are paired."

### 6. Secure your pod (optional, shown on day 2 and in Pod settings)
Email OTP to link the anonymous account. Copy states the real consequence: "Without this, a lost phone means a new pod." Dismissible, not nagging (twice in total).

### 7. Today (home)  — see `DESIGN.md` and the surface brief
1. App bar: pod name ("Mika & Teo"). Android: small pinned bar (keeps the pledge above the fold); iOS: large title, as top-level tabs use. Sync chip ("In sync" / "Waiting on Teo") arrives in Phase 4 with the nudge.
2. Pod header: two equal slabs, numerals beneath, pod line with pod streak.
3. Pledge card: before answer, "How was today?" with **Held the line** (filled) and **I slipped** (outlined). After: collapsed row "Held the line · 21:42" with "Change".
4. Habits card: "Habits · 3 of 4", native checkboxes; checking a habit sweeps today's ring (400 ms, emphasized decelerate).
5. Partner glance: Teo's habits as small ticks (sap), their pledge state in words, and **Say hello** (the one nudge per day) when Teo has not checked in.
6. Week strip: 7 ring glyphs × 2 people (also on History).

States: loading (slabs as hollow skeleton rings), offline banner ("Saved. Will send when you're back."), partner-not-checked-in (hollow ring, neutral words), archived pod (read-only, "Your pod has ended").

### 8. Slip sheet (modal bottom sheet / iOS sheet)
Copy in `SOUL.md`. Note field optional. **Tell Teo** sends; **Not yet** dismisses without saving. Never shows red; the ring that results is frost with the notch.

### 9. Urge (night register, full screen) — built in Phase 3
Built as described: opens within two frames with no network; the ping is queued first and goes out at once online (copy switches from "will be told the moment you're back online" to "has been told"); one slow ring (4 s in / 6 s out; still under Remove animations, with words and a soft haptic at each turn); one instruction a minute; the partner's reply appears as a card; Call/Text only with a number saved on this device (the setting arrives in Phase 4); the crisis-resource row stays behind `kShowCrisisResources = false` until the owner supplies a vetted list.
Opens **immediately** on tap, and sends the ping at once. No confirmation dialog. Top: "Teo has been told." Centre: one breathing ring (4 s in, 6 s out; Reduce Motion → text "In." / "Out." plus haptic ticks). Below: one instruction at a time, monumental type. 3:00 countdown in small text. Partner reply appears as a quiet card with **Call** / **Text** only if the user saved Teo's number locally. Bottom: **That was a mistake** (text button, retracts and sends all-clear), **Need more than a partner?** (feature-flagged, see SECURITY.md).
End screen: "How are you now?" with three answers; "I slipped" continues to the slip sheet, gently.

### 10. Reply sheet (partner side) — built in Phase 3
Opened from the urge push. Shows "Teo is reaching out." and 4 large prepared-reply buttons (here, call me, walk, proud) plus **Call** / **Text** if a number is saved. One tap sends and closes; confirmation is a snackbar/toast "Sent."

### 11. History
Top: week strip (you / Teo). Below: month grid; each day cell = two ring glyphs (you left, Teo right), 40dp tap target. Tap a day → sheet with that day's pledge, note (if any), habits done, replies. Month switcher in the app bar. Legend uses words, not just glyphs. Insights are limited to two numbers per person: best streak, days held this month.

### 12. Pod (tab)
Large title "Pod". Rows (grouped list, platform style): Partner (name, "paired since…"), Daily reminder time, App lock, Partner's number (device-only), Help and resources, Secure your pod, Leave pod, Delete account. Leave and Delete use platform confirm dialogs with plain consequence text.

## Notification taps

The `notify` function sends `data: {route: urge|today|pod, id?: <uuid>}` (ids only, never names or content). A tap on *reaching out* refreshes first, then opens the reply sheet if that urge is still open; `today` and `pod` just open the app. There are no URL-scheme deep links: nothing outside the app can open a screen by address.

## Today signal cards (Phase 3)

Above the pod header, only when there is something to answer, each a quiet card:
- **{Name} is reaching out.** + *Reply* (opens the reply sheet; gone once you have replied or they retract).
- **{Name} posted an update.** + their note + *Reply* (slip replies: thank you / tomorrow is a new ring / call me / proud of you).
- **{Name}: {kind word}**: a reply they sent you today.
- **Know when {Name} reaches out**: the one-time notification prompt (*Turn on notifications* / *Not now*).

## Component map (use these; do not invent)

| Need | Android (M3) | iOS |
|---|---|---|
| Primary action | `FilledButton` | `CupertinoButton.filled` (capsule) |
| Secondary | `OutlinedButton` / `TextButton` | `CupertinoButton` (plain/tinted) |
| Urge entry | `FloatingActionButton.extended` | trailing `CupertinoNavigationBar` action |
| Tabs | `NavigationBar` / `NavigationRail` | `CupertinoTabBar` |
| Habit tick | `Checkbox.adaptive` in `CheckboxListTile` | same adaptive |
| Toggles | `Switch.adaptive` | `CupertinoSwitch` |
| Sheets | `showModalBottomSheet` | `showCupertinoModalPopup` / sheet |
| Confirm | `showAdaptiveDialog` | same, renders Cupertino alert |
| Transient feedback | `SnackBar` | inline toast row (no snackbar on iOS) |
| Text input | `TextField` outlined 12dp | `CupertinoTextField` in grouped row |
| Rings | `CustomPainter` (shared) | shared |
