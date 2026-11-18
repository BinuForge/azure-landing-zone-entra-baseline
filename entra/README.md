# entra

| Level | Path | Contents |
|---|---|---|
| 0 | `level-0-org/` | Persona groups, owned by the level's apply identity |
| 0 | `level-0-privileged/` | Tier 0: the restricted administrative unit, Conditional Access exclusion groups, custom roles, role-assignable groups, PIM. CI plans it; the maintainer applies it |
| 1 | `level-1-governance/` | Authorisation, consent, authentication methods, cross-tenant defaults |
| 1 | `level-1-conditionalaccess/` | Named locations, authentication strengths, Conditional Access baseline |
| - | `break-glass/` | README and checks only; the accounts are created by hand |

Each workspace has its own plan and apply identity, and each holds only the Microsoft Graph permissions
its workspace needs (ADR-0016, `bootstrap/rbac.yaml`). No pipeline can assign directory roles, grant
permissions or add credentials. Entra's diagnostic settings are in bootstrap, which sends the logs to a
security workspace only the maintainer reads.

Not built yet: only `break-glass/` exists. The levels follow the pipeline identities.
