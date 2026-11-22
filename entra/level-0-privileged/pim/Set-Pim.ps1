#Requires -Version 7.2
#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Applies pim.json: activation rules, the maintainer's eligible roles, and the role-assignable group.

.DESCRIPTION
    PIM needs role management scopes that the Azure CLI token used by Terraform cannot carry, and no
    pipeline may hold them (ADR-0016). So the maintainer applies PIM with a delegated Microsoft Graph token,
    signed in as themselves, and level-0-privileged checks the result on every plan (ADR-0019).

    Run -Plan first. It prints what would change and changes nothing. Every step is idempotent.

    -RemoveStandingAccess removes the maintainer's permanent active assignments to the roles in pim.json,
    after checking the maintainer is eligible for Global Administrator and both break-glass accounts still
    hold it. Afterwards, activate Global Administrator in PIM before any Tier 0 run.

.EXAMPLE
    ./Set-Pim.ps1 -Plan
    ./Set-Pim.ps1
    ./Set-Pim.ps1 -RemoveStandingAccess
#>
[CmdletBinding()]
param(
    [switch] $Plan,
    [switch] $RemoveStandingAccess,
    [string] $Prefix = 'lab'
)

$ErrorActionPreference = 'Stop'
$config = Get-Content -Raw -Path (Join-Path $PSScriptRoot 'pim.json') | ConvertFrom-Json -AsHashtable
$graph = 'https://graph.microsoft.com/v1.0'
$justification = 'pim.json, ADR-0019'

function Get-Graph([string] $Path) {
    (Invoke-MgGraphRequest -Method GET -Uri "$graph/$Path").value
}

function Invoke-Change([string] $What, [scriptblock] $Action) {
    if ($Plan) { Write-Host "  would: $What" -ForegroundColor Yellow; return }
    Write-Host "  doing: $What" -ForegroundColor Cyan
    & $Action
}

function Get-Filter([string] $Filter) { [uri]::EscapeDataString($Filter) }

# Bodies are serialised here so nested objects (targets, schedules) keep their depth.
function Send-Graph([string] $Method, [string] $Path, [hashtable] $Body) {
    Invoke-MgGraphRequest -Method $Method -Uri "$graph/$Path" -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 10)
}

# Delegated scopes for this run only. At the consent prompt, do not tick "Consent on behalf of your
# organisation": the grant should be yours alone.
Connect-MgGraph -NoWelcome -Scopes @(
    'RoleManagement.ReadWrite.Directory',
    'RoleManagementPolicy.ReadWrite.Directory',
    'RoleEligibilitySchedule.ReadWrite.Directory',
    'RoleAssignmentSchedule.ReadWrite.Directory',
    'Group.ReadWrite.All',
    'User.Read.All'
)

$me = Invoke-MgGraphRequest -Method GET -Uri "$graph/me?`$select=id,mailNickname"
if ($me.mailNickname -like "$Prefix-emergency-*") { throw 'Signed in as a break-glass account. Sign in as the maintainer.' }
Write-Host "Maintainer: $($me.mailNickname)"

# Role-assignable groups first, so they can be made eligible below.
$groupIds = @{}
foreach ($name in $config.groups.Keys) {
    $spec = $config.groups[$name]
    Write-Host "Group $name"
    $group = Get-Graph "groups?`$filter=$(Get-Filter "displayName eq '$name'")&`$select=id,isAssignableToRole" | Select-Object -First 1
    if (-not $group) {
        Invoke-Change "create role-assignable group $name" {
            $script:group = Send-Graph POST "groups" @{
                displayName        = $name
                description        = $spec.description
                mailEnabled        = $false
                mailNickname       = $name
                securityEnabled    = $true
                isAssignableToRole = $true
            }
        }
    }
    elseif (-not $group.isAssignableToRole) { throw "$name exists but is not role-assignable. Rename or delete it by hand." }
    $groupIds[$name] = $group.id

    if ($group.id) {
        $members = @(Get-Graph "groups/$($group.id)/members?`$select=id" | ForEach-Object { $_.id })
        if ($spec.members -contains 'maintainer' -and $members -notcontains $me.id) {
            Invoke-Change "add the maintainer to $name" {
                Send-Graph POST "groups/$($group.id)/members/`$ref" @{
                    '@odata.id' = "$graph/directoryObjects/$($me.id)"
                }
            }
        }
    }
}

