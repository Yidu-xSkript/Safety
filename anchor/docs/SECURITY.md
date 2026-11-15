# SECURITY.md — privacy and threat model

Anchor stores the most sensitive thing a person can tell another person. The design assumes the biggest risks are **a bystander** and **a lost or shared phone**, not a sophisticated attacker. The second risk is a **bug in RLS**, so RLS is tested like a feature.

## What is stored, and who can read it

| Data | Stored where | Readable by |
|---|---|---|
| Display name (≤24 chars), timezone | `profiles` | you, your partner |
| Pledge (held / slipped), optional note | `check_ins` | you, your partner |
| Habits and ticks | `habits`, `habit_logs` | you, your partner |
| Urge events | `urge_events` | you, your partner |
| Prepared replies | `encouragements` | sender, recipient |
| Push token | `devices` | you; Edge Function (service role) |
| Partner's phone number | **never leaves the device** (local only, key-value storage; set in Pod → Partner's number) | you |
| Secured email (optional) | Supabase Auth only, used to sign you back in with a code; no password is stored | you |

Never collected: contacts, location, advertising ID, browsing history, analytics SDKs, crash reporters that attach user data. If crash reporting is added later it must scrub all fields above.

## Lock-screen and notification wording (fixed strings)

Visible without unlocking. Never contains the words porn, relapse, slip, urge, struggling, clean, addiction.

| Event | Title | Body |
|---|---|---|
| Partner pressed Urge | Anchor | `{Name} is reaching out.` |
| Partner retracted | Anchor | `{Name} is okay.` |
| Partner slipped | Anchor | `{Name} posted an update.` |
| Reply received | Anchor | `{Name} sent you a message.` |
| Nudge | Anchor | `{Name} says hello.` |
| Partner left | Anchor | `Your pod has changed.` |
| Partner joined | Anchor | `{Name} joined your pod.` |
| Daily reminder (local) | Anchor | `Your daily check-in is open.` |

Android: visibility is `PUBLIC` because the text is already generic (FCM has no "public version" field, and `PRIVATE` would hide even the harmless wording). iOS: no `mutable-content` payload carries sensitive text. `data` carries ids only. The strings above are enforced by `supabase/functions/notify/logic.test.ts`, which also fails if any of *porn, relapse, slip, urge, struggling, clean, addiction* appears. See `docs/PUSH.md`. Display names are user-chosen, so onboarding suggests a nickname.

## Threats and mitigations

| Threat | Mitigation |
|---|---|
| Someone glances at the phone | App looks like a wellness app; generic notifications; no explicit words on any screen outside the app; Today shows rings, not text about the habit |
| Someone borrows the phone | Optional app lock (`local_auth`, biometric or device credential), on by default once a pod is active; locks after 30 s in background |
| App-switcher snapshot | Blur / solid cover when backgrounded; Android `FLAG_SECURE` as a setting (default on) |
| Someone guesses an invite code | 6 chars from a 31-symbol alphabet (~887M), single-use, 24 h expiry, 5 wrong tries per user per hour, row lock on join |
| Third party reads a pod | RLS on every table; `is_pod_member()` gate; RLS test suite in CI |
| Client tampers with history | No delete policy on `check_ins`/`urge_events`; column-limited update grants; same-day edit trigger; server verifies `local_date` |
| Partner abuses the channel | Replies are **prepared words only**, no free text in v1; one nudge per day; either person can leave in one tap; leaving ends all access immediately |
| Account takeover | Session in Keychain/Keystore; email-link OTP only after the user opts into "Secure your pod"; no passwords stored |
| Lost phone, no email linked | Honest limit: pod is unrecoverable. Onboarding states this once, plainly, and offers to link email |
| Server breach | No free-text beyond a ≤500-char note and a ≤24-char name; no phone numbers; no content that names the behaviour is ever *required* |

## Account and data rights

- **Delete account** is one screen in Pod → Settings, in-app (App Store requirement), backed by the `delete-account` Edge Function. It cascades the user's rows and archives the pod.
- **Leave pod** ends both people's access to each other's data as far as *new* data goes: the leaver can no longer read the partner at all; the one who stays keeps read-only access to history the pod already holds (and can start a new pod). Each keeps their own. In-app confirmation names the consequence and that it cannot be undone.
- **Export** (Phase 5): JSON of your own data.
- Retention: while the account exists. No backups are exposed to clients.

## Not a crisis service

Anchor supports recovery; it is not treatment and not an emergency channel. A "Need more than a partner?" row in the Urge screen and Pod settings links to a locale-aware list of professional and crisis resources. **That list must be curated and verified by the owner before launch; do not invent phone numbers or URLs in code.** Until it exists, the row is hidden behind a feature flag and the launch checklist in `ROADMAP.md` is blocked.

## Review checklist (every PR touching data or push)

- [ ] New table has RLS enabled and a test in `supabase/tests/rls.sql`.
- [ ] No new client-writable column without a justification in `SCHEMA.md`.
- [ ] New notification uses a string from the table above.
- [ ] No sensitive text in logs, route names, or analytics events.
