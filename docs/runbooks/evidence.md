# Evidence

How an evidence pack gets from live Azure into `evidence/` (ADR-0011).

## Why a person carries it in

A pull request opened by a workflow does not trigger other workflows, so the required PR gates would
never run on it and the ruleset would block the merge. Instead the workflow attests each file, and a
person brings the files in through a normal pull request. The attestation binds each file's hash to the
workflow run, so who commits it does not matter: if one byte changes, verification fails.

## Steps

1. After a deploy or test session, run Actions, `evidence`, with a label such as `2026-11-19-aiservices`.
   The run fails without attesting anything if the redaction scan finds an identifier.
2. Note the run ID from the run's URL, then locally, from the repository root on an up-to-date `main`:

   ```sh
   bash .github/scripts/pull-evidence.sh <run-id> <label>
   ```

   This creates branch `evidence/<label>`, downloads the pack, verifies every file's attestation against
   `evidence.yml`, and stages it.
3. Read the files, commit with `docs(evidence): add <label>`, push and open a pull request.

Artifacts are kept for 90 days, so bring a pack in well within that.

## When to collect

| Moment | Label suffix | Shows |
|---|---|---|
| After a level is deployed and tested | the level, for example `aiservices` | What exists, who can change it, cost so far |
| After teardown | `teardown` | `resources.json` empty apart from bootstrap, `leftovers.json` clean |
