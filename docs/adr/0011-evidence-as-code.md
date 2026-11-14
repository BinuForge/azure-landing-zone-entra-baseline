# ADR-0011: Evidence as code

- **Status:** Accepted
- **Date:** 2026-11-14

## Context

- The lab is deployed in short sessions and destroyed afterwards to control cost (ADR-0004), so the
  running environment cannot be shown later.
- GitHub Actions logs and artifacts are deleted after a retention period, at most 90 days for a public
  repository. See
  [artifact and log retention](https://docs.github.com/en/organizations/managing-organization-settings/configuring-the-retention-period-for-github-actions-artifacts-and-logs-in-your-organization).
- Screenshots are easy to fake and hard to check.
- GitHub artifact attestations sign a file with the identity of the workflow run that produced it. For
  public repositories the signature is recorded in the Sigstore public transparency log, and anyone can
  check it with `gh attestation verify`. See
  [artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations).
  Private repositories need GitHub Enterprise for this.

## Options considered

| Option | For | Against |
|---|---|---|
| Workflow-generated evidence, attested and committed to `evidence/` | Permanent, checkable, made from live Azure with no manual step | An attestation proves origin, not that the content is true |
| Screenshots and notes | Quick | Cannot be checked; easy to fake |
| Leave the environment running | Anyone can look | Continuous cost, against ADR-0004 |

## Decision

Each deploy, test and destroy cycle runs an evidence workflow that collects, from live Azure:

- an apply summary with resource types and counts;
- the results of every threat model test (T-01 to T-15) that applies;
- a Resource Graph snapshot before destroy, and the empty result after;
- the session's cost;
- the ops agent's report on the estate.

Identifiers are redacted and every file is scanned (T-08) before it is attested and committed to
`evidence/<date>-<unit>/` through a pull request. Each entry in `controls.yaml` names its evidence
path, and CI fails if a named path does not exist.

Attested evidence was chosen because it can be checked by anyone after the environment is gone, without
trusting the maintainer.

## Risks accepted

| Risk | Why it is accepted | Mitigation, or how we would notice |
|---|---|---|
| An attestation shows which workflow made a file, not that the file is accurate | The workflow builds each file from Azure with no manual edit | Workflow code is public and reviewed; the claim is stated as provenance, not audit |
| Redaction misses an identifier and it becomes public | Patterns cover GUIDs, IP ranges and the tenant domain | T-08 scan blocks the commit; anything missed is removed and the identifier reviewed |
| Attestations depend on the repository being public | It goes public before the first apply | Without it, evidence is still committed, just unsigned |

## Consequences

- Easier: every claim in the README can point at a dated, signed file.
- Harder: each deployable unit also needs its evidence steps, written with it.
- At a bank: the same idea is continuous control monitoring, with evidence collected automatically into
  a GRC tool instead of a folder.
