# ADR-0009: Model deployment type and residency

- **Status:** Accepted
- **Date:** 2026-11-14

## Context

- Deployment types decide where a prompt may be processed and how it is billed. See
  [deployment types](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/concepts/deployment-types).
- Quota on the lab subscription was checked on 2026-11-14:

  ```sh
  az cognitiveservices usage list --location australiaeast \
    --query "[?limit>\`0\`].{quota:name.value, limit:limit}" -o table
  ```

  Chat models have quota only as Global Standard (for example `gpt-4.1-mini` and `gpt-5-mini`).
  Regional Standard and Data Zone quota for chat models is zero.
- Data Zone deployments process prompts within one of three Microsoft-defined zones: United States,
  European Union, or Asia Pacific (checked on the page above, 2026-11-14). The APAC zone spans several
  countries, so it keeps processing in the region but not in Australia.
- The ops agent sends lab estate metadata to the model, never customer or personal data.

## Options considered

| Option | For | Against |
|---|---|---|
| Global Standard | Quota available; pay per token; lowest token price | A prompt may be processed in any Azure region |
| Regional Standard in australiaeast | Processing stays in Australia | No chat model quota on this subscription |
| Data Zone Standard (APAC) | Processing stays within Asia Pacific | No quota on this subscription, and APAC is wider than Australia |
| Provisioned (any) | Predictable performance | Billed hourly whether used or not; out of the lab's budget |

## Decision

Deploy one small model with tool calling as Global Standard in `australiaeast`, with a low token limit.
The model is chosen on price at build time from those with quota. Stored data (the account, logs and
reports) stays in Australia; processing may happen elsewhere.

Global Standard was chosen because it is the only type with quota, and the data sent is lab metadata
that does not need to stay in Australia.

## Risks accepted

| Risk | Why it is accepted | Mitigation, or how we would notice |
|---|---|---|
| Prompts are processed outside Australia | Lab metadata only, no personal or customer data | The runner redacts identifiers before sending (C-11) |
| The chosen model version is retired | Microsoft retires versions on a schedule | Version pinned in code; a failed plan or retirement notice prompts the upgrade PR |

## Consequences

- Easier: the lab runs on the free account at token prices measured in cents.
- Harder: the residency story is design only. At a bank this would change first: Regional Standard or
  Provisioned in Australia, with residency approved by risk and privacy before any customer data.
- Revisit if in-region chat quota appears, or if the agent ever reads data that must stay onshore.
