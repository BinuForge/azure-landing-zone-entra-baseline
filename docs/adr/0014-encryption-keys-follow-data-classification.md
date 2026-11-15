# ADR-0014: Encryption keys follow data classification

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

- Every Azure service in the lab encrypts data at rest by default with Microsoft-managed keys.
- A customer-managed key (CMK) adds two things: the provider cannot use the key without the customer's
  key vault allowing it, and disabling the key makes the data unreadable, a kill switch.
- CMK for an AI services account needs a key vault with purge protection, a private endpoint and DNS
  zone for the vault, and a role for the account's identity on the key. A vault with purge protection
  cannot be removed for at least 7 days after deletion, which conflicts with the lab's deploy and
  teardown cycle unless the vault lives in bootstrap.
- CMK for Log Analytics needs a dedicated cluster, from about USD 3,500 a month.
- The lab's AI services hold infrastructure metadata from the lab estate and fabricated data only, never
  customer or personal data (ADR-0009).
- Checkov's CKV2_AZURE_22 asks for CMK on Cognitive Services accounts.

## Options considered

| Option | For | Against |
|---|---|---|
| Microsoft-managed keys, chosen by data classification | Matches the data; nothing extra to secure or tear down | Cannot demonstrate key revocation |
| CMK in a bootstrap key vault | Shows the full regulated pattern | A vault, private endpoint, DNS zone and key role to secure and run, for data that does not need it |
| CMK everywhere, including a Log Analytics cluster | Uniform | Cost far beyond the lab's budget |

## Decision

Use Microsoft-managed keys for every lab resource. Encryption-key ownership is decided per data
classification, not applied by default. CKV2_AZURE_22 is suppressed inline on the AI services account,
citing this ADR.

Microsoft-managed keys were chosen because CMK's protections, against provider access and through
revocation, do not change the risk for lab metadata, while its cost and teardown constraints are real.

## Risks accepted

| Risk | Why it is accepted | Mitigation, or how we would notice |
|---|---|---|
| The provider could in principle access data at rest | Lab metadata only, no customer or personal data | Data classification is stated in ADR-0009 and the threat model |
| No key kill switch for the AI services | Teardown removes the data instead | The destroy workflow and leftovers check |
| A reviewer sees a suppressed scanner finding | Suppressions are inline with a reason | Each suppression names this ADR |

## Consequences

- Easier: no key vault to secure, rotate or purge between sessions.
- Harder: the lab cannot show CMK running, so it is design only.
- At a bank, for highly confidential AI data: a key in a long-lived key vault with purge protection,
  behind a private endpoint; the AI account's identity holds only Key Vault Crypto Service Encryption
  User on that key; key rotation is automatic; revoking the key is tested as a control; Log Analytics
  uses a dedicated cluster with CMK where prompt content is retained.

Revisit if the lab ever processes customer, personal or production data.
