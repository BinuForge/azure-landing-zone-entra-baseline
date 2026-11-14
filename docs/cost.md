# Cost

Target: the default deployment costs **under USD 5 a day**. Anything more expensive sits behind a
flag that defaults to `false`.

## Guardrails

| Control | Status |
|---|---|
| Budget alerts at USD 30 / 60 / 100 per month | Bootstrap phase |
| Costly flags default to `false` | Enforced by variable defaults and tests, from the phase that adds each flag |
| Nightly workflow resets costly flags to `false` | Arrives with the first flag |
| `destroy.yml` workflow | Arrives with the first deployable level |

## Cost per flag

Approximate list prices, **not yet verified** for australiaeast. Each figure is checked against the
Azure pricing calculator in the phase that adds the flag, and this table is updated then.

| Flag | Resource | Approx. USD / day | Verified |
|---|---|---|---|
| `enable_firewall` | Azure Firewall (Basic / Standard) | 10 / 30, plus data | TODO |
| `enable_vpn_gateway` | VPN gateway (VpnGw1AZ) | 5 | TODO |
| `enable_route_server` | Azure Route Server | 11 | TODO |
| `enable_dns_resolver` | DNS Private Resolver (per endpoint) | TODO | TODO |
| `enable_apim` | API Management (Developer) | 2 | TODO |
| `enable_bastion_standard` | Azure Bastion Standard | 7 | TODO |
| `enable_ddos` | DDoS Network Protection | 98 | TODO |
| `enable_defender_paid` | Defender for Cloud paid plans | Per resource | TODO |
| `enable_arc_update_manager` | Update Manager on Arc servers | Per server | TODO |

## HCP Terraform managed resources

The Free tier allows 500 managed resources across the organisation. Data sources do not count.
Warn before a phase would take the total past **400**.

| Root | Phase | Resources | Running total |
|---|---|---|---|
| `tfc/` | 1 | 25 (3 projects, 11 workspaces, 11 workspace settings) | 25 |
