# Cost

Target: the default deployment costs **under USD 5 a day**. Anything more expensive sits behind a
flag that defaults to `false`.

## Guardrails

| Control | Status |
|---|---|
| Monthly budget of USD 30, alerts at 50, 80 and 100 percent actual and 100 percent forecast | Deployed by bootstrap |
| Costly flags default to `false` | `enable_prompt_logging` defaults to `false`, checked by level 3 tests. `enable_apim` is `true` only for the test sessions; `destroy.yml` removes it |
| Nightly workflow resets costly flags to `false` | Not built: a flag changes only by pull request, and `destroy.yml` removes everything after a session |
| `destroy.yml` workflow | Built: levels 4, 3 and 2, then the leftovers check (docs/runbooks/destroy.md) |
| Log Analytics daily caps | 0.5 GB ops, 0.1 GB prompts, 0.5 GB security (Entra logs): ingestion stops at the cap |
| Entra ID P2 trial | Free for 30 days from activation. Conditional Access, PIM and log export need a licence after that, so the Entra levels are torn down or licensed before it ends (ADR-0016) |
| Always-on alert | The prompt query alert evaluates every 5 minutes: about USD 1.50 a month, not yet verified in the calculator |

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
| `bootstrap/` | 3, 4 | 145 (budget, 7 resource groups, lock, 12 apps, 12 service principals, 1 app role assignment, 11 federated credentials, 10 custom roles, 30 role assignments, subscription placement, hierarchy settings, report store account and container, security workspace, 11 environments, 6 branch policies, 20 variables, 18 secrets), plus 1 with `entra_diagnostics` on | 145 |
| `entra/bootstrap/` | 4 | 76 (7 apps, 7 service principals, 7 federated credentials, 24 Graph permission grants, 7 environments, 3 branch policies, 14 variables, 7 secrets) | 221 |
| `tfc/` | 3 | 38 (3 projects, 12 workspaces, 12 workspace settings, 2 variable sets, 2 attachments, 7 variables) | 259 |
| `azure/level-0-org` | 4 | 10 management groups | 269 |
| `azure/level-1-governance` | 4 | 13 (2 custom definitions, 3 initiatives, 4 assignments, 4 exemptions) | 282 |
| `azure/level-2-platform/management` | 4 | 1 Log Analytics workspace | 283 |
| `azure/level-2-platform/connectivity` | 4 | 3 (hub VNet, 2 reserved subnets) | 286 |
| `azure/level-2-platform/dns` | 4 | 6 (3 private DNS zones, 3 hub links) | 292 |
| `azure/level-3-aiservices` | 5 | 44 (spoke VNet, 2 subnets, 2 NSGs, 2 NSG associations, 2 peerings, 3 zone links, account, project, private endpoint, guardrail, 1 model deployment, prompt workspace, 2 diagnostic settings, prompt query alert and its role, 12 APIM NSG rules, and 10 APIM resources while enable_apim is on) | 336 |
| `azure/level-4-workloads/opsagent` | 5 | 7 (6 runner role assignments, canary NSG) | 343 |

The Entra levels have 57 resources left before the 400 warning. With Azure levels 2 to 4 torn down, as
between sessions, the total is 282.
