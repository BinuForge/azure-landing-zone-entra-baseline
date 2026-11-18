# azure

| Level | Path | Contents |
|---|---|---|
| 0 | `level-0-org/` | Management groups. Custom roles and level identities are in `bootstrap/` (ADR-0012) |
| 1 | `level-1-governance/` | Subscriptions, policy baseline as data |
| 2 | `level-2-platform/` | Management, connectivity (hub and cost flags), DNS |
| 3 | `level-3-landingzones/` | Landing zone vending: corp-nonprod, corp-prod, sandbox. Designed only: its workspace exists, its folder does not yet (ADR-0004) |
| 3 | `level-3-aiservices/` | Shared AI services landing zone: Foundry, APIM gateway, prompt logs (ADR-0007) |
| 4 | `level-4-workloads/opsagent/` | Ops agent: the runner identity's read roles and the canary for threat model tests T-01 and T-09. Runs in HCP with dynamic credentials |

Levels 0 to 4 are deployed by `azure-l0.yml` to `azure-l4.yml` and torn down by `destroy.yml`.
