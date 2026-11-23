# Runbooks

Step-by-step instructions for each job, roughly in the order you will need them. New to the repository?
Read [how it works](../how-it-works.md) first.

| I want to | Runbook |
|---|---|
| Set up my machine | [Local setup](local-setup.md) |
| Deploy my own copy from scratch | [Quickstart](../../QUICKSTART.md) |
| Run bootstrap, the Entra bootstrap, pipeline secrets or the HCP root | [Bootstrap](bootstrap.md) |
| Apply Entra level 0 privileged, or set up PIM | [Entra privileged](entra-privileged.md) |
| Check before applying tenant defaults (SMS off, consent off) | [Entra governance](entra-governance.md) |
| Move a Conditional Access policy from report-only to on | [Conditional Access](entra-conditional-access.md) |
| Turn the AI gateway on or off, call it, or use the kill switch | [AI gateway](ai-gateway.md) |
| Collect an evidence pack and bring it into the repository | [Evidence](evidence.md) |
| Tear down the cost-bearing levels | [Destroy](destroy.md) |
| Move this repository to a new tenant and subscription | [Rebuild in a new tenant](rebuild-in-new-tenant.md) |
| Put tenant settings back after someone changed them outside code | [Entra recovery](entra-recovery.md) |
| Check or change the repository's own settings | [Repository governance](repo-governance.md) |

Every runbook's commands are bash. In PowerShell, set variables with `$env:NAME = "value"` instead of
`export` ([bootstrap](bootstrap.md#prerequisites)).
