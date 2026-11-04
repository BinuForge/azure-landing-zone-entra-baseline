# ADR-0006: Approvals with a single maintainer

- **Status:** Accepted
- **Date:** 2026-11-05

## Context

- The design gates every apply behind a GitHub environment with a required reviewer (ADR-0002), and
  every change to `main` behind a pull request.
- The lab has one maintainer. That person writes the code, opens the pull request and approves the
  apply.
- GitHub does not let the author of a pull request approve it, so a rule requiring one approving
  review would block every merge. See
  [about protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches).
- Environments have a "prevent self-review" option. With it on, the person who triggered a run cannot
  approve it, so a single maintainer could never deploy. See
  [deployment protection rules](https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-deployments/managing-environments-for-deployment#required-reviewers).
- Rulesets, branch protection and required reviewers on environments are only available to private
  repositories on paid plans. This repository is private on GitHub Free until it goes public before
  the first apply.

## Options considered

| Option | For | Against |
|---|---|---|
| Pull requests and passing checks required, no required approvals; environments need the maintainer as reviewer, self-review allowed | Every change still goes through the gates and a deliberate pause before apply | Not separation of duties: one person can change and deploy anything |
| Require one approval and add a second account to approve | Looks like two-person control | It is the same person with two logins, which is worse than stating the gap |
| No gates at all | Fastest | Nothing to show, and nothing stops a mistaken apply |

## Decision

Require a pull request and passing PR gates for `main`, with no required approving reviews. Apply
environments need the maintainer as a required reviewer, with self-review allowed.

This is a pause to confirm, not separation of duties, and the repository says so wherever approvals
are described. The first option was chosen because it keeps every control that one person can
honestly operate, and names the one control they cannot.

## Risks accepted

| Risk | Why it is accepted | Mitigation, or how we would notice |
|---|---|---|
| One person can change and deploy anything | A lab with one maintainer and no real data | The plan to be applied is reviewed in the run before approval; every apply is in the Actions history |
| The repository owner can bypass rules as an administrator | GitHub allows owners to bypass, and a solo owner needs it to recover from mistakes | Bypasses appear in the ruleset insights once the repository is public |

## Consequences

- Easier: the full gate design runs end to end with one person.
- Harder: the evidence cannot show two-person control, so it is documented as design only.
- At a bank this would change first: approvers in a separate group from authors, prevent self-review
  on, no administrator bypass on `main`, and changes to production tied to an approved change record.

Revisit if a second maintainer joins.
