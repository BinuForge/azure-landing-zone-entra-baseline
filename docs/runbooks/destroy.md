# Destroy

Cost-bearing levels are torn down after each test session (ADR-0004). Teardown goes through the same
gates as a deploy: a saved destroy plan, read before approval, applied by the level's apply identity.

## What is torn down, and what stays

| Torn down by `destroy.yml` | Stays |
|---|---|
| Level 4 ops agent, level 3 AI services, level 2 DNS, connectivity and management, in that order | Bootstrap: budget, identities, resource groups, environments (needed for the next deploy) |
| | Level 0 management groups and level 1 policy (free, and the subscription sits in them) |

Empty level resource groups stay too. They are free, and level identities are scoped to them.

## Run it

1. GitHub, Actions, `destroy`, Run workflow.
2. Choose the target, and type it again in the confirmation box.
3. For each level, read the destroy plan in the run summary, then approve the apply environment.
4. The leftovers check runs last and fails if anything is left.

To check without destroying anything, choose `check`. The same check runs locally:

```sh
AZURE_SUBSCRIPTION_ID="$(az account show --query id -o tsv)" bash .github/scripts/leftovers.sh
```

## What the leftovers check looks for

| Leftover | Why it survives a destroy | How the check sees it |
|---|---|---|
| Any resource outside the bootstrap group | Created by hand, or missed by a destroy | Resource Graph, excluding expected types |
| A Defender plan above Free | A subscription setting, not a resource | Security pricings API. `Discovery` and `FoundationalCspm` report Standard but are free, and are allowed |
| A soft-deleted Foundry account | Deleting a Cognitive Services account soft-deletes it | Deleted accounts API. Purge with `az cognitiveservices account purge` |

`microsoft.network/networkwatchers` is expected: Azure creates one per region when the first virtual
network is made, and it does not bill.

## Adding a level

The pull request that adds a cost-bearing level also:

1. adds the level to the `target` options in `destroy.yml`;
2. adds a destroy job that calls `_plan.yml` with `destroy: true` and the level's plan environment, then
   `_apply.yml` with its apply environment, needing the job for the level above it;
3. adds any new leftover type to `.github/scripts/leftovers.sh`, with the reason.
