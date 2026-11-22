# Architecture overview

Four views of the same system. For the plain-language version, read [the story](story.md) first.

## 1. The whole system

Code in GitHub is the only way in. Pipelines plan with read-only identities, a person approves, and the
saved plan is applied. State lives in HCP Terraform, one workspace per level.

```mermaid
flowchart LR
  dev["Maintainer"] -->|pull request| gh["GitHub<br/>PR gates: fmt, validate, tflint,<br/>checkov, gitleaks, terraform test"]
  gh -->|merge to main| act["GitHub Actions<br/>plan, approve, apply"]
  act -->|OIDC, no secrets| hcp["HCP Terraform<br/>one workspace per level"]
  act -->|plan and apply identities| az["Azure<br/>levels 0 to 4"]
  act -->|plan and apply identities| en["Entra ID<br/>levels 0 and 1"]
  dev -.->|Tier 0 only, run by hand| t0["bootstrap, entra/bootstrap,<br/>level 0 privileged, PIM script"]
  t0 -.-> az
  t0 -.-> en
  az -->|evidence workflow| ev["evidence/<br/>signed results"]
  en -->|sign-in and audit logs| sec["Security workspace<br/>(bootstrap)"]
```

## 2. Azure estate

The Azure landing zone layout, shrunk to one subscription. Empty management groups cost nothing and keep
the full design visible.

```mermaid
flowchart TB
  subgraph mg["Level 0: management groups"]
    root["lab-mg-root"] --> plat["platform"]
    root --> lz["landingzones"]
    root --> sbx["sandbox"]
    root --> dec["decommissioned"]
    plat --> mgmt["management"]
    plat --> conn["connectivity"]
    plat --> idn["identity"]
    lz --> corp["corp<br/>(the one subscription)"]
    lz --> onl["online"]
  end

  pol["Level 1: policy<br/>platform baseline, AI baselines,<br/>no public IPs in corp, MCSB audit"] -.->|assigned at| root

  subgraph net["Levels 2 and 3: network"]
    hub["Hub VNet 10.10.0.0/22<br/>firewall and gateway subnets reserved"]
    spoke["AI services spoke 10.20.0.0/24"]
    dns["Private DNS zones<br/>for Foundry"]
    hub <-->|peering| spoke
    dns -.->|linked| hub
    dns -.->|linked| spoke
  end

  subgraph ai["Level 3: AI services"]
    apim["APIM AI gateway<br/>caller identity, token limits,<br/>kill switch"]
    pe["Private endpoint"]
    fdy["Foundry account and project<br/>no public access, no keys"]
    apim --> pe --> fdy
  end

  subgraph ops["Level 4: ops agent"]
    agent["Ops agent runner<br/>read-only roles"]
    store["Report store<br/>write-only (bootstrap)"]
  end

  logs["Level 2: ops Log Analytics workspace"]
  agent -->|Entra token| apim
  agent --> store
  agent -->|reads cost, resources, logs| logs
  fdy -.->|diagnostics| logs
```

## 3. Identity

Three tiers. Tier 0 can make someone Global Administrator, so only a person changes it. Pipelines hold
only what their level needs.

```mermaid
flowchart TB
  subgraph t0["Tier 0: person-run, never a pipeline"]
    bg["Two break-glass accounts<br/>standing Global Administrator"]
    au["lab-au-emergency<br/>restricted management unit"]
    excl["lab-grp-excl-breakglass"]
    pim["PIM<br/>eligible roles, 4 h activation,<br/>MFA and justification"]
    boot["bootstrap and entra/bootstrap<br/>create every pipeline identity"]
    bg --- au
    excl --- au
  end

  subgraph t1["Tier 1: pipelines"]
    plan["Plan identities<br/>read only"]
    apply["Apply identities<br/>one level each, no Tier 0 permission"]
  end

  subgraph users["People"]
    adm["Admins<br/>targeted by directory role"]
    int["Internals<br/>dynamic group"]
    gst["Guests<br/>restricted guest role"]
  end

  ca["Conditional Access CA001 to CA008<br/>report-only first"]
  boot -->|OIDC federated credentials| plan
  boot --> apply
  ca -->|applies to| adm
  ca -->|applies to| int
  ca -->|applies to| gst
  ca -.->|excludes only| excl
  pim -->|activates| adm
```

## 4. How a change reaches production

```mermaid
sequenceDiagram
  participant M as Maintainer
  participant G as GitHub
  participant P as Plan identity
  participant H as HCP Terraform
  participant A as Apply identity
  M->>G: Pull request
  G->>G: Offline gates and tests with mock providers
  G->>P: Plan (read only)
  P->>H: Read state
  P-->>G: Plan posted on the pull request
  M->>G: Review and merge
  G->>P: Plan again, save it encrypted
  M->>G: Approve the apply environment
  G->>A: Apply exactly the saved plan
  A->>H: Write state
  G-->>M: Nightly drift plan opens an issue if anything changed outside code
```

## Where to go next

| To understand | Read |
|---|---|
| Why each choice was made | [ADR index](../adr/README.md) |
| How workspaces depend on each other | [Dependency graph](dependency-graph.md) |
| What is left out of Microsoft's reference design, and why | [Comparison with the Azure landing zone](alz-comparison.md) |
| Which controls map to which frameworks | [Control mapping](../security/control-mapping.md) |
| How identity could be attacked | [Identity threat model](../security/threat-model-identity.md) |
