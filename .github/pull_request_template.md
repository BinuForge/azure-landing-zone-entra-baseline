## What and why

<!-- What changes, and the reason. Link the ADR if this records or follows a decision. -->

## Checks

- [ ] PR gates pass (format, validate, lint, IaC scan, secret scan, tests)
- [ ] Plan output read for every root this touches, with no unexpected changes or destroys
- [ ] No tenant IDs, subscription IDs, IP ranges, secrets or employer content
- [ ] New costly resources are behind a flag that defaults to `false`, and `docs/cost.md` is updated
- [ ] Docs, ADRs and the dependency graph match the change
- [ ] Mapping docs say "supports", never "complies"

## Cost and destroy

<!-- Expected daily cost of what this deploys, and how to remove it. "None" if it deploys nothing. -->
