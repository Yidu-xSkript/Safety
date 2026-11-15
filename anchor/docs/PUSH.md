# PUSH.md — notifications, end to end

What is built and tested: the app side (consent, token registration, tap handling, icon shortcut), the database side (`register_device`), and the `notify` Edge Function's rules, wording and FCM signing. **What has never run: a real push to a real phone.** That needs the Firebase project and hardware below. Treat Phase 3 as "built, not accepted" until the checklist at the end passes on two physical phones.

## How a notification travels

```
Teo presses Urge ─▶ urge_events INSERT (Postgres)
                   └▶ Database Webhook ─▶ Edge Function `notify`
                         decide() → who? → message() → fcmBody()
                         └▶ FCM HTTP v1 ─▶ APNs / Google ─▶ Mika's phone
Mika taps it ─▶ app refreshes ─▶ reply sheet ("Teo is reaching out.")
```

Foreground phones don't need the push: Realtime already refetches and the Today card appears. The push is for a phone that is asleep or closed.

## What a notification may say

Only these (the same table is enforced by `logic.test.ts`, which also fails on any of the words *porn, relapse, slip, urge, struggling, clean, addiction*). Title is always `Anchor`.

| Event | Body | Android channel | iOS level |
|---|---|---|---|
| Partner pressed Urge | `{Name} is reaching out.` | `urge` (high) | time-sensitive |
| Partner retracted it | `{Name} is okay.` | `pod` | active |
| Partner slipped | `{Name} posted an update.` | `pod` | active |
| Reply received | `{Name} sent you a message.` | `pod` | active |
| Nudge | `{Name} says hello.` | `pod` | active |
| Partner joined | `{Name} joined your pod.` | `pod` | active |
| Pod ended | `Your pod has changed.` | `pod` | active |

`data` carries ids only (`{route: 'urge', id: '<uuid>'}`): never a name or any content. Android visibility is `PUBLIC` because the text is already generic (FCM has no "public version" field). Channel names in system settings are "Reaching out", "Pod updates", "Reminders". No channel bypasses Do Not Disturb; Critical Alerts are not used.

## One-time setup (you do this)

### 1. Firebase project (messaging only)

1. Create a project at [console.firebase.google.com](https://console.firebase.google.com). Do **not** enable Analytics; Anchor uses Firebase for messaging only.
2. Add an **Android app**, package `com.anchor.anchor`. Download `google-services.json` into `android/app/`. (Git-ignored. The Gradle build applies the Google Services plugin only when this file exists, so the app still builds without it.)
3. Add an **iOS app**, bundle id `com.anchor.anchor`. Download `GoogleService-Info.plist` and add it to the Runner target **in Xcode** (File → Add Files…, "Copy items if needed", target Runner). Git-ignored.
4. **Project settings → Cloud Messaging → Apple app configuration:** upload an APNs Authentication Key (`.p8`, from your Apple Developer account → Keys → enable APNs).
5. **Project settings → Service accounts → Generate new private key.** Keep the JSON out of git; it becomes a Supabase secret.

### 2. Xcode (a Mac is required; this cannot be done from Windows)

Open `ios/Runner.xcworkspace` → Runner → **Signing & Capabilities** → add **Push Notifications**, **Background Modes** (tick *Remote notifications*), and **Time Sensitive Notifications**. Xcode writes the entitlements file and wires it into the project. (`Info.plist` already has `UIBackgroundModes: remote-notification`.)

### 3. Supabase

```bash
supabase secrets set WEBHOOK_SECRET=<a long random string> FCM_SERVICE_ACCOUNT="$(cat service-account.json)"
supabase functions deploy notify --no-verify-jwt     # the webhook authenticates with WEBHOOK_SECRET instead
```

Then create the webhooks: copy `supabase/webhooks.example.sql`, fill in the project ref and the same secret, run it in the SQL editor. (Or create the same five webhooks in Dashboard → Database → Webhooks.)

Run migration `0002_push.sql` too (`register_device`).

## On the phone, in order

1. After pairing, Today shows a card: *Know when Teo reaches out* with **Turn on notifications** / **Not now**. The system dialog appears only after the first button. "Not now" is remembered and never asked again (re-enable: Phase 4, Pod settings).
2. On yes, the app registers its FCM token with `register_device` (which hands the token to the newest owner, so a shared phone or reinstall never collides). The token is re-sent on every launch and resume, and whenever Firebase rotates it.
3. Tapping a notification opens the app; for *reaching out* it refreshes first and then opens the reply sheet, but only if the urge is still open (a retracted or old one opens nothing).
4. **Urge shortcut:** a long-press shortcut on the app icon (Android) / Home Screen quick action (iOS) opens the grounding screen directly. Two presses never send two pings.

## The daily reminder (local, no server)

Pod → Daily reminder schedules a local notification (title `Anchor`, body `Your daily check-in is open.`, channel `reminders`, low importance). It repeats daily, is rescheduled on every app open and on every change, and skips today once you have checked in. It uses inexact timing so no exact-alarm permission is needed (it may arrive a few minutes late). Android 13+ asks for notification permission when you turn it on; iOS asks at the same moment. Never run on a device yet.

## Safety rules baked in

- A ping that sat offline for more than 30 minutes is **dropped**, not delivered: arriving hours late it would read as a fresh alarm.
- Retracting ("That was a mistake") sends an all-clear push.
- A slip pings once, at the moment it becomes a slip; later note edits are silent.
- Dead tokens (`UNREGISTERED`) are deleted by the function so it stops sending to them.
- No push to anyone outside the two pod members; replies are prepared words only.

## Acceptance checklist (needs two real phones)

- [ ] Urge pressed on A reaches B in under ~5 s with the app closed; lock-screen text matches the table exactly.
- [ ] Tapping it opens the reply sheet; one tap sends; A sees the reply on the grounding screen.
- [ ] Retract on A produces "is okay." on B and the Today card disappears.
- [ ] A slip on A produces "posted an update." once.
- [ ] Urge works fully offline on A and sends when the network returns (within 30 min).
- [ ] Android: channels appear as "Reaching out / Pod updates / Reminders"; the urge channel heads-up.
- [ ] iOS: urge notification is time-sensitive; denied permission is respected and never re-asked.
- [ ] Two simultaneous `join_pod` calls on one code: exactly one wins (from `supabase/README.md`).
