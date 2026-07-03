# Accountability — Android Companion App

Android-only Flutter+Kotlin app for the accountability system. It **holds the single Android VPN slot** (routing DNS to NextDNS, so no bypass VPN can start), resists uninstall/tamper via **Device Admin** with a **witness-PIN release**, and **emails the witness** on VPN-off / tamper / silence. Blocking + domain history stay in NextDNS; app-usage policy stays in Family Link. This app adds only what those can't.

This is the Android half of the mutual pair: your friend's phone runs this app, and **you (the witness) hold the PIN**.

## Architecture

- **Flutter/Dart** — UI, config, PIN (unit-tested: `flutter test`).
- **Kotlin** — enforcement + alerting: `AccountabilityVpnService` (DNS→NextDNS), `AdminReceiver` (tamper), `BootReceiver` (re-arm), `WatchdogWorker` (WorkManager), `EmailReporter` (JavaMail). The `Reporter` interface is the seam for a future backend (`HttpReporter`).
- Pure Kotlin logic (`AlertMessages`, `WatchdogDecision`) is unit-tested with JUnit (`./gradlew :app:testDebugUnitTest`).

## Build notes

- Requires **JDK 17+**. If PATH has an older JDK, `android/gradle.properties` sets `org.gradle.java.home` to Android Studio's bundled JBR (JDK 21) — **machine-specific**; adjust on another build machine.
- The scaffold uses `build.gradle.kts` (Kotlin DSL).
- Native component classes live in package `com.safety.accountability`; the manifest references them fully-qualified (the app namespace is `com.safety.accountability_android`).

## Setup (witness, in person)

You meet up, take your friend's phone, and:
1. Install the app (`flutter build apk --release` → sideload, or from a store later).
2. In the **setup wizard**, enter: witness email (yours), NextDNS DoH URL (from the NextDNS "Setup" tab), SMTP sender creds (a dedicated Gmail + app password), and **set the witness PIN yourself, out of his sight**.
3. Tap **Activate protection** — grant the VPN consent prompt and the device-admin prompt.

Custody: **you** keep the PIN and the SMTP account. He never sees the PIN.

## Uninstalling (authorized release)

App → **Allow uninstall** → enter the **witness PIN** → protection stops and the device admin is removed → Android permits a normal uninstall. Without the PIN, it can't be cleanly removed; disabling the admin in Settings fires a tamper email to you.

## On-device acceptance checklist

Behavioral verification needs a real Android 9+ device or emulator (`flutter devices`). Unit tests and compiles pass without one; these do NOT:

- [ ] Setup wizard activates: VPN consent granted, device-admin granted, watchdog scheduled.
- [ ] A known porn domain is blocked in Chrome **and** an incognito tab (NextDNS via the tunnel).
- [ ] Turning on another VPN app revokes ours → witness gets the "Protection off (VPN)" email.
- [ ] Deactivating the device admin in Settings → witness gets the "device admin disabled" email.
- [ ] Reboot → protection re-arms (VpnService restarts).
- [ ] Daily heartbeat email arrives; on SMTP failure (airplane mode, then back) the alert is retried, not dropped.
- [ ] Release screen: correct PIN stops protection and permits uninstall; wrong PIN does not.

## Known limitations

- **Device Admin (not Device Owner):** disabling is *detected + alerted*, not prevented. Upgrade to Device Owner (factory-reset/ADB provisioning) for hard prevention.
- **Force-stop gap:** WorkManager may pause until next app-open or reboot; `BootReceiver` + the missing daily heartbeat are the backstops.
- **DNS packet handling** in `AccountabilityVpnService` is the component most likely to need on-device iteration.
- **SMTP secret on device** — low stakes (sender account only); use a dedicated Gmail.
- No search-term/URL capture (DNS-only); no VPN kill on the (unsupported) iPhone side.
