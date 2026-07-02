# Accountability Blocker — Design Spec

**Date:** 2026-07-01
**Status:** Approved for planning
**Scope:** Personal tool first, **mutual two-person** setup. Designed to grow into a product.

---

## 1. Goal

A porn blocker with accountability. Block adult content, and make any attempt to reach it — including in incognito or over a VPN — visible to a trusted witness. The blocker stops the easy path; the accountability layer catches the rest and reports it. The model is not an unbreakable wall, it is a room where nothing can be done unseen.

Built for **two peers who are each other's witness** — the author and a friend, both fighting the same thing. Each runs the tool on their own devices; each is the other's accountability partner. Structured so the reporting layer can later be swapped from email to a hosted backend + dashboard and offered to others.

---

## 2. Roles

Symmetric and reciprocal. Two people, each playing both roles for the pair.

### 2.1 Protected User A (author)
Devices: **Windows PC + iPhone.** Uses a **standard, non-admin** Windows account. Cannot disable their own enforcement — User B holds the secrets.

### 2.2 Protected User B (friend)
Devices: **Windows PC + Android.** Same standard-user rule. User A holds B's secrets.

### 2.3 Mutual witness arrangement
- **B is A's Witness:** B owns A's NextDNS account, holds A's Windows admin password + iPhone passcode, and receives A's reports/alerts.
- **A is B's Witness:** A owns B's NextDNS account, holds B's Windows admin password + Android lock secrets, and receives B's reports/alerts.
- Neither can turn off their own protection; only the *other* person can.

### 2.4 Supporter (Partner mode) — optional, either user
A romantic partner may optionally be added as a **Supporter**: encouragement-only. Receives streaks, milestones, "clean week" confirmations. **Never** raw URLs, history, window titles, or relapse details. Keeps a partner included and encouraged without deputizing them as an enforcer or re-injuring them with raw data. Off unless explicitly enabled.

**Implemented (v1):** milestone emails to `supporterEmail` at `supporterMilestones` (default 7/30/90 days). A **clean day** = a day with no unapproved-VPN kill and no time-box breach (the agent-visible signals); the streak resets on a flagged day. Streak state lives in the **admin-only secrets dir** (SYSTEM-written) so the protected user cannot fabricate a milestone. **Honest caveat:** this uses only agent-visible signals — it does **not** yet detect an actual porn-site visit (that lives in NextDNS); making the streak fully truthful would require pulling NextDNS logs via its API (future work). It is encouragement, not a lie-detector.

---

## 3. Architecture (two layers, mirrored per person)

### Layer 1 — Blocking + history (all devices, free, no custom code)
**NextDNS** (free tier), each user's account owned by the *other* user (their Witness).
- Filters adult content at the DNS level. DNS resolves below the browser, so **incognito / private mode cannot hide it.**
- Logs every domain → the Witness views full history in the NextDNS web dashboard.
- Windows: applied and locked. iPhone: configuration profile. Android: Private DNS (Android 9+) or the NextDNS app.

### Layer 2 — Accountability agent (Windows only, custom — the part we build)
Identical on both users' PCs. Runs as a **SYSTEM service / scheduled task** a standard user cannot stop.
1. **Periodic report to the Witness** (email): recent browser URL history + active-window titles since last report.
   - **Incognito note:** the browser-history reader is a *supplement*, **not** the incognito defense — private mode does not write to the browser history file, so a history reader misses it. Incognito is caught by the two out-of-browser signals instead: the **NextDNS log** (authoritative, logs every domain regardless of browser mode) and **active-window titles** (read from the OS). Blocking in incognito works identically because DNS resolves below the browser.
