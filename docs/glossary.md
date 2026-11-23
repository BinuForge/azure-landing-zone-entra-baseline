# Glossary

The words this repository uses, one line each.

| Term | Meaning |
|---|---|
| **AI gateway** | API Management in front of the model. The only identity allowed to call Foundry; adds token limits, logs and the kill switch (ADR-0008) |
| **Apply environment** | A GitHub environment that unlocks a level's apply identity, and requires a reviewer's approval |
| **Apply identity** | The Entra app a pipeline uses to make changes in one level, and only that level |
| **Attestation** | A signature that ties an evidence file to the workflow run that made it, recorded in a public log |
| **Bootstrap** | The roots you run by hand to create what pipelines need before they can run |
| **Break-glass account** | One of two emergency Global Administrator accounts, kept out of every Conditional Access policy |
| **Canary** | A resource with planted malicious text, used to test that the ops agent is not fooled |
| **Drift** | A difference between code and what is deployed, found by the nightly `drift.yml` plan |
| **Dynamic credentials** | HCP Terraform signing in to Azure with OIDC per run, with no stored secret (level 4) |
| **Evidence pack** | A folder in `evidence/` of redacted, attested files from a live run |
| **Federated credential** | Trust that lets a GitHub job sign in as an Entra app with OIDC, with no secret |
| **Guardrail** | Foundry's content filter and Prompt Shields, set by the strict RAI policy in level 3 |
| **Kill switch** | A gateway setting that stops every model call within seconds |
| **Leftovers check** | The last step of a teardown, which fails if a cost-bearing resource remains |
| **Level** | One Terraform root with its own workspace, identities and workflow. Lower levels are deployed first |
| **Local execution** | Terraform runs on the GitHub runner or your machine; HCP stores only the state |
| **Persona group** | A dynamic Entra group, such as internals or guests, that Conditional Access targets |
| **PIM** | Privileged Identity Management: admin roles are eligible and activated for a few hours, not held permanently |
| **Plan identity** | The read-only Entra app a pipeline uses to plan a level, including on pull requests |
| **Prefix** | The start of every name, `lab` by default ([naming](naming.md)) |
| **Remote execution** | Terraform runs on HCP's servers (level 4 only) |
| **Report-only** | A Conditional Access policy that records what it would do without doing it |
| **Restricted administrative unit** | An Entra container whose members only named admins can change; it protects the break-glass accounts |
| **Root** | A folder Terraform runs in, with its own state. Every level is a root |
| **Saved plan** | The plan file made before approval and applied unchanged after it, encrypted while stored |
| **Tier 0** | Anything that controls access itself: bootstrap, Entra privileged, PIM. Run by a person, never a pipeline |
| **Unique suffix** | Up to 3 characters added to the few names that must be unique across Azure (ADR-0020) |
| **Workspace** | HCP Terraform's home for one root's state and settings |