foreach ($roleName in $config.roles.Keys) {
    $role = $config.roles[$roleName]
    Write-Host "Role $roleName"

    # Activation and eligibility rules on the role's PIM policy.
    $filter = Get-Filter "scopeId eq '/' and scopeType eq 'DirectoryRole' and roleDefinitionId eq '$($role.id)'"
    $assignment = Get-Graph "policies/roleManagementPolicyAssignments?`$filter=$filter&`$expand=policy(`$expand=rules)" | Select-Object -First 1
    $policyId = $assignment.policyId
    $rules = @{}
    $assignment.policy.rules | ForEach-Object { $rules[$_.id] = $_ }

    $wanted = @{
        'Expiration_EndUser_Assignment' = @{
            '@odata.type'        = '#microsoft.graph.unifiedRoleManagementPolicyExpirationRule'
            isExpirationRequired = $true
            maximumDuration      = $role.maximumActivation
        }
        'Enablement_EndUser_Assignment' = @{
            '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyEnablementRule'
            enabledRules  = $config.activationRules
        }
        'Expiration_Admin_Eligibility'  = @{
            '@odata.type'        = '#microsoft.graph.unifiedRoleManagementPolicyExpirationRule'
            isExpirationRequired = $true
            maximumDuration      = $config.eligibilityDuration
        }
    }
    foreach ($ruleId in $wanted.Keys) {
        $current = $rules[$ruleId]
        $body = $wanted[$ruleId]
        $same = switch ($ruleId) {
            'Enablement_EndUser_Assignment' { -not (Compare-Object @($current.enabledRules) @($body.enabledRules)) }
            default { $current.isExpirationRequired -eq $body.isExpirationRequired -and $current.maximumDuration -eq $body.maximumDuration }
        }
        if (-not $same) {
            Invoke-Change "set $ruleId" {
                $body.id = $ruleId
                $body.target = $current.target
                Send-Graph PATCH "policies/roleManagementPolicies/$policyId/rules/$ruleId" $body | Out-Null
            }
        }
    }

    # The eligible principal: the maintainer, or a group from pim.json.
    $principalId = if ($role.eligible -eq 'maintainer') { $me.id } else { $groupIds[$role.eligible] }
    if (-not $principalId) { Write-Host "  would: make $($role.eligible) eligible, once it exists" -ForegroundColor Yellow; continue }
    $filter = Get-Filter "principalId eq '$principalId' and roleDefinitionId eq '$($role.id)'"
    if (-not (Get-Graph "roleManagement/directory/roleEligibilitySchedules?`$filter=$filter")) {
        Invoke-Change "make $($role.eligible) eligible for $($config.eligibilityDuration)" {
            Send-Graph POST "roleManagement/directory/roleEligibilityScheduleRequests" @{
                action           = 'adminAssign'
                justification    = $justification
                roleDefinitionId = $role.id
                directoryScopeId = '/'
                principalId      = $principalId
                scheduleInfo     = @{
                    startDateTime = (Get-Date).ToUniversalTime().ToString('o')
                    expiration    = @{ type = 'afterDuration'; duration = $config.eligibilityDuration }
                }
            } | Out-Null
        }
    }
}

if ($RemoveStandingAccess) {
    Write-Host 'Standing access'
    $ga = $config.roles['Global Administrator'].id
    $filter = Get-Filter "principalId eq '$($me.id)' and roleDefinitionId eq '$ga'"
    if (-not (Get-Graph "roleManagement/directory/roleEligibilitySchedules?`$filter=$filter")) {
        throw 'The maintainer is not yet eligible for Global Administrator. Run without -RemoveStandingAccess first.'
    }
    $gaMembers = Get-Graph "directoryRoles(roleTemplateId='$ga')/members?`$select=id,mailNickname"
    $breakglass = @($gaMembers | Where-Object { $_.mailNickname -like "$Prefix-emergency-*" })
    if ($breakglass.Count -ne 2) { throw "Expected two break-glass Global Administrators, found $($breakglass.Count). Stopping." }

    foreach ($roleName in $config.roles.Keys) {
        $roleId = $config.roles[$roleName].id
        $filter = Get-Filter "principalId eq '$($me.id)' and roleDefinitionId eq '$roleId'"
        $standing = Get-Graph "roleManagement/directory/roleAssignmentSchedules?`$filter=$filter" |
            Where-Object { $_.assignmentType -eq 'Assigned' -and $_.memberType -eq 'Direct' }
        if ($standing) {
            if (-not $Plan -and (Read-Host "Remove your standing $roleName? Type REMOVE") -ne 'REMOVE') { continue }
            Invoke-Change "remove the maintainer's standing $roleName" {
                Send-Graph POST "roleManagement/directory/roleAssignmentScheduleRequests" @{
                    action           = 'adminRemove'
                    justification    = $justification
                    roleDefinitionId = $roleId
                    directoryScopeId = '/'
                    principalId      = $me.id
                } | Out-Null
            }
        }
    }
}

Write-Host ($Plan ? 'Plan only: nothing changed.' : 'Done. Run the level-0-privileged plan to check.')
Disconnect-MgGraph | Out-Null