2. **VPN allowlist + kill-switch + alert:** detect any active VPN tunnel and read its **remote peer IP** (the gateway the client dials). If it matches an **approved endpoint**, allow silently. Otherwise: **disable that VPN adapter/connection** (agent runs as SYSTEM) so the tunnel drops and the machine falls back to the NextDNS-filtered normal connection — *and* email the Witness. This is Option A: kill the unapproved VPN, keep normal internet working. Not a full internet kill-switch.
   - Reaction is **event-driven** (Windows network-change events) plus a short poll, so the tunnel is torn down within ~a second or two. A brief pre-detection window exists and is accepted.
   - The approved endpoint and the plain (no-VPN) connection are never touched.
   - Recovery from any misfire is via the Witness (admin) — by design, the standard user cannot re-enable a disabled adapter alone.
   - **Approved endpoint (User A / author):** `181.214.9.54` — the author's work VPN gateway to the New York database server; the only route to that DB. Allowed, no alert.
   - Any VPN dialing a **different** endpoint → reported instantly.
   - The report still logs *that* the approved VPN was active and when, so off-pattern use (e.g. 2am weekend) is visible even though the traffic itself isn't.
   - **Full-tunnel caveat:** while a full-tunnel VPN is active, NextDNS cannot see that traffic (the corporate filter guards it instead). Prefer **split-tunnel** for the work VPN so NextDNS keeps filtering all non-work browsing.
   - Per-user config: User B registers their own approved endpoints (if any) the same way.
   - **Tor Browser** routes around DNS entirely (like a VPN), so it is handled by this same path — detected, killed, and reported — not by the DNS layer.
   - **DoH / browser "secure DNS"** would let a browser dodge NextDNS; neutralized by a firewall rule blocking known DoH resolver servers (see enforcement hardening).
3. **Tamper alert:** service stopped/disabled/config-altered → notify Witness.
4. **Dead-man's switch:** Witness warned if a scheduled report fails to arrive on time.
5. **Supporter update (optional):** streak/milestone-only summary, stripped of raw data.

### Layer 3 — App & social-media policies (Windows agent + native phone limits)

Each app or category carries one of three policies, chosen **jointly by both users at setup** and stored in the admin-locked config (the protected user cannot change their own policy — that would defeat the point):

- **report-only** — usable; every session already appears in the NextDNS log + window-title report. No enforcement.
- **time-box** — the agent accrues per-app foreground minutes per day (by window-title match); when the daily limit is exceeded it alerts the witness and hard-blocks the app for the rest of the day. Phones use native Screen Time / Digital Wellbeing limits.
- **block** — the enforcer keeps the app's domains in the Windows **hosts file** (`127.0.0.1`), so the app/site fails to resolve. Reversible only by admin (witness). On phones, NextDNS denylist / Screen Time.

Rationale: "looking at women on social media" is a common lateral relapse — the compulsion reroutes when the front door is locked. Per-app policy lets the pair lock the specific trigger apps (block/time-box) while leaving genuinely-needed apps report-only.

### Phones (blocking + DNS-log accountability, via native parental systems)
No custom monitoring agent runs on either phone in v1; the phone accountability layer is the NextDNS query log plus the platform's own parental-control reporting, with the **witness as parent/organizer**.

- **iPhone (User A):** NextDNS profile + Screen Time restrictions, **locked with User B's passcode**; Screen Time under **Family Sharing** with User B as Family Organizer (activity reports + remote limits). To stop profile/Screen Time removal, the device should be **supervised** (Apple Configurator, free, needs a Mac + USB). iOS allows no monitoring agent and no VPN kill.
- **Android (User B):** NextDNS via **locked Private DNS** + **Google Family Link** with User A as parent (app activity reports, app blocking, daily limits, uninstall/settings lock). Android *can* support a stronger custom monitor later (accessibility service, VPN-kill parity, uninstall-block via device-owner) — deferred past v1.

#### iPhone web-activity limitation (explicit — set expectations)
On iPhone the witness sees **which sites/domains** were accessed but **NOT the actual search terms or full URLs**.
- **Visible:** every domain the phone resolves, via the NextDNS log — all apps and browsers, **incognito-proof** (DNS is below the browser). Plus rough Safari site + time in the Screen Time report.
- **NOT visible:** the search queries you type and specific page URLs — these are encrypted inside HTTPS; DNS and Screen Time can't see them.
- **Why iPhone is weaker than Windows here:** the Windows agent captures **active-window titles**, which often leak search terms/page titles. **iOS gives no app permission to read another app's screen or tab title**, so that layer cannot exist on iPhone. The only techniques that capture actual searches — screenshot monitoring or TLS decryption — are **blocked by Apple** on a normal iPhone (this limits every product, not just this one). Net on iPhone: *"which sites, incognito included"* — but not *"what was searched."*

---

## 4. How each requirement is met

