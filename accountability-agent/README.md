# Accountability Agent

The Accountability Agent is a tamper-resistant Windows agent that reports device activity to a witness by email, kills unapproved VPN connections, and enforces per-application usage policies (block, time-box, report-only). It is designed for a mutual-accountability arrangement in which two people hold custody over each other's configuration and recovery credentials, so neither can silently disable their own protections.

## Custody

| Item | Who holds it |
| --- | --- |
| Witness name | TODO |
| Witness email | TODO |
| Windows admin password holder | TODO |
| Phone passcode holder | TODO |
| NextDNS config ID | TODO |

## Setup (Task 0 — manual)

- **Create the OTHER person's NextDNS account.** Each user creates the NextDNS account for the other person (not their own), so control of the config stays with the witness. On that account enable: the **Porn** category, the **Proxies & VPNs** blocklist, and **SafeSearch**.
- **Apply NextDNS on each Windows PC.** Configure the PC to use the witness-controlled NextDNS config, and record into the agent config: the **DoH template** URL plus the **two plain-DNS IPs** (`nextDnsIps`).
- **Lock phones.**
  - **iPhone:** install the NextDNS configuration profile and enable **Screen Time** locked with a passcode held by the witness.
  - **Android:** set **Private DNS** to the NextDNS hostname and configure **Digital Wellbeing**.

## Install (per PC, run by the witness/admin)

```powershell
# 1. Copy the example config and fill in real values (SMTP app password, witness email,
#    approved VPN endpoint(s), NextDNS IPs, and the appPolicies you both agreed on).
Copy-Item .\config\agent-config.example.json $env:TEMP\real-config.json
#    ...edit $env:TEMP\real-config.json...

# 2. Install (elevated PowerShell). Registers the SYSTEM enforcer + user-session monitor.
.\install\install.ps1 -ConfigPath $env:TEMP\real-config.json

# 3. Start now (or reboot / log off + on).
Start-ScheduledTask -TaskName AccountabilityEnforcer
Start-ScheduledTask -TaskName AccountabilityMonitor
```

The daily user account must be a **standard (non-admin) user**; only the witness holds the admin password. To remove: `.\install\uninstall.ps1` (admin).

## Acceptance checklist

Run these as the **standard (non-admin) user** after install:

- [ ] A known porn test domain is blocked in a normal window **and** in incognito (NextDNS layer).
- [ ] The blocked attempt appears in the witness's NextDNS dashboard.
- [ ] Connect an **unapproved** VPN → it is disabled within `vpnPollSeconds`; witness gets the "Unapproved VPN killed" email.
- [ ] Connect the **approved** VPN (the endpoint in `approvedVpnIps`) → it stays up, no email.
- [ ] Stop the monitor task (admin `Stop-ScheduledTask` to simulate; a standard user cannot) → within `heartbeatStaleSeconds` the witness gets the "Tamper / silence" email.
- [ ] As the standard user, try `Unregister-ScheduledTask AccountabilityEnforcer` → **access denied**.
- [ ] Wait one `reportIntervalMinutes` → witness receives the activity report with window titles; the spool clears afterward.

App-policy checks:

- [ ] A `block` app's domain fails to load and shows the managed entry in the hosts file (`# BEGIN AccountabilityAgent` block).
- [ ] A `time-box` app becomes blocked after its daily limit is exceeded; the `usage-<app>-<date>.txt` counter resets the next day.
- [ ] A `report-only` app stays usable and appears in the witness report + NextDNS log.
- [ ] The standard user cannot edit the config to change a policy (the `C:\ProgramData\AccountabilityAgent` dir is admin-only).

## Mutual setup (two people)

Repeat the entire install on the **second person's** PC with their own config — their witness is you, their `approvedVpnIps`, their NextDNS IPs. Each person is the protected user for their own machine and the witness for the other's.
