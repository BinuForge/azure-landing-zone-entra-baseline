# Conditional Access report-only results, collected 2026-11-23

What the eight report-only policies (ADR-0017) would have done to real sign-ins since they were created
on 2026-11-19, collected before the subscription lapsed and the security workspace became unreadable. Counts per policy and outcome only: no
user, IP address, device or application.

**Not attested.** The `evidence` workflow's identity cannot read the security workspace, by design
(ADR-0016: only the maintainer reads Entra's logs). The maintainer ran the queries below on 2026-11-23
and committed the output unchanged. Treat it as a maintainer's record, not a signed pack.

## Results

Outcomes: `success` the sign-in already met the policy, `interrupted` it would have been prompted or
blocked, `notapplied` the policy's conditions did not match.

| Policy | Interactive sign-ins | Non-interactive sign-ins |
|---|---|---|
| `CA001-Global-BlockLegacyAuth` | notapplied 28 | notapplied 231 |
| `CA002-Global-BlockDeviceCodeFlow` | notapplied 28 | notapplied 231 |
| `CA003-Global-BlockUntrustedCountries` | notapplied 28 | notapplied 231 |
| `CA004-Admins-RequirePhishingResistantMfa` | interrupted 28 | interrupted 231 |
| `CA005-Internals-RequireMfa` | interrupted 8, success 20 | interrupted 7, success 224 |
| `CA006-Guests-RequireMfa` | interrupted 6, notapplied 20, success 2 | interrupted 7, notapplied 172, success 52 |
| `CA007-Global-RiskySignInRequireMfa` | notapplied 28 | notapplied 231 |
| `CA008-Global-HighUserRiskRequirePasswordChange` | notapplied 28 | notapplied 231 |

The tenant has four users: the daily admin, the recovery account and the two break-glass accounts.
The earliest record is 2026-11-20 (non-interactive) and 2026-11-22 (interactive); the per-row times are in
the JSON files. Pipeline identities sign in as service principals, in other tables, and are not shown.

## Reading it

- **CA004 is not ready to enforce.** It would have interrupted every admin sign-in in the window: none
  used a phishing-resistant method. Passkeys here are device-bound only (ADR-0018), and the daily admin's
  passkey prompt failed on 2026-11-23. Before enforcement, each admin
  registers a device-bound passkey (Microsoft Authenticator or a FIDO2 key), and the break-glass accounts
  get their FIDO2 keys ([open items](../../entra/break-glass/README.md#open-items)).
- **CA005 and CA006 interruptions** all fall between 22:45 and 00:53 UTC on 2026-11-22 and 23, when
  the daily admin could not complete a passkey prompt and used the recovery account. Every other sign-in already met them.
- **CA001, CA002, CA003, CA007 and CA008 matched nothing**: no legacy authentication, device code flow,
  sign-in from outside the trusted countries, or medium or high sign-in risk.
- **Identity Protection** raised 4 low-risk `suspiciousAuthAppApproval` detections in the same hour,
  now dismissed ([`risk-events.json`](risk-events.json)). Low is below CA007's medium threshold.

## Queries

Run against the security workspace (`lab-log-security-prd-ae`), once per table:

```kusto
SigninLogs   // and AADNonInteractiveUserSignInLogs
| where TimeGenerated > datetime(2026-11-19)
| mv-expand cap = todynamic(tostring(ConditionalAccessPolicies))
| extend policy = tostring(cap.displayName), outcome = tostring(cap.result)
| where outcome startswith "reportOnly"
| summarize sign_ins = count(), from_utc = min(TimeGenerated), to_utc = max(TimeGenerated) by policy, outcome
```

```kusto
AADUserRiskEvents
| summarize events = count(), latest_utc = max(TimeGenerated) by RiskEventType, RiskLevel, RiskState, DetectionTimingType
```
