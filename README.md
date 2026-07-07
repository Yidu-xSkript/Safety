# Accountability Blocker

A porn blocker with **accountability built in**. It blocks adult content on Windows and Android, and makes any *attempt* to reach it — even in incognito or over a VPN — visible to a trusted **witness** by email. The block stops the easy path; the accountability layer catches the rest and reports it.

The model is not an unbreakable wall. It's a room where nothing can be done unseen. A determined person with time and admin rights can defeat any single layer — the point is to make slipping **deliberate and hard**, and to make sure the witness is **told** when it's tried.

> This is a tool, not treatment. It supports recovery; it doesn't replace a counselor, a support group, or professional help.

---

## How it works — three layers

| Layer | What it does | Where |
|-------|--------------|-------|
| **1. NextDNS** | Blocks + logs porn at the DNS level — below the browser, so incognito can't hide it. Free. | All devices |
| **2. The apps** | A Windows agent and an Android app **enforce** the block, resist tampering/uninstall, and **email the witness** on every attempt, tamper, or bypass. | Windows + Android |
| **3. Alerts** | Instant porn-attempt emails, tamper alerts, hourly activity digests, and a daily "still protected" heartbeat. | Email |

**Two roles:**
- **The Witness** — holds every secret (NextDNS login, PINs, passwords, the alert email account). Works from a laptop browser + inbox. Receives every alert.
- **The Protected** — the person whose devices run the blocking. They never see the PINs or the sending email account.

The witness must be a *different person* than the protected user. If the protected user holds their own secrets, every layer becomes honor-system.

---

## Repository layout

```
accountability-agent/     Windows agent (PowerShell) — installer, enforcer, tests
  install/                install.ps1 / uninstall.ps1
  config/                 agent-config.example.json  (copy → agent-config.json)
  src/                    the agent modules + enforcer loop
  README.md, MOBILE-SETUP.md
accountability_android/    Android app (Flutter + Kotlin)
docs/                     design spec + build plans
```

Your real config (`*-config.json`) is git-ignored and never committed — only the `*.example.json` template is tracked. Keep your secrets out of git.

---

## Prerequisites

Have these ready before you start (about 15 minutes at a laptop):

