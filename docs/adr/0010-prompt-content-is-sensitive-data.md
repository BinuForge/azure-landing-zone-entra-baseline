# ADR-0010: Prompt content is sensitive data

- **Status:** Accepted
- **Date:** 2026-11-14

## Context

- Prompts to the ops agent contain estate metadata, and may contain whatever an attacker planted in a
  tag, name or log line. Responses can contain the same.
- Foundry diagnostic settings can send full request and response content to Log Analytics. Usage and
  audit categories record that a call happened without its content. TODO at build: confirm the current
  category names.
- Anyone with read access to a workspace can read everything in it, unless table-level access is set.
- Threats TM-10 and TM-08.

## Options considered

| Option | For | Against |
|---|---|---|
| Content logging off by default; when on, sent to a separate workspace with its own RBAC, short retention and an alert on every query | Content exists only when needed, and reading it is visible | Investigations without content rely on usage and gateway logs |
| Log content into the ops workspace | One place for everything | Everyone who reads ops logs reads prompts |
| Never log content | Nothing to leak | No way to investigate an injection after the fact |

## Decision

Usage, audit and gateway logs always go to the ops workspace. Content logging is behind a flag that
defaults to `false`, and when on it goes to a separate prompt workspace. Only the maintainer and level 3's
apply identity can read it, retention is the minimum, and any query against it raises an alert.

Reading it takes workspace permissions: resource permissions are off, so read on the Foundry account is
not enough. Plan identities hold a reader role without log reads (ADR-0012, decision 6), and no level may
delegate Log Analytics Reader where the workspace lives.

The first option was chosen because it keeps forensics possible without making prompt content part of
everyday log access.

## Risks accepted

| Risk | Why it is accepted | Mitigation, or how we would notice |
|---|---|---|
| With the flag off, an injection cannot be replayed | Tests run with the flag on; normal runs do not need content | Gateway logs still show caller, time, tokens and result |
| The maintainer can read prompt content | A single maintainer must be able to investigate | Every query raises an alert, so reading is never silent |
| Level 3's apply identity can read prompt content | It is Contributor on the group that holds the workspace, and could redirect the logs anyway. Removing the read would not reduce what it can do | Runs only on `main` after review; every query raises an alert |

## Consequences

- Easier: the most sensitive data in the platform has the smallest audience.
- Harder: two workspaces to manage, and investigations need the flag switched on.
- At a bank: prompt content is classified at the highest level of the data it can contain, with
  retention set by records policy and access through a privileged, reviewed role. The workspace sits
  in its own subscription, so no platform pipeline is Contributor over it, and reads go through
  just-in-time access with approval.
