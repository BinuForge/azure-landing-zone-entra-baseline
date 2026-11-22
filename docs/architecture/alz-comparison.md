# Comparison with the Azure landing zone

Microsoft's [Azure landing zone](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/)
is the reference design this repository follows. This page lists each part of it, what is here, and why
the difference exists. The short version: the structure is the same, the scale is one subscription, and
the costly services are designed but switched off.

| Area | Azure landing zone reference | Here | Why, and how it scales |
|---|---|---|---|
| Management groups | Root, platform (management, connectivity, identity), landing zones (corp, online), sandbox, decommissioned | The same hierarchy (`azure/level-0-org`) | Empty groups cost nothing and keep the design visible |
| Subscriptions | One per platform function, one or more per application, created by subscription vending | One subscription in corp (ADR-0004) | Free account limit. Levels are separated by resource group and identity instead; vending is the first thing to add at scale |
| Policy | A large set of assignments by archetype, many with deploy-if-not-exists | A focused baseline: no public IPs in corp, AI service rules, Microsoft cloud security benchmark in audit (`azure/level-1-governance`) | Deny and audit only, so no policy holds a managed identity with write rights. Archetype sets are added as landing zones appear |
| Connectivity | Hub and spoke or Virtual WAN, Azure Firewall, VPN or ExpressRoute, DDoS protection | Hub VNet with firewall and gateway subnets reserved, one spoke (`azure/level-2-platform/connectivity`) | Firewall and gateways are behind flags that default to off, for cost |
| DNS | Central private DNS zones, DNS Private Resolver | Central private DNS zones for Foundry; resolver subnets planned | The resolver is needed only with on-premises DNS |
| Management | Log Analytics, Azure Monitor Agent, data collection rules, Update Manager | Ops Log Analytics workspace; a separate security workspace for Entra logs (ADR-0016) | No virtual machines, so no agents or update management |
| Security | Defender for Cloud plans, Microsoft Sentinel | Defender free tier; logs ready for a SIEM | Plans and Sentinel cost money; the leftovers check fails if a paid plan is left on |
| Identity | An identity subscription, often with domain controllers | Cloud-only Entra ID with a full baseline (`entra/`) | No on-premises directory. The reference design does not configure Entra itself; this repository does |
| Application landing zones | Teams deploy into vended subscriptions | An AI services landing zone shared by consumers (ADR-0007), and one consumer, the ops agent | Shows the pattern with a real workload |
| Delivery | The accelerator bootstraps GitHub or Azure DevOps with identities and pipelines | Person-run bootstrap; read-only plan and single-level apply identities, saved encrypted plans, approvals (ADR-0012) | Tiered identities are stricter than the accelerator's defaults; at scale an identity team owns bootstrap |
| Modules | Azure Verified Modules | azurerm and azapi resources directly; one local module | Small levels read better without wrapper modules. Verified modules are the choice when teams share code |

## What this repository adds that the reference design does not cover

- An Entra ID baseline as code: Conditional Access, PIM, break-glass protection, tenant defaults.
- Threat models with a live test for each control (`docs/security/`).
- Signed evidence from real deployments (`evidence/`).
- An ADR for every significant decision, each with its bank-scale target.
