# Android Companion App — Design Spec

**Date:** 2026-07-02
**Status:** Approved for planning
**Scope:** Android-only companion app for the accountability system. Extends the Windows agent's guarantees to the friend's Android phone. Designed so the email reporting layer can later swap to a backend.

---

## 1. Goal

Close the one real hole in the current Android setup: a user can toggle on a VPN to bypass NextDNS. This app **holds the single Android VPN slot** with its own `VpnService`, routing DNS to NextDNS (un-bypassable filtering + logging) while making a bypass VPN impossible to start. It adds **tamper/uninstall resistance** (Device Admin + witness-PIN release) and **email alerts** on tamper/VPN-off/silence.

Blocking and domain history stay in **NextDNS** (witness owns the account). App-level policies stay in **Family Link**. This app adds only what those cannot: holding the slot, tamper resistance, and alerts.

**Platform:** Android only. iPhone cannot replicate the tamper-proof model (Apple forbids uninstall-blocking and slot-holding for a normal app) and stays on the documented **supervised NextDNS profile + Screen Time** route. Flutter is used for the UI; enforcement is Android-native Kotlin and does not port to iOS.

---

## 2. Roles (this app is the Android half of the mutual pair)

- **Protected user:** the friend, on whose Android phone the app runs.
- **Witness:** the other person (you), who receives this phone's alerts and **holds the witness PIN**. The PIN controls all settings, disabling, and uninstall-release; the protected user must never know it.
- The reverse direction (your iPhone) is handled by NextDNS + Screen Time, not this app.

---

## 3. Architecture

Clean split: **Flutter/Dart = UI + config + PIN**; **Kotlin (native) = enforcement + alerting**. The native `Reporter` interface is the seam for a future backend.

### 3.1 Flutter (Dart) — presentation & config
- **Setup wizard:** witness email, SMTP sender creds, NextDNS DoH URL, and set the **witness PIN**.
- **Status screen:** is protection active (VPN up, admin active)?
- **Settings** (PIN-gated) and **Release screen** (PIN-gated uninstall).
- Config in **EncryptedSharedPreferences**. PIN stored **salted-hashed**; raw PIN never persisted.

### 3.2 Kotlin (native) — enforcement, reached via MethodChannel
- **`AccountabilityVpnService`** (`VpnService`): a **DNS-only tunnel** — captures DNS, forwards to the NextDNS DoH endpoint, passes all other traffic through untouched. Holds the single VPN slot. `onRevoke()` → alert.
- **`AdminReceiver`** (`DeviceAdminReceiver`): blocks normal uninstall; `onDisabled()` → immediate alert.
- **`BootReceiver`** (`BOOT_COMPLETED`): restart the VpnService after reboot.
- **`Watchdog`** (WorkManager, ~15 min): verify VPN + admin active; restart/alert if not; emit a **daily "still protected" heartbeat** email.
- **`Reporter`** interface → **`EmailReporter`** (JavaMail/SMTP) for v1; **`HttpReporter`** (backend) later. Alerts send from native so they fire even as the app loses privileges.

### 3.3 Division of labor
- **NextDNS:** blocking + domain history (witness dashboard).
- **Family Link:** app-usage reports + app policies (block/time-limit).
- **This app:** holds the VPN slot (no bypass VPN) + tamper/uninstall resistance + alerts. It does **not** duplicate domain history into email — **alerts only**.

---

## 4. Enforcement flow

1. Boot/launch → `AccountabilityVpnService` establishes the tunnel, DNS pinned to NextDNS, slot occupied.
2. All DNS → NextDNS → blocked/allowed **and logged** (witness reads NextDNS).
3. User tries another VPN → cannot coexist; ours is revoked → `onRevoke()` → **"protection turned off" alert**.
4. User deactivates the admin in Settings → `onDisabled()` → **immediate alert**.
5. Watchdog + daily heartbeat catch anything silent.

---

## 5. Tamper model & release switch

- **Uninstall protection:** Device Admin active blocks the normal uninstall path.
- **Witness PIN gates** every setting change, disabling, and the uninstall-release. Set at setup, salted-hashed. Protected user never knows it.
- **Release (authorized uninstall):**
  1. Settings → **"Allow uninstall"** → enter witness PIN.
  2. Correct PIN → stop VpnService → deactivate Device Admin → "you may now uninstall."
  3. Wrong PIN → no-op; after N failures → **"release attempt" alert** to witness.
- **Dead-man's switch (three layers):**
  - **Immediate:** `onDisabled()` / `onRevoke()` alert before privileges fully drop.
  - **Watchdog (~15 min):** re-check + restart + alert.
  - **Daily heartbeat email:** its *absence* is the signal if the app is force-stopped and never reopened.

**Honest gap (kept explicit):** a force-stop can suspend WorkManager until next app-open or reboot; `BootReceiver` recovers on reboot and the missing heartbeat is the backstop. With Device Admin, deactivation is **detected, not prevented**. Guarantee = **"can't disable/uninstall unseen,"** not "physically impossible" — the tradeoff chosen when we picked Device Admin over Device Owner.

---

## 6. Config, custody & setup

- **Setup is done by the witness** (or with the witness present): v1 = **in-person or video-call**. Either person may type the **non-secret** fields (witness email, NextDNS DoH URL, SMTP sender creds); **only the witness enters the PIN**, out of the protected user's sight.
- **Remote PIN provisioning** (witness sets/resets the PIN from their own phone via a one-time code, never touching the device) is **deferred to v2** — it needs the backend/pairing layer.
- Config in EncryptedSharedPreferences. **Honest note:** the SMTP app password sits on the device; a rooted/determined user could extract it, but it's only the *sender* account (mint a dedicated Gmail). Low stakes.

---

## 7. Testing

- **Kotlin unit tests (JUnit, no device):** pure logic — PIN hash/verify, config validation, alert/heartbeat formatting, watchdog decision (is-active → action).
- **Dart widget tests:** setup wizard + status/release screens.
- **Manual/instrumented checklist:** VpnService starts + holds slot; a second VPN triggers a revoke alert; admin deactivation triggers an alert; reboot re-arms; release flow permits uninstall; SMTP-failure alerts queue and resend.

---

## 8. Error handling

- **VpnService fails to start** → retry + alert witness.
- **SMTP failure / no network** → **queue alerts** (WorkManager) and resend on reconnect; never drop an alert silently.
- **Wrong-PIN spam** → rate-limit + alert.

---

## 9. Known limitations (stated honestly)

- **Device Admin, not Device Owner:** disabling is detected + alerted, not prevented. (Device Owner would prevent it but needs factory-reset/ADB provisioning — declined for setup simplicity.)
- **Force-stop gap:** covered by reboot recovery + missing-heartbeat, not instantaneous.
- **iPhone not covered by this app** — supervised NextDNS + Screen Time instead (Apple limits).
- **SMTP secret on device** — low stakes (sender account only).
- **No content/search-term capture** — DNS-only; domain history via NextDNS, app usage via Family Link. (An Accessibility-based monitor for foreground titles is possible but deferred.)

---

## 10. Out of scope for v1

- iOS build.
- Backend + witness dashboard + remote PIN provisioning (the `HttpReporter` seam is left in place).
- Native app policies (block/time-box) and foreground-title reporting — Family Link covers app policy/usage for now.
- Device Owner provisioning.
- Own blocklist / packet-filtering VPN (NextDNS is the blocker).
