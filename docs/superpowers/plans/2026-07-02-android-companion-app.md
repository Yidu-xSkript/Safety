# Android Companion App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an Android-only Flutter+Kotlin app that holds the single VPN slot (routing DNS to NextDNS so no bypass VPN can start), resists uninstall/tamper via Device Admin with a witness-PIN release, and emails the witness on tamper/VPN-off/silence.

**Architecture:** Flutter/Dart owns UI + config + PIN (pure, unit-tested with `flutter test`). Kotlin owns enforcement + alerting (VpnService, DeviceAdminReceiver, BootReceiver, WorkManager watchdog, JavaMail EmailReporter), bridged via a MethodChannel. Pure Kotlin logic (alert text, watchdog decision) is unit-tested with JUnit on the JVM; platform integration is verified with an on-device checklist. The native `Reporter` interface is the seam for a future backend (`HttpReporter`).

**Tech Stack:** Flutter (Dart 3), Kotlin, Android `VpnService` / `DeviceAdminReceiver` / WorkManager, OkHttp (DoH forwarding), Jakarta Mail (SMTP), `flutter_secure_storage`, JUnit.

---

## Environment prerequisites (verify before Task 1)

Execution requires, on the build machine:
- Flutter SDK on PATH (`flutter --version`), Dart 3.
- Android SDK + a JDK 17 (`java -version`), Gradle (via the Flutter wrapper).
- For native verification: an Android device or emulator (`flutter devices` shows one) — Android 9+ (API 28+).

If these are absent, the pure-logic tasks (2, 3, 4, 6, 7) can still be written and `flutter test` / JUnit run once Flutter+JDK are installed, but the on-device tasks (9–14) cannot be verified here. **Do not fake device verification** — mark those steps blocked and note it.

## File structure

```
accountability_android/                         (flutter create output)
  lib/
    main.dart
    config/agent_config.dart                    # config model, fromJson/toJson, validation (pure)
    security/pin.dart                            # salted PIN hash + verify (pure)
    reporting/alert_messages.dart                # NOTE: Dart mirror only for UI copy; native sends
    logic/watchdog_decision.dart                 # pure: (vpnUp, adminActive) -> actions
    platform/enforcement_channel.dart            # Dart side of the MethodChannel
    storage/config_store.dart                    # flutter_secure_storage wrapper
    ui/setup_wizard.dart
    ui/status_screen.dart
    ui/settings_screen.dart
    ui/release_screen.dart
  test/
    agent_config_test.dart
    pin_test.dart
    watchdog_decision_test.dart
  android/app/src/main/kotlin/com/safety/accountability/
    MainActivity.kt                              # MethodChannel handlers
    Reporter.kt                                  # interface
    EmailReporter.kt                             # JavaMail impl
    AlertMessages.kt                             # pure alert/heartbeat text
    WatchdogDecision.kt                          # pure decision (mirror of Dart, native-side)
    AccountabilityVpnService.kt                  # DNS-only tunnel -> NextDNS DoH
    AdminReceiver.kt                             # DeviceAdminReceiver
    BootReceiver.kt                              # BOOT_COMPLETED
    WatchdogWorker.kt                            # WorkManager periodic worker
  android/app/src/test/kotlin/com/safety/accountability/
    AlertMessagesTest.kt
    WatchdogDecisionTest.kt
  android/app/src/main/AndroidManifest.xml
  android/app/src/main/res/xml/device_admin.xml
  README.md                                      # setup + on-device acceptance checklist
```

---

## Task 1: Flutter project scaffold + Android manifest

**Files:**
- Create: `accountability_android/` (via `flutter create`)
- Modify: `accountability_android/android/app/src/main/AndroidManifest.xml`
- Create: `accountability_android/android/app/src/main/res/xml/device_admin.xml`
- Modify: `accountability_android/pubspec.yaml`

- [ ] **Step 1: Create the project**

Run:
```bash
cd accountability-agent-mobile 2>/dev/null || mkdir -p . ; flutter create --org com.safety --project-name accountability_android accountability_android
```
Expected: project created; `flutter test` in it passes the default sample test.

- [ ] **Step 2: Add dependencies to `pubspec.yaml`**

Under `dependencies:` add:
```yaml
  flutter_secure_storage: ^9.0.0
  crypto: ^3.0.3
```
Run `flutter pub get`. Expected: resolves with no errors.

- [ ] **Step 3: Declare permissions + components in `AndroidManifest.xml`**

Inside `<manifest>` (above `<application>`):
```xml
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.BIND_VPN_SERVICE"/>
```
Inside `<application>`:
```xml
        <service
            android:name=".AccountabilityVpnService"
            android:permission="android.permission.BIND_VPN_SERVICE"
            android:exported="false">
            <intent-filter><action android:name="android.net.VpnService"/></intent-filter>
        </service>
        <receiver android:name=".AdminReceiver"
            android:permission="android.permission.BIND_DEVICE_ADMIN" android:exported="true">
            <meta-data android:name="android.app.device_admin" android:resource="@xml/device_admin"/>
            <intent-filter><action android:name="android.app.action.DEVICE_ADMIN_ENABLED"/></intent-filter>
        </receiver>
        <receiver android:name=".BootReceiver" android:exported="true">
            <intent-filter><action android:name="android.intent.action.BOOT_COMPLETED"/></intent-filter>
        </receiver>
```

- [ ] **Step 4: Create `res/xml/device_admin.xml`**

