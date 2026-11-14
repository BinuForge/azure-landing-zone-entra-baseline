# ADR-0007: AI services as a shared landing zone

- **Status:** Accepted
- **Date:** 2026-11-14

## Context

- The first AI consumer is the ops agent (`docs/security/threat-model-ai.md`). More consumers are
  expected, each needing models, guardrails, quota, private networking and logging.
- A Foundry account holds many projects, so one account can serve several consumers while settings such
  as network access, local authentication and diagnostics are set once on the account.
- Guardrails, model allowlists and logging rules are security controls. If each workload sets its own,
  they drift.
- Level 3 landing zone vending is deferred (ADR-0004), so this is the first level 3 workspace built.

## Options considered

| Option | For | Against |
|---|---|---|
| Shared AI services landing zone at level 3, consumed by level 4 workloads | Guardrails, network and logging set once; one place to apply the kill switch | Shared blast radius; one consumer can exhaust quota for others |
| Foundry inside each level 4 workload | Teams fully independent | Every team re-implements the controls, and they drift |
| AI services inside the level 2 platform | Fewer workspaces | Couples the core platform to AI quota and preview features |

## Decision

Build a shared AI services landing zone as workspace `lab-azure-l3-aiservices-prd`. It reads the
governance, management, connectivity and DNS levels. Consumers are level 4 workspaces that each get a
Foundry project and an APIM product, and read the landing zone's outputs.

The shared option was chosen because the controls in the threat model only work if they are set in one
place and cannot be skipped by a consumer.

## Risks accepted

| Risk | Why it is accepted | Mitigation, or how we would notice |
|---|---|---|
| One consumer exhausts quota for all | One consumer exists today | Per-caller token limits at APIM (threat model C-18) |
| A misconfiguration affects every consumer | Changes go through PR gates and a saved plan | Drift detection (C-25) and policy (C-24) |
| The platform team becomes a bottleneck for new consumers | Onboarding is a YAML entry and a PR | Documented onboarding steps when a second consumer arrives |

## Consequences

- Easier: a new AI consumer inherits private networking, guardrails, limits and logging.
- Harder: changes to the landing zone affect every consumer, so they need more care in review.
- Revisit if a consumer needs a different residency or guardrail baseline, which would justify a second
  account.
