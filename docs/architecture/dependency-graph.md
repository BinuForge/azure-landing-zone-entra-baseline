# Workspace dependency graph

Arrows point from a workspace to the workspace whose outputs it reads with `tfe_outputs`. The graph
mirrors the `reads` lists in `tfc/workspaces.yaml`; the `tfc/` tests reject a read from a higher
level within the same area.

```mermaid
flowchart BT
  subgraph azure["Azure"]
    a0["lab-azure-l0-org-prd"]
    a1["lab-azure-l1-governance-prd"]
    a2m["lab-azure-l2-management-prd"]
    a2c["lab-azure-l2-connectivity-prd"]
    a2d["lab-azure-l2-dns-prd"]
    a3["lab-azure-l3-landingzones-prd<br/>(designed, not deployed)"]
    a3ai["lab-azure-l3-aiservices-prd"]
    a4["lab-azure-l4-opsagent-np<br/>(remote execution)"]
  end

  subgraph entra["Entra ID"]
    e0o["lab-entra-l0-org-prd"]
    e0p["lab-entra-l0-privileged-prd"]
    e1g["lab-entra-l1-governance-prd"]
    e1c["lab-entra-l1-ca-prd"]
  end

  a1 --> a0
  a2m --> a1
  a2c --> a1
  a2c --> a2m
  a2d --> a1
  a2d --> a2c
  a3 --> a1
  a3 --> a2m
  a3 --> a2c
  a3 --> a2d
  a3ai --> a1
  a3ai --> a2m
  a3ai --> a2c
  a3ai --> a2d
  a4 --> a2m
  a4 --> a3ai

  e0p --> e0o
  e1g --> e0o
  e1c --> e0o
  e1c --> e0p
```

No edge crosses areas. Entra's sign-in and audit logs go to a security workspace that bootstrap owns,
not to level 2's ops workspace, so the Entra levels read nothing from Azure (ADR-0016).
