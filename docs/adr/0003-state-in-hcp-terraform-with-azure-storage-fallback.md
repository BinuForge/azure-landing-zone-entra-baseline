# ADR-0003: State in HCP Terraform, with Azure Storage as the fallback

- **Status:** Accepted
- **Date:** 2026-10-25

## Context

Terraform state holds resource IDs and configuration, and can hold secrets if code is careless. The
backend must provide locking, version history, and a way for one level to read another level's outputs.
Regulated financial services firms also ask *where* state is stored and who can read it.

## Decision

Use HCP Terraform (Free) for state, with these rules:

- No secrets in state: secrets are generated and kept in Key Vault, and write-only arguments are used
  where providers offer them.
- Levels read each other only through `tfe_outputs` (see ADR-0002).
- The managed resource count is tracked in `docs/cost.md`. The fallback is triggered before 400 of the
  500 free resources are used.

Azure Storage is the documented fallback.

## Consequences

| | HCP Terraform (chosen) | Azure Storage (fallback) |
|---|---|---|
| Locking and history | Built in | Blob lease locking; blob versioning and soft delete |
| Reading other levels | `tfe_outputs`, per-workspace allow-list | `terraform_remote_state`, Azure RBAC per container |
| Identity | HCP token (ADR-0002) | Entra ID with OIDC (`use_azuread_auth`); no storage keys |
| Data location | HashiCorp SaaS, United States region (HCP Europe exists; no APAC region) | Customer tenant, chosen region, private endpoint and customer-managed key possible |
| Extras | Private registry, dynamic credentials, run UI | None; build or buy them |
| Bootstrap | Organisation exists before any Azure resource | Storage account must exist before the first `init` (chicken and egg) |
| Cost | Free up to 500 managed resources | A few cents a month |

Revisit when any of these is true:
- a regulator or risk owner requires state to stay in-region or in-tenant;
- the managed resource count approaches 400;
- teams are needed and a paid tier is not funded.

## Alternatives considered

| Option | Why not |
|---|---|
| Local state | No locking, no history, no sharing. |
| Terraform Enterprise (self-hosted) | Solves data location; licence cost is out of scope for a lab. |
