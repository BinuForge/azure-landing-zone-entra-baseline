# Entra level 1, governance

`entra/level-1-governance` sets the tenant's defaults: user and guest permissions, consent, authentication
methods and default cross-tenant access (ADR-0018). It runs like the Azure levels: a pull request plans
with `lab-entra-l1-governance-plan`, a merge plans again and waits for approval in
`lab-entra-l1-governance-apply`.

## Before the first apply

SMS and voice are switched off. Anyone who has only those registered can no longer complete MFA. Before
approving the apply, check each of these has Microsoft Authenticator or a passkey registered: the daily
admin and both break-glass accounts.

Entra admin centre, Users, open the user, Authentication methods. If one has only a phone method,
register Authenticator for it first, or issue a Temporary Access Pass after the apply and register a
passkey with it.

## Reverting a setting

Every resource here updates a tenant setting that always exists. Deleting the resource leaves the setting
as it is. To revert, change the value in code and apply, then remove the resource if it is no longer
wanted.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `400` on `fido2` mentioning `passkeyProfiles` | The tenant read as having profiles but rejected them | Check `terraform output passkey_profiles_in_use`; re-run the plan so it reads the tenant again |
| `403` on apply | The identity lost a Graph permission | Check `entra/bootstrap/graph.yaml` and run the Entra bootstrap |
| Plan shows a change nobody made | Someone changed the setting in the portal | Apply to restore it, or change the code if the portal change was right |
| A user cannot add an app | User consent is off | An admin grants consent in Enterprise applications |
