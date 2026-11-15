# Cost

Target: the default deployment costs **under USD 5 a day**. Anything more expensive sits behind a
flag that defaults to `false`.

## Guardrails

| Control | Status |
|---|---|
| Monthly budget of USD 30, alerts at 50, 80 and 100 percent actual and 100 percent forecast | Deployed by bootstrap |
| Costly flags default to `false` | `enable_prompt_logging` defaults to `false`, checked by level 3 tests. `enable_apim` is `true` only for the test sessions; `destroy.yml` removes it |
| Nightly workflow resets costly flags to `false` | Not built: a flag changes only by pull request, and `destroy.yml` removes everything after a session |
| `destroy.yml` workflow | Built: levels 2 and 3, then the leftovers check (docs/runbooks/destroy.md) |
| Log Analytics daily caps | 0.5 GB ops, 0.1 GB prompts: ingestion stops at the cap |

## Cost per flag

Approximate list prices, **not yet verified** for australiaeast. Each figure is checked against the
Azure pricing calculator in the phase that adds the flag, and this table is updated then.

| Flag | Resource | Approx. USD / day | Verified |
|---|---|---|---|
| `enable_firewall` | Azure Firewall (Basic / Standard) | 10 / 30, plus data | TODO |
| `enable_vpn_gateway` | VPN gateway (VpnGw1AZ) | 5 | TODO |
| `enable_route_server` | Azure Route Server | 11 | TODO |
| `enable_dns_resolver` | DNS Private Resolver (per endpoint) | TODO | TODO |
| `enable_apim` | API Management Developer, plus a Standard public IP | 1.80 | TODO: confirm in the calculator before the first deploy |
| `enable_bastion_standard` | Azure Bastion Standard | 7 | TODO |
| `enable_ddos` | DDoS Network Protection | 98 | TODO |
| `enable_defender_paid` | Defender for Cloud paid plans | Per resource | TODO |
| `enable_arc_update_manager` | Update Manager on Arc servers | Per server | TODO |

## HCP Terraform managed resources

The Free tier allows 500 managed resources across the organisation. Data sources do not count.
Warn before a phase would take the total past **400**.

| Root | Phase | Resources | Running total |
|---|---|---|---|
| `bootstrap/` | 3 | 134 (budget, 7 resource groups, lock, 12 apps, 12 service principals, 1 app role assignment, 11 federated credentials, 4 custom roles, 26 role assignments, subscription placement, hierarchy settings, report store account and container, 11 environments, 6 branch policies, 20 variables, 18 secrets) | 134 |
| `tfc/` | 3 | 37 (3 projects, 12 workspaces, 12 workspace settings, 2 variable sets, 2 attachments, 6 variables) | 171 |
| `azure/level-0-org` | 4 | 10 management groups | 181 |
| `azure/level-1-governance` | 4 | 13 (2 custom definitions, 3 initiatives, 4 assignments, 4 exemptions) | 194 |
| `azure/level-2-platform/management` | 4 | 1 Log Analytics workspace | 195 |
| `azure/level-2-platform/connectivity` | 4 | 3 (hub VNet, 2 reserved subnets) | 198 |
| `azure/level-2-platform/dns` | 4 | 6 (3 private DNS zones, 3 hub links) | 204 |
| `azure/level-3-aiservices` | 5 | 39 (spoke VNet, 2 subnets, 2 NSGs, 2 NSG associations, 2 peerings, 3 zone links, account, project, private endpoint, guardrail, 1 model deployment, prompt workspace, 2 diagnostic settings, 11 APIM NSG rules, and 8 APIM resources while enable_apim is on) | 243 |
