# Address plan

Private ranges only (RFC 1918), chosen for the lab and used in no real network. They are in code, not
hidden, so reviewers can check overlaps and tests can enforce them.

| Range | Use | Level | Status |
|---|---|---|---|
| `10.10.0.0/22` | Hub VNet `lab-vnet-hub-prd-ae` | 2 connectivity | Deployed |
| `10.10.0.0/26` | `AzureFirewallSubnet` | 2 connectivity | Reserved subnet; firewall behind a flag, off |
| `10.10.0.64/27` | `GatewaySubnet` | 2 connectivity | Reserved subnet; VPN gateway behind a flag, off |
| `10.10.0.128/28` | DNS Private Resolver inbound | 2 connectivity | Planned with the resolver flag |
| `10.10.0.144/28` | DNS Private Resolver outbound | 2 connectivity | Planned with the resolver flag |
| `10.10.0.192/26` | `AzureBastionSubnet` | 2 connectivity | Planned with the Bastion flag |
| `10.20.0.0/24` | AI services spoke `lab-vnet-aiservices-prd-ae` | 3 aiservices | Planned |
| `10.30.0.0/16` | Future spokes, one /24 each | 3 and 4 | Unallocated |
| `10.110.0.0/22` | DR hub in australiasoutheast, mirroring the primary | 2 connectivity | Design only |

Rules:

- Spokes never overlap the hub or each other, because peering refuses overlapping ranges.
- Azure-named subnets (`AzureFirewallSubnet`, `GatewaySubnet`, `AzureBastionSubnet`) keep their required
  names and minimum sizes, and take no network security group.
- A new range is added here in the same pull request as the code that uses it.
