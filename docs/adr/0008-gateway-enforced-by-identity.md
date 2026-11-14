# ADR-0008: The AI gateway is enforced by identity

- **Status:** Accepted
- **Date:** 2026-11-14

## Context

- Foundry accepts a call from any Entra identity that holds a data-plane role on the account. Network
  access only decides whether a caller can reach the endpoint, not whether the call is allowed.
- Key (local) authentication can be disabled on the account, so no API key can be used at all. See
  [disable local authentication](https://learn.microsoft.com/en-us/azure/ai-services/disable-local-auth).
- The gateway's value (per-caller limits, caller identity in logs, one kill switch) is lost on any call
  that skips it. Threat TM-06.

## Options considered

| Option | For | Against |
|---|---|---|
| Only the APIM managed identity holds a data-plane role on Foundry | A direct call fails with 403 whatever the network allows | APIM becomes a single point of failure for model access |
| Network only: Foundry reachable only from the APIM subnet | Familiar pattern | Any identity with a role and network reach can still call directly; network rules are easy to widen |
| Convention: consumers are told to use APIM | No extra work | Nothing stops a consumer, so the controls are optional |

## Decision

Disable local authentication and public network access on Foundry, and grant a Foundry data-plane role
to the APIM managed identity only. Consumers authenticate to APIM with their own Entra identity and are
authorised per APIM product. No consumer identity holds a role on Foundry.

The role is Cognitive Services OpenAI User: it can call deployments and read models, but has no
`listkeys` action. Foundry User was rejected because it includes `accounts/listkeys/action` and
`projects/connections/listsecrets/action` (checked with `az role definition list` on 2026-11-14).

Identity was chosen over network rules because it holds even when the network is wrong, and because the
test for it is simple: call Foundry directly and expect 403 (T-04).

## Risks accepted

| Risk | Why it is accepted | Mitigation, or how we would notice |
|---|---|---|
| APIM is a single point of failure, and the Developer tier has no SLA | A lab, used in short sessions | At a bank: a tier with zone redundancy and an SLA |
| A compromised APIM managed identity has full model access | It only exists inside APIM | Token limits bound the damage; drift detection flags new role assignments |
| A subscription Owner can grant another identity a role | Owners can do anything in the subscription | T-04 runs after every deploy; drift detection on role assignments |

## Consequences

- Easier: every model call carries a caller identity, a limit and a log entry, and one switch stops them
  all.
- Harder: every consumer must be onboarded at APIM, and APIM outages stop all AI traffic.
- Revisit if Foundry gains native per-caller limits that match APIM's.