| Requirement | Mechanism | Device |
|---|---|---|
| Block porn sites | NextDNS filtering | All |
| Witness sees history | NextDNS query log (Witness owns the account); Windows adds window titles (search terms). **iPhone = domains only, no search terms** | All |
| Works in incognito | DNS is below the browser; private mode can't hide it | All |
| VPN bypass | Windows agent **disables** any unapproved VPN (Option A) + alerts Witness; approved endpoint `181.214.9.54` exempt | Windows |
| Can't uninstall / tamper | SYSTEM service + standard-user account + tamper alert + dead-man's switch | Windows |
| Phone coverage | Locked NextDNS (+ Screen Time / Digital Wellbeing) | iPhone / Android |
| Social media / apps | Per-app policy: report-only / time-box / block (set by witness) | Windows + phones |
| Protect a partner | Optional Supporter mode: encouragement-only, no raw data | N/A |

---

## 5. What each person installs / holds (mirrored)

For each user, **the other user** holds: their NextDNS login, their Windows admin password, their phone lock/passcode.

**Each Protected User — Windows:** NextDNS applied + locked; the accountability agent (SYSTEM service); daily use via a standard non-admin account.

**User A — iPhone:** NextDNS profile + Screen Time, locked with B's passcode.
**User B — Android:** NextDNS Private DNS + Digital Wellbeing/Family Link, locked with A's secrets.

**As Witness, each person needs:** an email inbox + the NextDNS login they own for the other. No install on their own devices for the witness role.

---

## 6. Components (build boundaries)

The Windows agent is built as separate, independently-understandable pieces so the reporting channel can later be swapped without touching enforcement/monitoring:

1. **Monitor** — collects browser URL history + active-window titles.
2. **Detector** — watches for VPN/unknown network adapters and service-tamper.
3. **Reporter** — formats and sends output. Report types: full (Witness) and encouragement-only (Supporter). Delivery is pluggable: **email now**, backend API later.
4. **Watchdog / dead-man's switch** — ensures the agent is alive and reports arrive on schedule; alerts on failure.
5. **Service host** — runs the above as SYSTEM, resistant to a standard user stopping it.

The two users run **the same build**; only configuration differs (who reports to whom).

---

## 7. Growth path (personal tool → product)

- Keep the **Reporter** delivery pluggable. v1 = SMTP email. v2 = POST to a hosted backend with a web dashboard.
- Roles (Protected User / Witness / Supporter) become accounts; the mutual pair generalizes to any witness pairing or group.
- NextDNS stays as the blocking/logging layer, or is later replaced by an owned filtering service.
- Android gains the deferred stronger monitor; iOS depth stays capped by Apple.

---

## 8. Known limitations (stated honestly)

- **Collusion / mutual leniency.** Two people fighting the same thing as each other's *only* witness can drift into going easy on each other on bad weeks. Inherent to a pure two-person peer model (chosen deliberately). A shared third anchor was considered and declined; revisit if drift shows up.
- **VPN bypass is actively killed, not just reported (Option A kill-switch).** Any unapproved VPN adapter is disabled within ~1–2s and reported, so a VPN can't stay up long enough to be useful. Residual gaps: (a) the brief pre-detection window, and (b) the **approved work VPN (`181.214.9.54`)** — a deliberate allowlisted blind spot necessary for the author's job; if full-tunnel, the corporate filter guards that traffic.
- **iOS allows no monitoring agent, and shows domains but not search terms.** iPhone accountability = NextDNS domain log (incognito-proof) + Screen Time reports. Actual search queries/full URLs are not visible on iPhone (HTTPS-encrypted; iOS forbids the window-title capture Windows uses, and blocks screenshot/TLS-decrypt monitoring). No VPN kill on iOS. Android can go further with a future custom app.
- **A determined user with a second/unmanaged device defeats any of this.** The system assumes the user *wants* to be caught — inherent to the whole category.
- **Screenshots deliberately excluded** in favor of URL history + active-window titles: lighter, more private, still incognito-proof via NextDNS.
- **Free NextDNS tier (chosen for now) fails open at ~300k queries/month** — filtering silently stops until the month resets. Accepted for v1; upgrade to NextDNS Pro (~$2/mo, unlimited) to close it.
- **Other devices / router.** The agent covers this PC; other devices on the home network are only covered if NextDNS is also set on the router (recommended, not required for v1).
- **App policies are set by the witness, not the protected user** — deliberate, so the user can't loosen their own trigger apps.

---

## 9. Out of scope for v1

- Shared third-party anchor (pure two-person model chosen).
- Android monitoring agent / uninstall-block (deferred; DNS-log only in v1).
- Hosted backend / multi-user accounts / billing (growth path only).
- Custom DNS/WFP filtering driver (NextDNS covers it).
- Periodic screenshots.
