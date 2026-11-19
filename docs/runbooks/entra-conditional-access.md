# Entra level 1, Conditional Access

`entra/level-1-ca` holds the named location and the eight baseline policies (ADR-0017). It runs like the
Azure levels: a pull request plans with `lab-entra-l1-ca-plan`, a merge plans again and waits for approval
in `lab-entra-l1-ca-apply`. Every policy starts report-only.

It reads level 0's outputs, so level 0 org and level 0 privileged must be applied first. Without the
break-glass exclusion group the plan stops.

## Reading report-only results

For one sign-in: Entra admin centre, Sign-in logs, open the sign-in, Report-only tab. Each policy shows
the result it would have had.

Across all sign-ins, with Entra diagnostics on (`docs/runbooks/bootstrap.md`), in `lab-log-security-prd-ae`:

```kusto
SigninLogs
| where TimeGenerated > ago(7d)
| mv-expand policy = ConditionalAccessPolicies
| where tostring(policy.displayName) startswith "CA0"
| summarize sign_ins = count() by policy = tostring(policy.displayName), result = tostring(policy.result)
| order by policy asc, result asc
```

`reportOnlySuccess` would have passed, `reportOnlyFailure` would have been blocked, `reportOnlyInterrupted`
would have asked for more (usually MFA), and `reportOnlyNotApplied` was out of scope. The Conditional
Access insights workbook shows the same data.

## Enforcing a policy

1. Check the policy against ADR-0017's bar: seven days of results, no failure for a legitimate sign-in,
   break-glass not applied, and for CA004 a phishing-resistant method for every administrator.
2. Before the first policy is enforced, turn security defaults off: Entra admin centre, Overview,
   Properties, Manage security defaults. Do it in the same session as enforcing CA001, CA005 and CA006.
3. In one pull request, add the policy ID to `local.enforced` in `policies.tf` and update the test
   `nothing_is_enforced_until_its_report_is_read`. The plan shows only that policy's state changing.
4. Merge, approve the apply, then sign in again in a private window to confirm you are not locked out.

## If a policy locks you out

1. Sign in with a break-glass account (`entra/break-glass/README.md`). Every policy excludes it.
2. Set the policy to report-only in the portal.
3. Remove it from `local.enforced` in a pull request. The next plan shows the portal change as drift
   until then.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `No break-glass exclusion group from lab-entra-l0-privileged-prd` | Level 0 privileged has not been applied, or its output is missing | Apply it (`docs/runbooks/entra-privileged.md`) |
| `Unsupported attribute` on `persona_group_ids` | Level 0 org has not been applied | Run the `entra-l0-org` workflow |
| `403` or `Authorization_RequestDenied` on apply | The identity lost a Graph permission | Check `entra/bootstrap/graph.yaml` and run the Entra bootstrap |
| Enforcing fails with a security defaults error | Security defaults are still on | Step 2 above |
| CA007 or CA008 never reports a result | No P2 licence, or no risky sign-ins | Check licences; risk is rare in a lab |
