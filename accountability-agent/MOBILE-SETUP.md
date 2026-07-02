# Mobile Setup (Android + iPhone)

Phones are covered by **native parental-control systems with the witness as parent/organizer**, plus **NextDNS**. There is no custom phone app in v1 — this is a manual setup checklist, the phone equivalent of the Windows `install.ps1`.

Custody rule is the same as everywhere: the **witness** holds the account passwords and passcodes; the protected user cannot loosen their own restrictions.

---

## Shared first step — NextDNS (both phones)

The witness owns the NextDNS config for this person (the same config used for their PC).
- In that config enable: **Parental Control → Porn** category, **Security → Block Proxies & VPNs**, and **Enforce SafeSearch**.
- This gives domain-level blocking + a full query log the witness can read — **incognito-proof** (DNS sits below the browser) and it covers apps, not just browsers.

---

## Android (witness = parent via Google Family Link)

1. **Private DNS (blocking + logging):** Settings → Network & internet → **Private DNS** → *Private DNS provider hostname* → enter the NextDNS DNS-over-TLS hostname (from the NextDNS "Setup" tab). Applies to every app and browser, incognito included.
2. **Google Family Link (reporting + app policy + tamper-resistance):**
   - The **witness** installs **Family Link** as the *parent*; this person's Google account is added as the member.
   - Enable: **app activity reports**, **app approval for installs**, **daily limits / app blocking** — map your agreed `appPolicies` here (block / time-limit the trigger apps).
   - Block **uninstalling Family Link** and changing its settings.
3. **Custody:** the witness holds the Google account password and the Family Link parent controls.

**What the witness sees on Android:** domains (NextDNS) **+ app usage/time and blocks** (Family Link). Not search terms (HTTPS-encrypted). Android can later gain a custom app for VPN-kill + foreground-title reporting.

---

## iPhone (witness = Family Organizer via Screen Time)

1. **NextDNS profile (blocking + logging):** install the NextDNS **configuration profile** (from NextDNS's Apple setup page). Covers all apps/browsers, incognito-proof.
2. **Screen Time under Family Sharing (reporting + app policy):**
   - The **witness** is the **Family Organizer**; this person is a family member.
   - Turn on **Content & Privacy Restrictions**.
   - Set a **Screen Time passcode only the witness knows.**
   - Use **Downtime / App Limits** to map your agreed `appPolicies`.
   - Turn on **prevent app deletion** so NextDNS + Screen Time can't be removed.
   - Enable **Share Across Devices**; the organizer can view activity reports.
3. **Supervise the device (recommended, closes the "just delete the profile" hole):** use **Apple Configurator** (free, needs a Mac + USB) to supervise the iPhone. A supervised device can pin the NextDNS DNS profile as **non-removable** and lock restrictions.

**What the witness sees on iPhone:** which **domains/sites** were accessed (NextDNS, incognito-proof) + rough Safari site/time (Screen Time). **NOT the actual search terms or full URLs** — iOS forbids reading another app's screen/tab title, and blocks the screenshot/TLS techniques that would capture searches. **No VPN kill on iOS.** This is Apple's ceiling, not a gap in this tool.

---

## Per-user assignment (mutual setup)

- **You (iPhone):** witness = your friend (he owns your NextDNS + holds your Screen Time passcode).
- **Your friend (Android):** witness = you (you own his NextDNS + are his Family Link parent).

## Honest ceilings (say them out loud together)

| | Android | iPhone |
|---|---|---|
| Block + domain history (incognito-proof) | yes | yes |
| Search terms / full URLs visible | no (HTTPS) | no (HTTPS + iOS limits) |
| App usage reports to witness | yes (Family Link) | yes (Screen Time) |
| VPN kill-switch | later (custom app) | not possible (Apple) |
| Uninstall/tamper resistance | Family Link | Screen Time + supervision |