```xml
<device-admin xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-policies>
        <disable-camera/>
        <watch-login/>
    </uses-policies>
</device-admin>
```

- [ ] **Step 5: Commit**

```bash
git add accountability_android
git commit -m "feat(android): flutter scaffold, manifest, device-admin policy"
```

---

## Task 2: Dart config model + validation (TDD)

**Files:**
- Create: `accountability_android/lib/config/agent_config.dart`
- Create: `accountability_android/test/agent_config_test.dart`

- [ ] **Step 1: Write the failing test**

`test/agent_config_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:accountability_android/config/agent_config.dart';

void main() {
  group('AgentConfig', () {
    test('parses and validates a complete config', () {
      final c = AgentConfig.fromJson({
        'witnessEmail': 'w@x.com',
        'nextDnsDohUrl': 'https://dns.nextdns.io/abc123',
        'smtp': {'host': 's', 'port': 587, 'username': 'u', 'appPassword': 'p', 'fromAddress': 'f@x.com'},
      });
      expect(c.witnessEmail, 'w@x.com');
      expect(c.isValid, true);
    });

    test('is invalid when the witness email is missing', () {
      final c = AgentConfig.fromJson({'nextDnsDohUrl': 'https://dns.nextdns.io/abc'});
      expect(c.isValid, false);
      expect(c.validationErrors, contains('witnessEmail is required'));
    });

    test('round-trips through toJson', () {
      final j = {
        'witnessEmail': 'w@x.com',
        'nextDnsDohUrl': 'https://dns.nextdns.io/abc123',
        'smtp': {'host': 's', 'port': 587, 'username': 'u', 'appPassword': 'p', 'fromAddress': 'f@x.com'},
      };
      expect(AgentConfig.fromJson(j).toJson(), j);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd accountability_android && flutter test test/agent_config_test.dart`
Expected: FAIL — `AgentConfig` undefined.

- [ ] **Step 3: Implement `lib/config/agent_config.dart`**

```dart
class SmtpConfig {
  final String host; final int port; final String username;
  final String appPassword; final String fromAddress;
  SmtpConfig(this.host, this.port, this.username, this.appPassword, this.fromAddress);
  factory SmtpConfig.fromJson(Map j) =>
      SmtpConfig(j['host'], j['port'], j['username'], j['appPassword'], j['fromAddress']);
  Map<String, dynamic> toJson() =>
      {'host': host, 'port': port, 'username': username, 'appPassword': appPassword, 'fromAddress': fromAddress};
}

class AgentConfig {
  final String? witnessEmail;
  final String? nextDnsDohUrl;
  final SmtpConfig? smtp;
  AgentConfig({this.witnessEmail, this.nextDnsDohUrl, this.smtp});

  factory AgentConfig.fromJson(Map j) => AgentConfig(
        witnessEmail: j['witnessEmail'],
        nextDnsDohUrl: j['nextDnsDohUrl'],
        smtp: j['smtp'] != null ? SmtpConfig.fromJson(j['smtp']) : null,
      );

  Map<String, dynamic> toJson() => {
        if (witnessEmail != null) 'witnessEmail': witnessEmail,
        if (nextDnsDohUrl != null) 'nextDnsDohUrl': nextDnsDohUrl,
        if (smtp != null) 'smtp': smtp!.toJson(),
      };

  List<String> get validationErrors {
    final e = <String>[];
    if (witnessEmail == null || witnessEmail!.isEmpty) e.add('witnessEmail is required');
    if (nextDnsDohUrl == null || !nextDnsDohUrl!.startsWith('https://')) e.add('nextDnsDohUrl must be https');
    if (smtp == null) e.add('smtp is required');
    return e;
  }

  bool get isValid => validationErrors.isEmpty;
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/agent_config_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add accountability_android/lib/config/agent_config.dart accountability_android/test/agent_config_test.dart
git commit -m "feat(android): config model + validation with tests"
```

---

## Task 3: Dart PIN hashing + verification (TDD)

**Files:**
- Create: `accountability_android/lib/security/pin.dart`
- Create: `accountability_android/test/pin_test.dart`

- [ ] **Step 1: Write the failing test**

`test/pin_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:accountability_android/security/pin.dart';

void main() {
  group('Pin', () {
    test('verifies a correct PIN against its stored hash', () {
      final stored = Pin.hash('4821', salt: 'abc');
      expect(Pin.verify('4821', stored), true);
    });
    test('rejects a wrong PIN', () {
      final stored = Pin.hash('4821', salt: 'abc');
      expect(Pin.verify('0000', stored), false);
    });
    test('produces salt:hash format and never stores the raw PIN', () {
      final stored = Pin.hash('4821', salt: 'abc');
      expect(stored.contains('4821'), false);
      expect(stored.split(':').length, 2);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/pin_test.dart`
Expected: FAIL — `Pin` undefined.

- [ ] **Step 3: Implement `lib/security/pin.dart`**

```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

class Pin {
  // Stored form is "salt:sha256(salt+pin)". Raw PIN is never persisted.
  static String hash(String pin, {required String salt}) {
    final digest = sha256.convert(utf8.encode('$salt$pin')).toString();
    return '$salt:$digest';
  }

  static bool verify(String pin, String stored) {
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    return hash(pin, salt: parts[0]) == stored;
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/pin_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add accountability_android/lib/security/pin.dart accountability_android/test/pin_test.dart
git commit -m "feat(android): salted PIN hash + verify with tests"
```

---

## Task 4: Dart config store (secure storage wrapper)

