# ADR-0004: One subscription on the free account, with no upgrade

- **Status:** Accepted
- **Date:** 2026-11-04

## Context

- The design separates corp-nonprod, corp-prod and sandbox into their own subscriptions, created by
  landing zone vending.
- The lab runs on an Azure free account. Unused credit lasts
  [30 days from sign-up](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/upgrade-azure-subscription).
- Microsoft lists Enterprise Agreement, Microsoft Customer Agreement and Microsoft Partner Agreement
  billing accounts for
  [programmatic subscription creation](https://learn.microsoft.com/en-gb/azure/cost-management-billing/manage/programmatically-create-subscription-preview).
  Free accounts are not listed. This is inferred from the list, not stated by Microsoft.
- If a subscription is disabled for running out of credit and is later upgraded,
  [its resources are enabled again and charged](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/upgrade-azure-subscription).
- The lab has one hard rule on cost: nothing may bill continuously without the owner knowing.

## Options considered

| Option | For | Against |
|---|---|---|
| One subscription, no upgrade | No surprise charges; management groups, policy and RBAC can still be shown | No real subscription boundary, and vending is not demonstrated |
| Upgrade to pay-as-you-go, with subscriptions created by hand | Real subscription boundaries | Ongoing spend risk, because budgets alert but do not stop spending; creating subscriptions by hand is not vending |
| Move to a billing account that supports vending | Shows the full design | Cost and account changes out of proportion to a personal lab |

## Decision

Deploy into one subscription and let it lapse when the credit ends. Keep the management group hierarchy
and policy baseline, and use resource groups as the boundary between environments. Level 3 vending stays
in the design, documented but not deployed.

One subscription was chosen because the cost rule outranks showing subscription boundaries, and the
boundary is simple to explain in review.

## Risks accepted

| Risk | Why it is accepted | Mitigation, or how we would notice |
|---|---|---|
| A resource group is a weaker boundary than a subscription | This is a lab holding no real data | RBAC and policy are scoped per resource group; this ADR states the gap |
| Quotas, budgets and blast radius are shared across environments | Only one workload runs at a time | Costly flags default to off, and everything can be destroyed in one workflow |
| The lab stops working when the credit ends | Stopping is preferred to surprise charges | Code, plans and dated evidence stay in the repo |
| Upgrading later would re-enable and charge for any resource left running | There is no plan to upgrade | Destroy everything before the credit ends |

## Consequences

- Easier: cost is bounded, and there is one subscription to reason about.
- Harder: subscription-level isolation and vending cannot be shown running, so the evidence for them is
  design only.
- At bank scale this would be the first thing to change: separate subscriptions per environment, created
  by vending.

Revisit if the lab moves to a billing account that supports vending, or if a target role needs vending
shown running.
