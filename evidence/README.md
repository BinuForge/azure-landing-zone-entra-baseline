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
  --signer-workflow BinuForge/azure-landing-zone-entra-baseline/.github/workflows/evidence.yml
```

Verification fails if a single byte has changed since the workflow attested it.

## What an attestation proves, and what it does not

- It proves the file was produced by `evidence.yml`, in this repository, at a recorded commit and time.
- It does not prove the content is true. The workflow builds each file from Azure APIs with no manual
  step, and its code is public, so the claim is provenance, not audit.

## Redaction

Subscription and tenant IDs appear as `<subscription>` and `<tenant>`. Every other GUID becomes a stable
token such as `<guid-1>`, consistent within a pack. A pack is only attested after a scan finds no GUID,
IP address, tenant domain or email address left in it.