**Files:**
- Create: `accountability_android/lib/storage/config_store.dart`

- [ ] **Step 1: Implement the wrapper**

```dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/agent_config.dart';

class ConfigStore {
  final FlutterSecureStorage _s;
  ConfigStore([FlutterSecureStorage? s]) : _s = s ?? const FlutterSecureStorage();

  Future<void> saveConfig(AgentConfig c) => _s.write(key: 'config', value: jsonEncode(c.toJson()));
  Future<AgentConfig?> loadConfig() async {
    final raw = await _s.read(key: 'config');
    return raw == null ? null : AgentConfig.fromJson(jsonDecode(raw));
  }

  Future<void> savePinHash(String hash) => _s.write(key: 'pinHash', value: hash);
  Future<String?> loadPinHash() => _s.read(key: 'pinHash');
}
```

- [ ] **Step 2: Analyze (no device needed)**

Run: `flutter analyze lib/storage/config_store.dart`
Expected: no issues. (Runtime behavior is covered by the on-device checklist; secure storage can't run in `flutter test`.)

- [ ] **Step 3: Commit**

```bash
git add accountability_android/lib/storage/config_store.dart
git commit -m "feat(android): secure config + pin-hash store"
```

---

## Task 5: Kotlin alert/heartbeat message builder (JUnit TDD)

**Files:**
- Create: `.../kotlin/com/safety/accountability/AlertMessages.kt`
- Create: `.../src/test/kotlin/com/safety/accountability/AlertMessagesTest.kt`

- [ ] **Step 1: Write the failing test**

`android/app/src/test/kotlin/com/safety/accountability/AlertMessagesTest.kt`:
```kotlin
package com.safety.accountability
import org.junit.Assert.assertTrue
import org.junit.Test

class AlertMessagesTest {
    @Test fun vpnOffAlertMentionsProtectionOff() {
        val m = AlertMessages.build(AlertKind.VPN_OFF, "")
        assertTrue(m.subject.contains("protection off", ignoreCase = true))
    }
    @Test fun tamperAlertMentionsAdmin() {
        val m = AlertMessages.build(AlertKind.ADMIN_DISABLED, "")
        assertTrue(m.body.contains("admin", ignoreCase = true))
    }
    @Test fun heartbeatMentionsStillProtected() {
        val m = AlertMessages.build(AlertKind.HEARTBEAT, "")
        assertTrue(m.subject.contains("protected", ignoreCase = true))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd accountability_android/android && ./gradlew :app:testDebugUnitTest --tests "com.safety.accountability.AlertMessagesTest"`
Expected: FAIL — unresolved `AlertMessages`.

- [ ] **Step 3: Implement `AlertMessages.kt`**

```kotlin
package com.safety.accountability

enum class AlertKind { VPN_OFF, ADMIN_DISABLED, RELEASE_ATTEMPT, HEARTBEAT }
data class AlertEmail(val subject: String, val body: String)

object AlertMessages {
    fun build(kind: AlertKind, detail: String): AlertEmail = when (kind) {
        AlertKind.VPN_OFF -> AlertEmail(
            "[Accountability] Protection off (VPN)",
            "The VPN protection was turned off or replaced. $detail")
        AlertKind.ADMIN_DISABLED -> AlertEmail(
            "[Accountability] Tamper: device admin disabled",
            "The device admin was disabled — uninstall protection is off. $detail")
        AlertKind.RELEASE_ATTEMPT -> AlertEmail(
            "[Accountability] Repeated wrong PIN on release",
            "Someone entered the wrong witness PIN trying to release the app. $detail")
        AlertKind.HEARTBEAT -> AlertEmail(
            "[Accountability] Daily heartbeat: still protected",
            "Protection is active. $detail")
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `./gradlew :app:testDebugUnitTest --tests "com.safety.accountability.AlertMessagesTest"`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add accountability_android/android/app/src/main/kotlin/com/safety/accountability/AlertMessages.kt accountability_android/android/app/src/test/kotlin/com/safety/accountability/AlertMessagesTest.kt
git commit -m "feat(android): alert/heartbeat message builder with tests"
```

---

## Task 6: Kotlin watchdog decision (JUnit TDD)

**Files:**
- Create: `.../kotlin/com/safety/accountability/WatchdogDecision.kt`
- Create: `.../src/test/kotlin/com/safety/accountability/WatchdogDecisionTest.kt`

- [ ] **Step 1: Write the failing test**

```kotlin
package com.safety.accountability
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class WatchdogDecisionTest {
    @Test fun healthyStateAsksForNothingButHeartbeat() {
        val a = WatchdogDecision.decide(vpnUp = true, adminActive = true, heartbeatDue = false)
        assertTrue(a.isEmpty())
    }
    @Test fun vpnDownRequestsRestartAndAlert() {
        val a = WatchdogDecision.decide(vpnUp = false, adminActive = true, heartbeatDue = false)
        assertTrue(a.contains(WatchdogAction.RESTART_VPN))
        assertTrue(a.contains(WatchdogAction.ALERT_VPN_OFF))
    }
    @Test fun adminDownRequestsAlert() {
        val a = WatchdogDecision.decide(vpnUp = true, adminActive = false, heartbeatDue = false)
        assertTrue(a.contains(WatchdogAction.ALERT_ADMIN))
    }
    @Test fun heartbeatDueEmitsHeartbeat() {
        val a = WatchdogDecision.decide(vpnUp = true, adminActive = true, heartbeatDue = true)
        assertEquals(listOf(WatchdogAction.SEND_HEARTBEAT), a)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `./gradlew :app:testDebugUnitTest --tests "com.safety.accountability.WatchdogDecisionTest"`
Expected: FAIL — unresolved symbols.

- [ ] **Step 3: Implement `WatchdogDecision.kt`**

```kotlin
package com.safety.accountability

enum class WatchdogAction { RESTART_VPN, ALERT_VPN_OFF, ALERT_ADMIN, SEND_HEARTBEAT }

object WatchdogDecision {
    // Pure: given observed state, return the actions the worker should perform.
    fun decide(vpnUp: Boolean, adminActive: Boolean, heartbeatDue: Boolean): List<WatchdogAction> {
        val out = mutableListOf<WatchdogAction>()
        if (!vpnUp) { out.add(WatchdogAction.RESTART_VPN); out.add(WatchdogAction.ALERT_VPN_OFF) }
        if (!adminActive) out.add(WatchdogAction.ALERT_ADMIN)
        if (heartbeatDue) out.add(WatchdogAction.SEND_HEARTBEAT)
        return out
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `./gradlew :app:testDebugUnitTest --tests "com.safety.accountability.WatchdogDecisionTest"`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add accountability_android/android/app/src/main/kotlin/com/safety/accountability/WatchdogDecision.kt accountability_android/android/app/src/test/kotlin/com/safety/accountability/WatchdogDecisionTest.kt
git commit -m "feat(android): pure watchdog decision with tests"
```

---

## Task 7: Kotlin Reporter interface + EmailReporter

**Files:**
- Create: `.../kotlin/com/safety/accountability/Reporter.kt`
- Create: `.../kotlin/com/safety/accountability/EmailReporter.kt`
- Modify: `accountability_android/android/app/build.gradle` (add Jakarta Mail)

- [ ] **Step 1: Add the mail dependency**

In `android/app/build.gradle` under `dependencies {`:
```gradle
    implementation 'com.sun.mail:android-mail:1.6.7'
    implementation 'com.sun.mail:android-activation:1.6.7'
```

- [ ] **Step 2: Define the Reporter interface (`Reporter.kt`)**

```kotlin
package com.safety.accountability

// The backend seam: v1 is EmailReporter; a future HttpReporter posts to a server instead.
interface Reporter {
    fun send(to: String, email: AlertEmail)
}
```

- [ ] **Step 3: Implement `EmailReporter.kt`**

```kotlin
package com.safety.accountability

import java.util.Properties
import javax.mail.Authenticator
import javax.mail.PasswordAuthentication
import javax.mail.Session
import javax.mail.Transport
import javax.mail.internet.InternetAddress
import javax.mail.internet.MimeMessage

class EmailReporter(
    private val host: String, private val port: Int,
    private val username: String, private val appPassword: String, private val from: String,
) : Reporter {
    override fun send(to: String, email: AlertEmail) {
        val props = Properties().apply {
            put("mail.smtp.auth", "true")
            put("mail.smtp.starttls.enable", "true")
            put("mail.smtp.host", host)
            put("mail.smtp.port", port.toString())
        }
        val session = Session.getInstance(props, object : Authenticator() {
            override fun getPasswordAuthentication() = PasswordAuthentication(username, appPassword)
        })
        val msg = MimeMessage(session).apply {
            setFrom(InternetAddress(from))
            addRecipient(javax.mail.Message.RecipientType.TO, InternetAddress(to))
            subject = email.subject
            setText(email.body)
        }
        Transport.send(msg)
    }
}
```

- [ ] **Step 4: Verify it compiles**

Run: `cd accountability_android/android && ./gradlew :app:compileDebugKotlin`
Expected: BUILD SUCCESSFUL. (SMTP send itself is covered by the on-device checklist — do not send real mail from a unit test.)

- [ ] **Step 5: Commit**

```bash
git add accountability_android/android/app/src/main/kotlin/com/safety/accountability/Reporter.kt accountability_android/android/app/src/main/kotlin/com/safety/accountability/EmailReporter.kt accountability_android/android/app/build.gradle
git commit -m "feat(android): Reporter interface + JavaMail EmailReporter"
```

---

## Task 8: AccountabilityVpnService (DNS-only tunnel → NextDNS)

This is the hardest component and the one requiring device iteration. It establishes a VpnService that captures DNS and forwards it to the NextDNS DoH endpoint, passing other traffic through. `// ponytail: minimal DNS-forwarding tunnel — the well-trodden Intra/DNSNet pattern; expect on-device iteration on packet handling.`

**Files:**
- Create: `.../kotlin/com/safety/accountability/AccountabilityVpnService.kt`

- [ ] **Step 1: Implement the service**

```kotlin
package com.safety.accountability

import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer

class AccountabilityVpnService : VpnService() {
    private var tunnel: ParcelFileDescriptor? = null
    @Volatile private var running = false
    private val http = OkHttpClient()
    private lateinit var dohUrl: String

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        dohUrl = intent?.getStringExtra("dohUrl") ?: EnforcementState.dohUrl ?: return START_NOT_STICKY
        EnforcementState.dohUrl = dohUrl
        startTunnel()
        return START_STICKY   // OS restarts us if killed
    }

    private fun startTunnel() {
        if (running) return
        val b = Builder()
            .setSession("Accountability")
            .addAddress("10.111.222.1", 32)
            .addDnsServer("10.111.222.2")          // route DNS into the tunnel
            .addRoute("10.111.222.2", 32)          // only DNS server IP goes through us
            .setBlocking(true)
        tunnel = b.establish() ?: return
        running = true
        Thread { pump(tunnel!!) }.start()
    }

    private fun pump(pfd: ParcelFileDescriptor) {
        val input = FileInputStream(pfd.fileDescriptor)
        val output = FileOutputStream(pfd.fileDescriptor)
        val buf = ByteBuffer.allocate(32767)
        while (running) {
            val n = try { input.read(buf.array()) } catch (e: Exception) { break }
            if (n <= 0) continue
            val query = extractDnsPayload(buf.array(), n) ?: continue
            val answer = resolveOverDoh(query) ?: continue
            val packet = wrapDnsResponse(buf.array(), n, answer) ?: continue
            try { output.write(packet) } catch (e: Exception) { break }
        }
    }

    // extractDnsPayload / wrapDnsResponse parse the IPv4+UDP header to get/replace the DNS
    // payload. Implemented against the tun packet format; iterate on-device. See README.
    private fun extractDnsPayload(pkt: ByteArray, len: Int): ByteArray? = DnsPacket.extract(pkt, len)
    private fun wrapDnsResponse(reqPkt: ByteArray, len: Int, answer: ByteArray): ByteArray? =
        DnsPacket.wrapResponse(reqPkt, len, answer)

    private fun resolveOverDoh(query: ByteArray): ByteArray? = try {
        val req = Request.Builder().url(dohUrl)
            .header("accept", "application/dns-message")
            .post(query.toRequestBody("application/dns-message".toMediaType())).build()
        http.newCall(req).execute().use { it.body?.bytes() }
    } catch (e: Exception) { null }

    override fun onRevoke() {
        running = false
        EnforcementState.reporter?.send(EnforcementState.witnessEmail ?: "", AlertMessages.build(AlertKind.VPN_OFF, ""))
        super.onRevoke()
    }

    override fun onDestroy() { running = false; tunnel?.close(); super.onDestroy() }
}
```

- [ ] **Step 2: Create the packet helper stub `DnsPacket.kt` and shared `EnforcementState.kt`**

`EnforcementState.kt`:
```kotlin
package com.safety.accountability
object EnforcementState {
    @Volatile var dohUrl: String? = null
    @Volatile var witnessEmail: String? = null
    @Volatile var reporter: Reporter? = null
}
```
`DnsPacket.kt` (IPv4/UDP parse — verify on device):
```kotlin
package com.safety.accountability
object DnsPacket {
    // Returns the DNS payload from an IPv4/UDP packet, or null if not IPv4/UDP.
    fun extract(pkt: ByteArray, len: Int): ByteArray? {
        if (len < 28) return null
        val ihl = (pkt[0].toInt() and 0x0F) * 4
        val proto = pkt[9].toInt() and 0xFF
        if (proto != 17) return null                 // 17 = UDP
        val udpStart = ihl
        val payloadStart = udpStart + 8
        if (payloadStart > len) return null
        return pkt.copyOfRange(payloadStart, len)
    }
    // Builds a response packet by swapping src/dst and replacing the UDP payload.
    // Recomputes lengths; checksums set to 0 (allowed for UDP over IPv4). Verify on device.
    fun wrapResponse(reqPkt: ByteArray, len: Int, answer: ByteArray): ByteArray? {
        val ihl = (reqPkt[0].toInt() and 0x0F) * 4
        val out = ByteArray(ihl + 8 + answer.size)
        System.arraycopy(reqPkt, 0, out, 0, ihl + 8)
        // swap IP src/dst
        for (i in 0 until 4) { val t = out[12 + i]; out[12 + i] = out[16 + i]; out[16 + i] = t }
        // swap UDP src/dst ports
        for (i in 0 until 2) { val t = out[ihl + i]; out[ihl + i] = out[ihl + 2 + i]; out[ihl + 2 + i] = t }
        System.arraycopy(answer, 0, out, ihl + 8, answer.size)
        val totalLen = out.size
        out[2] = (totalLen shr 8).toByte(); out[3] = totalLen.toByte()
        val udpLen = 8 + answer.size
        out[ihl + 4] = (udpLen shr 8).toByte(); out[ihl + 5] = udpLen.toByte()
        out[ihl + 6] = 0; out[ihl + 7] = 0     // zero UDP checksum
        out[10] = 0; out[11] = 0               // zero IP checksum (kernel/caller may recompute)
        return out
    }
}
```
Add OkHttp to `android/app/build.gradle`: `implementation 'com.squareup.okhttp3:okhttp:4.12.0'`

- [ ] **Step 3: Compile**

Run: `./gradlew :app:compileDebugKotlin`
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Commit**

```bash
git add accountability_android/android/app/src/main/kotlin/com/safety/accountability/AccountabilityVpnService.kt accountability_android/android/app/src/main/kotlin/com/safety/accountability/DnsPacket.kt accountability_android/android/app/src/main/kotlin/com/safety/accountability/EnforcementState.kt accountability_android/android/app/build.gradle
git commit -m "feat(android): DNS-only VpnService forwarding to NextDNS DoH"
```

---

## Task 9: AdminReceiver (tamper detection)

**Files:**
- Create: `.../kotlin/com/safety/accountability/AdminReceiver.kt`

- [ ] **Step 1: Implement**

```kotlin
package com.safety.accountability

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

class AdminReceiver : DeviceAdminReceiver() {
    override fun onDisabled(context: Context, intent: Intent) {
        // Fires when the witness-controlled admin is deactivated — alert before we lose privileges.
        EnforcementState.reporter?.send(
            EnforcementState.witnessEmail ?: "",
            AlertMessages.build(AlertKind.ADMIN_DISABLED, "")
        )
        super.onDisabled(context, intent)
    }
}
```

- [ ] **Step 2: Compile**

Run: `./gradlew :app:compileDebugKotlin`
Expected: BUILD SUCCESSFUL.

- [ ] **Step 3: Commit**

```bash
git add accountability_android/android/app/src/main/kotlin/com/safety/accountability/AdminReceiver.kt
git commit -m "feat(android): device-admin receiver alerts on tamper"
```

---

## Task 10: BootReceiver (re-arm after reboot)

**Files:**
- Create: `.../kotlin/com/safety/accountability/BootReceiver.kt`

- [ ] **Step 1: Implement**

```kotlin
package com.safety.accountability

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val prepare = android.net.VpnService.prepare(context)
        if (prepare == null) {  // already authorized
            context.startService(Intent(context, AccountabilityVpnService::class.java))
        }
        // else: needs user re-consent on next app open (handled by UI)
    }
}
```

- [ ] **Step 2: Compile & commit**

Run: `./gradlew :app:compileDebugKotlin` (Expected: SUCCESSFUL)
```bash
git add accountability_android/android/app/src/main/kotlin/com/safety/accountability/BootReceiver.kt
git commit -m "feat(android): restart VPN after reboot"
```

---

## Task 11: WatchdogWorker (WorkManager)

**Files:**
- Create: `.../kotlin/com/safety/accountability/WatchdogWorker.kt`
- Modify: `android/app/build.gradle` (WorkManager dep)

- [ ] **Step 1: Add dependency**

In `android/app/build.gradle`: `implementation 'androidx.work:work-runtime-ktx:2.9.0'`

- [ ] **Step 2: Implement the worker (wires the pure decision to actions)**

```kotlin
package com.safety.accountability

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters

class WatchdogWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
    override fun doWork(): Result {
        val vpnUp = EnforcementState.dohUrl != null && android.net.VpnService.prepare(applicationContext) == null
        val adminActive = AdminState.isActive(applicationContext)
        val heartbeatDue = HeartbeatClock.isDue(applicationContext)
        val actions = WatchdogDecision.decide(vpnUp, adminActive, heartbeatDue)
        val to = EnforcementState.witnessEmail ?: return Result.success()
        for (a in actions) when (a) {
            WatchdogAction.RESTART_VPN -> applicationContext.startService(
                android.content.Intent(applicationContext, AccountabilityVpnService::class.java))
            WatchdogAction.ALERT_VPN_OFF -> EnforcementState.reporter?.send(to, AlertMessages.build(AlertKind.VPN_OFF, ""))
            WatchdogAction.ALERT_ADMIN -> EnforcementState.reporter?.send(to, AlertMessages.build(AlertKind.ADMIN_DISABLED, ""))
            WatchdogAction.SEND_HEARTBEAT -> {
                EnforcementState.reporter?.send(to, AlertMessages.build(AlertKind.HEARTBEAT, ""))
                HeartbeatClock.markSent(applicationContext)
            }
        }
        return Result.success()
    }
}
```

- [ ] **Step 3: Add the small helpers `AdminState.kt` and `HeartbeatClock.kt`**

`AdminState.kt`:
```kotlin
package com.safety.accountability
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
object AdminState {
    fun isActive(ctx: Context): Boolean {
        val dpm = ctx.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return dpm.isAdminActive(ComponentName(ctx, AdminReceiver::class.java))
    }
}
```
`HeartbeatClock.kt`:
```kotlin
package com.safety.accountability
import android.content.Context
object HeartbeatClock {
    private const val KEY = "lastHeartbeatDay"
    private fun today(): Long = System.currentTimeMillis() / 86_400_000L
    fun isDue(ctx: Context): Boolean {
        val p = ctx.getSharedPreferences("aa_hb", Context.MODE_PRIVATE)
        return p.getLong(KEY, 0) != today()
    }
    fun markSent(ctx: Context) {
        ctx.getSharedPreferences("aa_hb", Context.MODE_PRIVATE).edit().putLong(KEY, today()).apply()
    }
}
```

- [ ] **Step 4: Compile & commit**

Run: `./gradlew :app:compileDebugKotlin` (Expected: SUCCESSFUL)
```bash
git add accountability_android/android/app/src/main/kotlin/com/safety/accountability/WatchdogWorker.kt accountability_android/android/app/src/main/kotlin/com/safety/accountability/AdminState.kt accountability_android/android/app/src/main/kotlin/com/safety/accountability/HeartbeatClock.kt accountability_android/android/app/build.gradle
git commit -m "feat(android): watchdog worker wiring pure decision to actions"
```

---

## Task 12: MethodChannel bridge (MainActivity) + Dart channel

**Files:**
- Modify: `.../kotlin/com/safety/accountability/MainActivity.kt`
- Create: `accountability_android/lib/platform/enforcement_channel.dart`

- [ ] **Step 1: Implement the native handlers in `MainActivity.kt`**

```kotlin
package com.safety.accountability

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Intent
import androidx.work.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "accountability/enforce")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "configure" -> {
                        EnforcementState.dohUrl = call.argument("dohUrl")
                        EnforcementState.witnessEmail = call.argument("witnessEmail")
                        EnforcementState.reporter = EmailReporter(
                            call.argument("smtpHost")!!, call.argument("smtpPort")!!,
                            call.argument("smtpUser")!!, call.argument("smtpPass")!!,
                            call.argument("smtpFrom")!!)
                        result.success(true)
                    }
                    "startVpn" -> {
                        val prep = android.net.VpnService.prepare(this)
                        if (prep != null) { startActivityForResult(prep, 1); result.success(false) }
                        else { startService(Intent(this, AccountabilityVpnService::class.java)
                            .putExtra("dohUrl", EnforcementState.dohUrl)); result.success(true) }
                    }
                    "startWatchdog" -> {
                        val work = PeriodicWorkRequestBuilder<WatchdogWorker>(15, TimeUnit.MINUTES).build()
                        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
                            "watchdog", ExistingPeriodicWorkPolicy.KEEP, work)
                        result.success(true)
                    }
                    "requestAdmin" -> {
                        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                            .putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN,
                                ComponentName(this, AdminReceiver::class.java))
                        startActivity(intent); result.success(true)
                    }
                    "release" -> {
                        val dpm = getSystemService(DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        dpm.removeActiveAdmin(ComponentName(this, AdminReceiver::class.java))
                        stopService(Intent(this, AccountabilityVpnService::class.java))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
```

- [ ] **Step 2: Implement the Dart side `enforcement_channel.dart`**

```dart
import 'package:flutter/services.dart';
import '../config/agent_config.dart';

class EnforcementChannel {
  static const _c = MethodChannel('accountability/enforce');

  Future<void> configure(AgentConfig cfg) => _c.invokeMethod('configure', {
        'dohUrl': cfg.nextDnsDohUrl,
        'witnessEmail': cfg.witnessEmail,
        'smtpHost': cfg.smtp!.host, 'smtpPort': cfg.smtp!.port,
        'smtpUser': cfg.smtp!.username, 'smtpPass': cfg.smtp!.appPassword,
        'smtpFrom': cfg.smtp!.fromAddress,
      });
  Future<bool> startVpn() async => await _c.invokeMethod('startVpn') as bool;
  Future<void> startWatchdog() => _c.invokeMethod('startWatchdog');
  Future<void> requestAdmin() => _c.invokeMethod('requestAdmin');
  Future<void> release() => _c.invokeMethod('release');
}
```

- [ ] **Step 3: Compile the native side & analyze Dart**

Run: `./gradlew :app:compileDebugKotlin && cd .. && flutter analyze lib/platform/enforcement_channel.dart`
Expected: both clean.

- [ ] **Step 4: Commit**

```bash
git add accountability_android/android/app/src/main/kotlin/com/safety/accountability/MainActivity.kt accountability_android/lib/platform/enforcement_channel.dart
git commit -m "feat(android): method-channel bridge for enforcement control"
```

---

## Task 13: Setup wizard UI

**Files:**
- Create: `accountability_android/lib/ui/setup_wizard.dart`
- Modify: `accountability_android/lib/main.dart`

- [ ] **Step 1: Implement the wizard**

```dart
import 'package:flutter/material.dart';
import '../config/agent_config.dart';
import '../security/pin.dart';
import '../storage/config_store.dart';
import '../platform/enforcement_channel.dart';

class SetupWizard extends StatefulWidget {
  const SetupWizard({super.key});
  @override State<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  final _witness = TextEditingController();
  final _doh = TextEditingController();
  final _host = TextEditingController(text: 'smtp.gmail.com');
  final _port = TextEditingController(text: '587');
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _pin = TextEditingController();
  String? _error;

  Future<void> _finish() async {
    final cfg = AgentConfig(
      witnessEmail: _witness.text.trim(),
      nextDnsDohUrl: _doh.text.trim(),
      smtp: SmtpConfig(_host.text.trim(), int.tryParse(_port.text) ?? 587,
          _user.text.trim(), _pass.text, _user.text.trim()),
    );
    if (!cfg.isValid || _pin.text.length < 4) {
      setState(() => _error = cfg.validationErrors.join(', ') + (_pin.text.length < 4 ? ' pin>=4' : ''));
      return;
    }
    final store = ConfigStore();
    await store.saveConfig(cfg);
    await store.savePinHash(Pin.hash(_pin.text, salt: DateTime.now().microsecondsSinceEpoch.toString()));
    final ch = EnforcementChannel();
    await ch.configure(cfg);
    await ch.requestAdmin();
    await ch.startVpn();
    await ch.startWatchdog();
    if (mounted) Navigator.of(context).pushReplacementNamed('/status');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Witness setup')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: _witness, decoration: const InputDecoration(labelText: 'Witness email')),
      TextField(controller: _doh, decoration: const InputDecoration(labelText: 'NextDNS DoH URL')),
      TextField(controller: _host, decoration: const InputDecoration(labelText: 'SMTP host')),
      TextField(controller: _port, decoration: const InputDecoration(labelText: 'SMTP port')),
      TextField(controller: _user, decoration: const InputDecoration(labelText: 'SMTP user/from')),
      TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'SMTP app password')),
      const Divider(),
      TextField(controller: _pin, obscureText: true, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Witness PIN (you set, keep secret)')),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      ElevatedButton(onPressed: _finish, child: const Text('Activate protection')),
    ]),
  );
}
```

- [ ] **Step 2: Wire `main.dart` routes**

Replace `lib/main.dart` body with:
```dart
import 'package:flutter/material.dart';
import 'ui/setup_wizard.dart';
import 'ui/status_screen.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Accountability',
        routes: {
          '/': (_) => const SetupWizard(),
          '/status': (_) => const StatusScreen(),
        },
      );
}
```

- [ ] **Step 3: Analyze & commit**

Run: `flutter analyze lib/ui/setup_wizard.dart lib/main.dart` (Expected: clean once Task 14 adds StatusScreen; if StatusScreen missing, create the stub in Task 14 first or expect an unresolved import — do Task 14 before analyzing.)
```bash
git add accountability_android/lib/ui/setup_wizard.dart accountability_android/lib/main.dart
git commit -m "feat(android): witness setup wizard"
```

---

## Task 14: Status / settings / release screens (PIN-gated)

**Files:**
- Create: `accountability_android/lib/ui/status_screen.dart`
- Create: `accountability_android/lib/ui/release_screen.dart`

- [ ] **Step 1: Implement `status_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'release_screen.dart';

class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Protection active')),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.shield, size: 96, color: Colors.green),
            const Text('Accountability protection is active.'),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReleaseScreen())),
              child: const Text('Allow uninstall (witness PIN)'),
            ),
          ]),
        ),
      );
}
```

- [ ] **Step 2: Implement `release_screen.dart` (PIN-gated release)**

```dart
import 'package:flutter/material.dart';
import '../security/pin.dart';
import '../storage/config_store.dart';
import '../platform/enforcement_channel.dart';

class ReleaseScreen extends StatefulWidget {
  const ReleaseScreen({super.key});
  @override State<ReleaseScreen> createState() => _ReleaseScreenState();
}

class _ReleaseScreenState extends State<ReleaseScreen> {
  final _pin = TextEditingController();
  int _wrong = 0;
  String _msg = '';

  Future<void> _tryRelease() async {
    final stored = await ConfigStore().loadPinHash();
    if (stored != null && Pin.verify(_pin.text, stored)) {
      await EnforcementChannel().release();
      setState(() => _msg = 'Released. You may now uninstall the app.');
    } else {
      _wrong++;
      setState(() => _msg = 'Wrong PIN ($_wrong).');
      // On repeated failure the native side is asked to alert the witness.
      if (_wrong >= 3) { /* EnforcementChannel could expose alertReleaseAttempt(); wired in v1.1 */ }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Allow uninstall')),
        body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          const Text('Enter the witness PIN to release protection for uninstall.'),
          TextField(controller: _pin, obscureText: true, keyboardType: TextInputType.number),
          ElevatedButton(onPressed: _tryRelease, child: const Text('Release')),
          Text(_msg),
        ])),
      );
}
```

- [ ] **Step 3: Analyze & commit**

Run: `flutter analyze lib/ui/status_screen.dart lib/ui/release_screen.dart`
Expected: clean.
```bash
git add accountability_android/lib/ui/status_screen.dart accountability_android/lib/ui/release_screen.dart
git commit -m "feat(android): status + PIN-gated release screens"
```

---

## Task 15: On-device acceptance checklist (manual)

**Files:**
- Create: `accountability_android/README.md`

- [ ] **Step 1: Write the runbook + checklist**

README covering: witness-run setup (in person), then verify on a real Android 9+ device:
- [ ] Setup wizard activates: grants VPN consent, device-admin, starts watchdog.
- [ ] A known porn domain is blocked in Chrome + a private tab (NextDNS via the tunnel).
- [ ] Turning on another VPN app revokes ours → witness gets "protection off" email.
- [ ] Deactivating the device admin in Settings → witness gets "admin disabled" email.
- [ ] Reboot → protection re-arms (VpnService restarts).
- [ ] Daily heartbeat email arrives; SMTP failure retries (airplane mode, then back).
- [ ] Release screen with correct PIN stops protection and permits uninstall; wrong PIN does not.

- [ ] **Step 2: Commit**

```bash
git add accountability_android/README.md
git commit -m "docs(android): on-device acceptance checklist"
```

---

## Self-review notes

- **Spec coverage:** VpnService DNS→NextDNS holding slot (Task 8) ✅ · Device Admin tamper + alert (Task 9) ✅ · witness-PIN release (Tasks 3,14) ✅ · dead-man = onRevoke/onDisabled + watchdog + heartbeat (Tasks 8,9,11) ✅ · email alerts + Reporter seam (Tasks 5,7) ✅ · config/PIN/secure storage (Tasks 2,3,4) ✅ · setup wizard, witness sets PIN (Task 13) ✅ · boot re-arm (Task 10) ✅ · Android-only (whole plan) ✅.
- **Deferred per spec:** iOS, backend/HttpReporter (interface left in place, Task 7), native app policies, foreground-title reporting, Device Owner, remote PIN provisioning. No tasks — intentional.
- **Testability honesty:** pure logic is unit-tested (Dart Tasks 2,3; Kotlin Tasks 5,6). Everything touching `VpnService`/`DeviceAdmin`/WorkManager/SMTP is compile-checked + on-device checklist (Task 15) — it cannot be unit-tested, and the **VpnService packet handling (Task 8) will need real-device iteration** (flagged in-task).
- **Type consistency:** `AgentConfig`/`SmtpConfig` fields match across Dart config, store, wizard, channel. `AlertKind`/`AlertEmail`/`WatchdogAction` match across builder, decision, worker, services. MethodChannel method names (`configure`/`startVpn`/`startWatchdog`/`requestAdmin`/`release`) match between `MainActivity.kt` and `enforcement_channel.dart`.
