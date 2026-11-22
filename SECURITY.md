# Security policy

This is a personal lab. It holds no production data, and the lab tenant is torn down and rebuilt between
sessions. Reports are still welcome, because the patterns here are meant to be copied.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting:
<https://github.com/BinuForge/azure-landing-zone-entra-baseline/security/advisories/new>
(the Security tab of this repository, then "Report a vulnerability"). Please do not open a public issue
for a security problem.

Useful reports include:

- a way for a pull request, fork or workflow to obtain a cloud identity or a secret;
- a pipeline identity, Graph permission or role that grants more than its ADR says;
- a test, check or policy that passes when the control it proves is broken;
- an identifier, tenant detail or credential committed to the repository.

You should hear back within seven days.

## Scope

In scope: the Terraform, workflows, scripts, tests and documentation in this repository.

Out of scope: Microsoft, HashiCorp and GitHub services themselves, and denial of service against the lab.

## What is never in this repository

Tenant, subscription and object IDs, domains, credentials and personal data. Identifiers live in
git-ignored `env/*.auto.tfvars` files or in GitHub environment secrets, because Actions prints variable
values in public logs (ADR-0012).
