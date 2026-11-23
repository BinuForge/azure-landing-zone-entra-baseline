# Evidence

Each folder is one evidence pack: what was deployed, what the tests showed, and what was left after
teardown, collected from live Azure by the `evidence` workflow (ADR-0011). The environment is torn down
after each session to control cost, so these files are the record that it existed.

## Check a file yourself

Every file is attested by the workflow that produced it. The signature is in the Sigstore public
transparency log, so checking it does not depend on trusting this repository's owner:

```sh
gh attestation verify evidence/<pack>/<file> \
  --repo BinuForge/azure-landing-zone-entra-baseline \
  --signer-workflow BinuForge/azure-landing-zone-entra-baseline/.github/workflows/<workflow>
```

Use `evidence.yml`, or `gateway-tests.yml` for the `-gateway` packs.

Verification fails if a single byte has changed since the workflow attested it.

## What an attestation proves, and what it does not

- It proves the file was produced by the named workflow, in this repository, at a recorded commit and time.
- It does not prove the content is true. The workflow builds each file from Azure APIs with no manual
  step, and its code is public, so the claim is provenance, not audit.

## Redaction

Subscription and tenant IDs appear as `<subscription>` and `<tenant>`. Every other GUID becomes a stable
token such as `<guid-1>`, consistent within a pack. A pack is only attested after a scan finds no GUID,
IP address, tenant domain or email address left in it.

## Findings

Problems the tests found in the live environment, and how each was closed.

| Date | Found by | Finding | Fix | Proof |
|---|---|---|---|---|
| 2026-11-15 | GW-02, `gateway-tests` run 43701410635 | A human account held `Foundry User` at subscription scope, granted outside code before this build. It could have called the model directly, skipping the gateway's limits, kill switch and logs (threat model TM-06) | Role removed. The account stays as a recovery account: it can grant access, and holds none on the model | `2026-11-15-gateway-retest`, GW-02 |
| 2026-11-16 | Review of a plan failure (PR #42) | The prompt workspace was readable beyond the maintainer (ADR-0010). Reader, Role Based Access Control Administrator and Resource Policy Contributor all include `*/read`, which covers Log Analytics queries, and pipeline identities held them at the root, the subscription and the AI services group. Resource permissions were also on, so read on the Foundry account was enough, and level 3 could still delegate Log Analytics Reader there. Content logging was off, so the workspace held no prompts | Custom twins of the three roles without log reads (ADR-0012, decision 6); prompt workspace set to workspace permissions only; Log Analytics Reader delegable on the management group only | PR #43: bootstrap and level 3 tests |

| 2026-11-18 | Review of the runner's roles before the first agent run (PR #48) | Cost Management Reader and Log Analytics Reader both include `Microsoft.Support/*`, which opens and changes support requests: a write, held by an identity that reads attacker-influenced data | Custom twins without it (ADR-0012, decision 7) | PR #48: bootstrap tests; `agent-live-tests` run 44290489055, T-02a and T-02c |
| 2026-11-18 | Building T-13 (PR #49) | No AI gateway log had ever reached the ops workspace. APIM sends logs to an ingestion host outside the AzureMonitor service tag, and the subnet's deny rule dropped them, so threat model C-22 never held | The APIM subnet may reach Azure on 443 (ADR-0008) | PR #49; `agent-live-tests` run 44290489055, T-13a |
| 2026-11-18 | First live agent run | Prompt Shields did not block planted instructions that arrived in a tool result. The model reported them as suspicious and did not follow them, and the sanitiser removed the planted image | Threat model C-02 no longer relied on; the runner's own controls carry TM-01 | `agent-live-tests` run 44290489055, T-01a, T-01b and T-09 |
| 2026-11-23 | Conditional Access report-only review, before the subscription lapsed | CA004 (admins need phishing-resistant MFA) would have interrupted every admin sign-in since 2026-11-19: none used a phishing-resistant method. Enforcing it on the planned date would have locked out the daily admin, as a failed passkey prompt nearly did that morning | CA004 stays report-only until each admin has a device-bound passkey and the break-glass accounts have FIDO2 keys (ADR-0017 bar) | `2026-11-23-ca-report-only` (maintainer's record, not attested) |

The finding run was cancelled before its report job, so it has no signed pack; its job logs are the
record. GW-09 failed in the same run because the test expected the wrong refusal, not because of a gap:
Foundry checks role before network rules (PR #37).
