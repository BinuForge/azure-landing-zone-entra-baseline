# ADR-0013: Levels read lower levels through tfe_outputs

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

- Each workspace declares which lower workspaces it reads in `tfc/workspaces.yaml`, and the `tfc/` root
  turns that into each workspace's state-sharing allow-list (ADR-0002).
- A level can learn about a lower level in two ways: read that workspace's outputs with the `tfe_outputs`
  data source, or look the resource up in Azure by its conventional name.
- Level 1 looks up level 0's management groups by name, which was written before this decision.
- Bootstrap is not a level. Its state is Tier 0 and is not shared with any workspace.

## Options considered

| Option | For | Against |
|---|---|---|
| `tfe_outputs` from the lower workspace | The dependency is explicit and the same as the declared `reads` list; the lower level decides what it exposes; the allow-list enforces it on a paid tier and for remote runs | Each level needs the `tfe` provider and the HCP token; a lower level must be applied before a higher level can plan |
| Azure lookup by name | Proves the resource exists; no HCP dependency | Couples levels to names instead of a published interface; the `reads` list becomes documentation only |

## Decision

A level reads another level only through `tfe_outputs`, from a workspace in its `reads` list. Outputs
are the level's published interface: a higher level never depends on a lower level's internals.

Resources that bootstrap creates, such as the level resource groups, are looked up in Azure by name,
because bootstrap's state is never shared.

Level 1's lookups of level 0's management groups move to `tfe_outputs` in their own change.

`tfe_outputs` was chosen because it keeps the dependency graph real: the graph in
`docs/architecture/dependency-graph.md`, the allow-list and the code all say the same thing.

## Risks accepted

| Risk | Why it is accepted | Mitigation, or how we would notice |
|---|---|---|
| On Free, local runs use the owners token, which can read every state | Teams are not available on Free (ADR-0002) | The allow-list is enforced for remote runs and on any paid tier |
| A higher level cannot plan until the lower level is applied | That ordering is true of the infrastructure anyway | Levels are delivered in dependency order, one pull request each |
| A lower level renames or removes an output | Outputs are an interface | The higher level's plan fails, before anything changes |

## Consequences

- Easier: what each level depends on is visible in its outputs and its `reads` list, and tested.
- Harder: every level that reads another needs the `tfe` provider pinned and locked.
- At bank scale this is the normal pattern, with per-level team tokens so the allow-list is enforced.
