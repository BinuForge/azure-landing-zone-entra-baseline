# ADR-0015: The ops agent's report store is write-only, identity-only and outlives teardowns

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

- The ops agent writes full reports about the lab estate. Those reports hold names, topology and costs,
  so they are not for a public repository (threat model C-12, TM-08).
- The lab is torn down after each session. Reports must survive that, or the record of what the agent
  said is lost with the estate.
- The runner is a GitHub-hosted job on the internet, signed in with its own workload identity.
- A compromised or steered run is the threat the store must survive: it should not be able to read
  earlier reports, or remove or rewrite what it wrote before.

## Options considered

| Option | For | Against |
|---|---|---|
| Blob container in bootstrap, write-only role for the runner, public endpoint with Entra-only access | Survives teardowns; a bad run can add but not read or erase; no network path to build for a runner on the internet | The endpoint is reachable from the internet, so identity is the only boundary |
| The same, behind a private endpoint | No public endpoint | GitHub-hosted runners cannot reach it; needs self-hosted runners in a VNet that teardowns would remove |
| Storage Blob Data Contributor for the runner | Built-in role | The runner could read, list and delete every report |
| Reports as workflow artifacts | Nothing to build | Downloadable by anyone on a public repository |

## Decision

A storage account in the locked bootstrap resource group, with one private container. Shared keys are
off, so account and service SAS cannot exist; local users and anonymous access are off. Versioning and
30-day soft delete are on, and the account is geo-zone redundant, because the reports are the record.

The runner holds a custom role with two data actions, blob write and blob add, on that container only.
It cannot read, list or delete. An overwrite keeps the earlier version, and deleting versions is an
action it does not hold. The maintainer holds Storage Blob Data Reader on the container. Bootstrap
creates both, because the store outlives the levels.

The public endpoint stays, because GitHub-hosted runners are on the internet; the same reasoning as the
gateway (ADR-0008). Checkov's network findings on the account are suppressed inline, citing this ADR.

## Risks accepted

| Risk | Why it is accepted | Mitigation, or how we would notice |
|---|---|---|
| The endpoint is reachable from the internet | Every request needs an Entra token with a data role; no key exists | Test T-02 checks the runner's roles; the account refuses shared keys by setting |
| A bad run can add misleading reports | It cannot remove or rewrite earlier ones | Versioning; every report names its run ID (C-22) |
| No access logs for the store | They would go to the ops workspace, which teardowns remove | Bank target below |

## Consequences

- Easier: one place for every report, readable only by the maintainer, kept across sessions.
- Harder: the runner cannot read a previous report to compare runs; a comparison would need a separate,
  read-only identity.
- At a bank: a private endpoint and self-hosted runners in a VNet, storage logs to the SIEM, a
  time-based immutability policy on the container, and readers as a PIM-eligible group.
