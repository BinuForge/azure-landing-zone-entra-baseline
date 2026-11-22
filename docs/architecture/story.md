# The story of this repository

This is the whole design told as a story, for anyone who works in IT. There is no code here. Each part
ends with where to look if you want the detail. The diagrams are in [the overview](overview.md).

## The problem

Picture a company of 300 to 1,000 people in a regulated industry, such as a bank, an insurer or a health
fund. It wants to use Azure and AI services. Its regulator expects it to show who can change what, how
changes are approved, and how it would notice something going wrong.

Most companies start in the portal: someone clicks to create a network, someone else adds a policy,
access is granted when people ask. A year later nobody can say why a setting is the way it is, and
the audit takes weeks.

This repository builds the opposite: an Azure estate and an Entra ID tenant where every setting is
written down as code, every change is reviewed before it happens, and the evidence that controls work is
collected automatically. It is built small, on one lab tenant and one subscription, but every decision
records what a bank would do at full scale.

The story has three parts: the building (Azure), the security desk (Entra ID) and the way work gets done
(the code and the pipelines).

## Part 1: Azure, the building

Think of Azure as an office building that the company is fitting out.

### The floor plan: management groups

Before anyone moves in, you decide the floor plan. Microsoft publishes a standard one, the Azure landing
zone, and this repository follows it. Management groups are the floors and wings:

- Platform, for the shared services everyone relies on: management (logging), connectivity (the
  network) and identity.
- Landing zones, where business applications live: corp for internal systems, online for anything facing
  the internet.
- Sandbox, for experiments, and decommissioned, for things on their way out.

Most of these wings are empty. Empty wings cost nothing, and keeping them shows the full design. The
lab's one subscription sits in corp. In a real company each wing would hold many subscriptions, each
created on request by an automated "vending" process.

Look at: `azure/level-0-org/`.

### The building code: Azure Policy

Every building has a code that inspectors enforce. Here that is Azure Policy, assigned at the top of the
floor plan so it applies everywhere below. Some rules are hard blocks: no public IP addresses in corp, AI
services must not accept keys or public network traffic, only approved models may be deployed. Others
only report, such as Microsoft's cloud security benchmark, so you can see where you stand before you
start blocking.

The rules are tested. A test tries to create something forbidden and expects to be refused, and the
result goes into the evidence folder.

Look at: `azure/level-1-governance/`, `tests/policy/`.

### Shared services: the plant room

Every building has a plant room that nobody visits but everyone depends on: power, plumbing, the
switchboard. Level 2 is that room:

- a central log workspace, where operational logs go;
- a hub network, the building's corridors, with space reserved for a firewall and a VPN gateway that are
  switched off to save cost;
- private DNS, so services find each other by name without going onto the internet.

Look at: `azure/level-2-platform/`.

### The AI room, with a reception desk

Level 3 is a room for AI services, Microsoft Foundry, set up as a shared service other teams can use.
The room has no outside door: Foundry has no public network access and accepts no keys. The only way in
is through a reception desk, an API Management gateway, which checks who you are with your Entra
identity, limits how much you can use, logs a correlation ID for every request, and has a kill switch
that stops all AI traffic in one action.

Before any of this was built, a threat model listed how it could be attacked, such as prompt injection,
data leaking out through the model and runaway cost. Each threat has a control, and each control has a
live test.

Look at: `azure/level-3-aiservices/`, `docs/security/threat-model-ai.md`, `tests/gateway/`.

### A tenant who only reads: the ops agent

Level 4 is the first "tenant" of the building: an operations agent that, when run, writes a report on
cost and health. It uses the AI room through the reception desk like anyone else. It can read the estate but
cannot change anything, and it can write its report into a store it cannot read back. If someone tricks
the model, the worst outcome is a bad paragraph that a person reads. It cannot cause a change in Azure
and cannot leak data.

Look at: `azure/level-4-workloads/opsagent/`, `agents/opsagent/`.

### Why levels?

Each part is a separate "level" with its own state and its own pipeline identity. Higher levels read
what lower levels publish and never the reverse, the way a tenant can use the building's power but cannot
rewire the plant room. A mistake in level 3 cannot damage level 1.

Look at: `docs/architecture/dependency-graph.md`.

## Part 2: Entra ID, the security desk

If Azure is the building, Entra ID is the security desk at the front door: it issues badges, decides who
gets in, and holds the master keys.

### Badges and groups

Everyone who signs in gets a badge, an identity. People fall into groups that Microsoft calls personas:
internals (staff), guests (people from other organisations) and admins. Internals and guests are dynamic
groups: membership follows a rule, so nobody is added by hand and nobody is forgotten. Admins are not a
group at all: rules target them by the admin role they hold, so a role someone picks up later is still
covered.

Look at: `entra/level-0-org/`.

### The door rules: Conditional Access

Conditional Access decides, at every sign-in, whether to let someone in and what proof to ask for. The
baseline has eight rules:

- block old sign-in methods that cannot do MFA, the device code trick used in phishing, and sign-ins from
  outside Australia;
- admins must use phishing-resistant MFA, such as a passkey or a security key;
- staff and guests must use MFA;
- risky sign-ins and risky accounts must prove themselves again, every time.

All eight start in report-only mode. They are checked against every real sign-in and the result is
logged, but nobody is blocked. After seven days of results, each rule is switched on one at a time. This
is how you avoid the classic mistake of locking every admin out of the tenant on a Friday afternoon.

Look at: `entra/level-1-ca/`, ADR-0017.

### House rules: tenant defaults

