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

The finding run was cancelled before its report job, so it has no signed pack; its job logs are the
record. GW-09 failed in the same run because the test expected the wrong refusal, not because of a gap:
Foundry checks role before network rules (PR #37).