1. A **Google account** to be the witness.
2. A **dedicated Gmail** for *sending* alerts, with a **Gmail app password** (see below). Keep it separate from your personal mail.
3. A **NextDNS account** (free) at [my.nextdns.io](https://my.nextdns.io).
4. To build the Android app: [Flutter](https://docs.flutter.dev/get-started/install) installed. To run the Windows agent: Windows 10/11 with PowerShell 5.1+ (built in).

---

## Step 1 — Create a Gmail app password (for the alert emails)

The apps send alerts over SMTP using a Gmail **app password** — a 16-character token, *not* your normal Google password. You need 2-Step Verification on first.

1. Go to [myaccount.google.com](https://myaccount.google.com) → **Security**.
2. Turn on **2-Step Verification** if it isn't already (required for app passwords).
3. Go to **App passwords** (search "app passwords" in the settings search bar, or visit [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords)).
4. Name it (e.g. "Accountability") and click **Create**.
5. Copy the **16-character password** it shows (it looks like `abcd efgh ijkl mnop`). This is what you paste into the app/agent config as the SMTP password. **Paste it — don't retype it.**

Use this dedicated Gmail as **both** the SMTP username and the "from" address. The witness email (where alerts are *received*) can be any address, including your normal one.

---

## Step 2 — Set up NextDNS (the blocker)

This single layer blocks porn on every device and browser, incognito included. Set it up first; the phone and PC both point at it.

1. Create/open your profile at [my.nextdns.io](https://my.nextdns.io). Note the short **profile ID** in the URL (6 characters, e.g. `a1b2c3`).
2. **Parental Control** → turn on **Block Porn** (add Gambling/Dating if you want).
3. Turn on **SafeSearch** (forces safe results on Google/Bing/DuckDuckGo).
4. **Settings → Logs** → **enable logging**. *Without logs, the attempt emails and activity digests will be empty.*
5. From the **Setup** tab and **Account** page, copy these three:

   | Value | Where | Used by |
   |-------|-------|---------|
   | **DoH URL** — `https://dns.nextdns.io/<profileID>` | Setup tab | App + PC |
   | **Private-DNS host** — `<profileID>.dns.nextdns.io` | Setup tab (Android/Linux) | Phone |
   | **API key** | Account → API | Attempt emails + digests |

   > ⚠️ The **API key** (Account → API) is **not** the same as the "linked IP" secret shown on the Setup page. Using the linked-IP secret as the API key makes the log fetch silently return nothing.

---

## Step 3 — Windows PC (the agent)

Run in an **elevated PowerShell** (Run as administrator), on the protected user's PC.

```powershell
cd path\to\accountability-agent
# 1. Create your real config from the template and fill it in (see reference below)
Copy-Item .\config\agent-config.example.json .\config\agent-config.json
notepad .\config\agent-config.json

# 2. Install. It will prompt you to set an uninstall password that YOU (the witness) keep.
.\install\install.ps1 -ConfigPath .\config\agent-config.json

# 3. Verify the whole install end-to-end
.\verify.ps1
```

Then:
- Make sure the PC resolves DNS through **NextDNS** (the NextDNS desktop app or the DoH profile).
- **The real lock:** make the protected user's daily Windows account a **standard user** and keep the **administrator password** yourself. A standard user can't stop the SYSTEM service or edit the hosts file.

See `accountability-agent/README.md` for module details.

---

## Step 4 — Android phone (the app)

Do this in person, on the protected user's phone.

**Build the APK** (on your machine):
```bash
cd accountability_android
flutter pub get
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

**On the phone:**
1. **Private DNS** — Settings → Network & internet → **Private DNS** → *Provider hostname* → paste `<profileID>.dns.nextdns.io`. **This alone blocks porn system-wide, incognito included.**
2. Copy `app-release.apk` to the phone, tap it, allow "install unknown apps" once.
3. Open the app's **setup wizard** and fill it in *yourself*: witness email, DoH URL, the dedicated Gmail + app password, the NextDNS **API key**, and **you type the 6-digit PIN** (out of his sight — it's the key that stops uninstall/release). Paste the passwords/keys.
4. Tap the **battery / "run in background"** button and allow it — required, or reports stop when the phone idles.
5. Grant **Usage access** (for the hourly app-usage report).
6. Tap **Send test email & activate**. It sends a real test email and only activates if it arrives — so you know alerting works before you leave. Then grant the VPN + device-admin prompts.
7. Confirm the phone browses normally **and** a porn site is blocked before handing it back.

### Samsung phones — required extra steps

Samsung's **Device Care** kills background apps even after the battery exemption. Do all three or the hourly reports stop:

1. **Never sleeping apps** — Settings → **Battery and device care** → **Battery** → **Background usage limits** → **Never sleeping apps** → **＋** → add the app. Make sure it's **not** under "Sleeping/Deep sleeping apps". *(This is the one that matters.)*
2. Turn **off** "Put unused apps to sleep" and "Auto-disable unused apps" (same screen).
3. **Lock it in Recents** — open Recents → tap the app's icon → **Keep open / Lock this app**.

(Menu names are One UI 6/7; older versions differ slightly.) If reports still drop, disable **Adaptive battery** as a last resort.

---

## Config reference (`agent-config.json`)

Copied from `agent-config.example.json`. Secrets go here; this file is git-ignored.

| Field | Meaning |
|-------|---------|
| `witnessEmail` | Where alerts are **sent**. |
| `nextDnsApiKey` / `nextDnsProfileId` | From NextDNS **Account → API** and the profile URL. Enable attempt emails + digests. |
| `pornBlocklistUrl` / `pornBlocklistMaxDomains` | Hosts-format blocklist the Windows agent loads into the hosts file, capped for sanity. |
| `approvedVpnIps` | VPN gateway IPs to **allow** (e.g. a required work VPN). Any other VPN is killed + reported. |
| `appPolicies[]` | Per-app rules: `block`, `time-box` (daily minute cap), or `report-only`. |
| `reportIntervalMinutes` / `heartbeatStaleSeconds` | Report cadence and how long silence goes before the dead-man alert. |
| `smtp.host/port/username/appPassword/fromAddress` | Your dedicated Gmail + **app password** (Step 1). |

---

## What the witness is emailed

| If the protected user… | You get |
|------------------------|---------|
| Reaches a porn site (blocked or not) | "Adult site attempted" — instantly |
| Turns off the VPN / installs a bypass VPN | "Protection off" |
| Disables device admin / tries to uninstall | "Tamper" |
| Enters the wrong PIN repeatedly | "Release attempt" |
| Edits the hosts file or DNS on the PC | "Tamper" |
| Does nothing | An hourly activity digest + a daily "still protected" heartbeat |

**Silence is also a signal** — a missing heartbeat means something is off.

---

## Honest limitations

- **Friction, not a cage.** Every layer can be defeated by someone with enough time and admin access. The strength is in the layers *together*, and in the trust behind them.
- **iPhone** allows no monitoring agent — iOS accountability is DNS-log-only (no companion app here).
- **Full-tunnel VPN** hides traffic from NextDNS while active; prefer split-tunnel for any allowed work VPN.
- Android exposes *which* app was used and for how long — **not** what was done inside it.

---

## License

No license is granted by default — add one (e.g. MIT) before others build on it. Nothing here is affiliated with NextDNS or Google.
