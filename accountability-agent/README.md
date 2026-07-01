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

## Acceptance checklist
