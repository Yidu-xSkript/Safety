# STORE.md — listing, privacy answers, review notes

Drafts for you to review and own. Nothing here has been submitted, and the privacy answers below need your sign-off (and, for a health-adjacent app, ideally a lawyer's eye) before you publish them.

## Listing (neutral by design)

The listing must be as discreet as the app: it should never name the behaviour, because it shows in search, in purchase history and in notifications.

- **Name:** Anchor
- **Subtitle / short description (≤80):** A quiet daily check-in for two people who keep each other steady.
- **Category:** Health & Fitness (alternative: Lifestyle). Age rating: see "Rating" below.
- **Full description:**
  > Anchor pairs you with one person you trust. Once a day, each of you logs one honest line and ticks a few daily habits, and you both see how the other is doing. If a moment gets hard, one button lets your partner know and walks you through three calm minutes. A slip is never punished: it stays in the record as a mark, and the next day starts fresh.
  >
  > • Exactly two people: no feeds, no groups, no strangers
  > • Daily check-in and habits (prayer, exercise, reading, sleep… you choose)
  > • A reaching-out button with a quiet, three-minute grounding screen that works offline
  > • Prepared words your partner can send back, so nobody has to find the right thing to say
  > • Private by default: app lock, nothing shown in the app switcher, notifications that never say what the app is for
  > • Export or delete everything, any time, inside the app
  >
  > Anchor supports recovery. It isn't treatment, and it isn't a crisis service.
- **Keywords (iOS, 100 chars):** accountability,habit,check-in,streak,partner,daily,routine,wellbeing,discipline,focus
- **Screenshots (plan):** (1) Today with both rings, (2) the check-in, (3) the grounding screen, (4) History month, (5) Pod settings/privacy. Take them from a real device on synthetic data (Mika and Teo), light and dark. Never include real names or notes.
- **Icon:** `assets/icon/` (regenerate with `flutter test tool/make_icon.dart` then `dart run flutter_launcher_icons`).

## Apple: App Privacy ("nutrition label")

| Data type | Collected | Linked to user | Used for tracking | Purpose |
|---|---|---|---|---|
| Name (a nickname the user chooses) | Yes | Yes | No | App functionality |
| Email address (only if the user secures their account) | Optional | Yes | No | App functionality (sign-in) |
| User content: check-ins, notes, habits, replies | Yes | Yes | No | App functionality |
| Identifiers: user ID, push token | Yes | Yes | No | App functionality |
| Health & fitness / sensitive info | **Decide:** a daily "held the line / slipped" record about a personal struggle may count as sensitive; declare it conservatively | Yes | No | App functionality |
| Location, contacts, browsing history, purchases, diagnostics, advertising data | **No** | | | |

No third-party analytics, no advertising SDKs, no crash reporter. The partner's phone number is stored only on the user's own device and is not collected.

## Google Play: Data safety

- Data collected and shared: **none shared with third parties.** Collected (for app functionality, linked to the user): name, email (optional), user-generated content, user ID, device/push token.
- Encrypted in transit: **yes** (TLS to Supabase/Firebase). At rest: managed by the backend provider.
- Data deletion: **yes, in the app** (Pod → Delete account). Google also requires a **web page where a person can request deletion** (for users who have lost the app). **Needed from you:** a URL.
- Committed to follow the Play Families policy: no (not a children's app).

## Needed from you before submitting

- [ ] **Privacy policy URL** (required by both stores). It must match the tables above and the in-app behaviour: collects a nickname, check-ins/notes/habits, an optional email and a push token; nothing else; nothing sold or shared; deletion and export in the app.
- [ ] **Account-deletion web page URL** (Google Play).
- [ ] **Support URL / email.**
- [ ] **Curated, verified crisis-resource list** per supported locale (`docs/SECURITY.md`). The in-app row stays off until it exists; stores may also ask what the app does for users in crisis.
- [ ] Apple Developer + Google Play accounts, signing keys (never commit them), and the Firebase/APNs setup from `docs/PUSH.md`.
- [ ] Final decision on the content rating and the sensitive-data declaration.

## Rating

Suggested starting point, to confirm in each store's questionnaire: mature themes are referenced only in the abstract (no explicit content anywhere in the app or the listing). Answer the questionnaires literally, and note that the app contains no user-to-user free text (replies are prepared words), which is relevant to the "user-generated content" questions.

## Review notes (paste into App Store Connect / Play Console)

> Anchor pairs exactly two people. To review the full flow you need two devices (or one device plus one simulator/emulator):
> 1. On device A: Get started → enter a nickname → Create a pod. A 6-character code appears.
> 2. On device B: Get started → enter a nickname → "I have a code" → enter the code.
> Both devices are then paired. No account or password is needed (sessions start anonymously). Optional: Pod → Secure your pod adds an email code sign-in. Account deletion: Pod → Delete account. Data export: Pod → Export my data.
> The "Urge" button opens a calm 3-minute screen and notifies the partner. Notifications use deliberately generic text. Notification permission is requested only after an explanation screen.
> We can provide two pre-paired test accounts on request.

## Release checklist (engineering)

- [ ] CI green (`.github/workflows/anchor.yml`), and the two-simultaneous-join test passed on a live project (`supabase/README.md`).
- [ ] `docs/PUSH.md` acceptance checklist passed on two real phones.
- [ ] Real-device accessibility pass: TalkBack and VoiceOver through Today, Urge, History, Pod; 200% text; Reduce Motion. (The automated tap-target, label and overflow checks already pass in `test/accessibility_test.dart`.)
- [ ] Low-end Android phone, a small iPhone, a tablet and an iPad (content is capped at 600dp).
- [ ] Release signing, version/build numbers, obfuscation/symbols if you add crash reporting later (and scrub it of all user data).
- [ ] `/impeccable document`, `/impeccable audit`, `/impeccable polish` on the real build, then regenerate screenshots.