A new Entra tenant is friendly by default: anyone can invite guests, anyone can register an app, and
anyone can let an app read their mailbox. That last one is how many real breaches start: a convincing
"sign in to view this document" page asks the user to approve an app, and the attacker's app now reads
their mail with no password needed.

This baseline closes those doors. Users cannot approve apps; they request it, and an admin reviews.
Guests see only their own details. Only admins invite. Text message and phone call codes are switched
off, because they can be phished and SIM-swapped; passkeys and the Authenticator app replace them.

Look at: `entra/level-1-governance/`, ADR-0018.

### The master keys: PIM and break-glass

Global Administrator is the master key: whoever holds it can do anything, including giving it to someone
else. Two rules protect it.

First, nobody holds it all the time except two emergency accounts. Everyone else is "eligible" through
Privileged Identity Management (PIM): they ask for the key when they need it, prove who they are with
MFA, say why, and get it for at most four hours. If an admin's laptop is stolen on a Tuesday, the thief
does not have a master key.

Second, the two emergency accounts, "break-glass", are like keys in a sealed envelope in a locked
cabinet. Conditional Access never applies to them, so a broken rule cannot lock the company out. That
makes the group that excludes them the most sensitive group in the tenant: anyone who could add
themselves to it would escape every rule. So the accounts and the group sit in a restricted
administrative unit, a cabinet that even other Global Administrators cannot open without first giving
themselves a key to that cabinet, which is recorded. Every plan also checks that exactly two such
accounts exist, that both are enabled, cloud-only and still Global Administrators.

Look at: `entra/level-0-privileged/`, `entra/break-glass/`, ADR-0016, ADR-0019.

## Part 3: the code, and the way work gets done

### Blueprints: Terraform

Everything above is written as Terraform: text files that describe what should exist. Terraform compares
the description with what is really there and makes the difference. The files are the single source of
truth; the portal is for looking, not changing.

### The building inspector: pull request gates

Nobody changes the estate directly. A change starts as a pull request, and automatic checks run before
anyone looks at it: formatting, validation, a linter, a security scanner (checkov), a secret scanner
(gitleaks) and unit tests that run against fake providers, so they need no cloud access. The tests check
the rules that matter, for example "every Conditional Access policy excludes the break-glass group and
nothing else" and "no pipeline holds a permission that can grant itself more".

Look at: `.github/workflows/pr.yml`, `tests/` folders under each level.

### Workers with limited keys: pipeline identities

The pipelines that make changes are workers with keys, and the design question is which keys. Each
level has two identities: a planner that can only read, and an applier that can only write to that
level. Neither has a password: GitHub proves who it is to Microsoft with a short-lived token (OIDC), so
there is no secret to steal. No pipeline holds a permission that could make itself or anyone else Global
Administrator. The few changes that need such a permission, the bootstrap and the master-key level, are
run by a person from their own machine.

Look at: `bootstrap/`, `entra/bootstrap/`, ADR-0012, ADR-0016.

### Measure twice, cut once: plan, approve, apply

When a pull request is merged, the pipeline makes a plan: the exact list of changes. The plan is
encrypted and saved. A person reads it and approves. Only then does the applier run, and it applies that
exact saved plan, not a fresh one, so what was approved is what happens.

Every night a drift check plans every level that should exist. If anything changed outside the code,
someone clicking in the portal for example, it opens an issue.

Look at: `.github/workflows/_plan.yml`, `_apply.yml`, `drift.yml`.

### Inspection certificates: evidence

Auditors do not want promises; they want proof. After a deployment, an evidence workflow collects what
is really there, such as policy assignments, test results and costs, signs it so it cannot be quietly
edited, and stores it with the date. Findings, including the embarrassing ones, are written down.

Look at: `evidence/`, ADR-0011.

### Writing down why: decision records

Every significant choice has an architecture decision record: the context, the options considered, the
decision, the risks accepted and what a bank would do differently. When someone asks in a year "why is
it like this?", the answer is in the repository.

Look at: `docs/adr/`.

### Keeping the bill small

The lab is torn down between sessions. Anything expensive, such as the AI gateway, is behind a switch
that defaults to off. A destroy workflow removes the costly levels in order and then checks nothing was
left behind.

Look at: `docs/cost.md`, `docs/runbooks/destroy.md`.

## What a bank would add

The lab proves the patterns; a bank would add scale and separation of duties:

- many subscriptions created by a vending process, instead of one;
- a firewall, private connectivity to on-premises, and Defender for Cloud plans switched on;
- a SIEM such as Sentinel, with alerts on break-glass sign-ins, PIM activations and policy changes;
- a second approver for every Tier 0 change, and quarterly access reviews;
- Conditional Access for devices and workload identities, and token protection.

Each ADR's "Consequences" section says what changes at bank scale for that decision.

## Glossary

| Term | Meaning |
|---|---|
| Landing zone | A pre-built, governed place in Azure where an application team can deploy |
| Management group | A folder for subscriptions; policy and access set on it flow down |
| Azure Policy | Rules Azure enforces or reports on when anything is created or changed |
| Entra ID | Microsoft's identity service: users, groups, sign-in and admin roles |
| Conditional Access | Rules evaluated at each sign-in: who, from where, with what proof |
| PIM | Privileged Identity Management: admin roles held only when activated, for a limited time |
| Break-glass account | An emergency admin account, used only if normal admin access is lost |
| Restricted administrative unit | A container in Entra whose members even Global Administrators cannot change without a scoped role |
| OIDC federation | A pipeline proves its identity with a short-lived token instead of a stored password |
| Terraform plan | The exact list of changes Terraform will make, reviewed before it is applied |
| Drift | A difference between the code and what really exists, usually from a manual change |
| ADR | Architecture decision record: one decision, with its context and trade-offs |
