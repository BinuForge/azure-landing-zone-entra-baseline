# modules

Small local modules, used only where an Azure Verified Module does not fit. Each is published to the
HCP Terraform private registry by a git tag of the form `azure/<module>/<semver>`, after its tests pass.

| Module | Used by | What |
|---|---|---|
| `github-pipeline-identity` | `entra/bootstrap` | An app registration that trusts one GitHub environment, and that environment with its branch rule, reviewer, variables and identifier secrets |

`github-pipeline-identity` is used by path, not from the registry: only person-run roots use it, and a
change to it is reviewed with the root that calls it. Azure levels still use azurerm or azapi directly.
