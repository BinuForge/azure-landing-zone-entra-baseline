# Runs with mock providers: no sign-in, no network calls, nothing created. ADR-0016, decision 6.
mock_provider "azurerm" {
  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock"
    }
  }
}

mock_provider "azuread" {
  mock_data "azuread_client_config" {
    defaults = {
      object_id = "00000000-0000-0000-0000-000000000001"
      tenant_id = "00000000-0000-0000-0000-000000000002"
    }
  }
}

mock_provider "github" {
  mock_data "github_user" {
    defaults = {
      id = "12345"
    }
  }
}

mock_provider "azapi" {
  mock_data "azapi_resource" {
    defaults = {
      output = { properties = { defaultManagementGroup = "lab-mg-sandbox" } }
    }
  }
}

# A known workspace ID at plan time, so a test can check where the diagnostic setting sends logs.
override_resource {
  target          = azurerm_log_analytics_workspace.security
  override_during = plan
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab-rg-bootstrap-prd-ae/providers/Microsoft.OperationalInsights/workspaces/lab-log-security-prd-ae"
  }
}

variables {
  subscription_id            = "00000000-0000-0000-0000-000000000000"
  budget_contact_emails      = ["alerts@example.com"]
  github_oidc_subject_prefix = "repo:example@1/repo@2"
  hcp_organization           = "example-org"
}

run "entra_logs_go_to_a_workspace_only_the_maintainer_reads" {
  command = plan

  assert {
    condition = (
      azurerm_log_analytics_workspace.security.resource_group_name == "lab-rg-bootstrap-prd-ae" &&
      azurerm_log_analytics_workspace.security.local_authentication_enabled == false &&
      azurerm_log_analytics_workspace.security.allow_resource_only_permissions == false
    )
    error_message = "The security workspace lives in bootstrap's group, with shared keys and resource-context access off."
  }

  # Roles at the root and subscription reach bootstrap's group too. The custom ones read no logs
  # (rbac_github.tftest.hcl), and Management Group Contributor acts on management groups only.
  assert {
    condition = alltrue([
      for k, a in local.role_assignments :
      split("/", k)[2] != "bootstrap" && (!contains(["root", "subscription"], split("/", k)[2]) || startswith(a.role, "custom:") || a.role == "Management Group Contributor")
    ])
    error_message = "No pipeline identity may hold a role that can read logs in bootstrap's group."
  }

  assert {
    condition     = length(azurerm_monitor_aad_diagnostic_setting.entra) == 0
    error_message = "Entra diagnostics stay off until the tenant has Entra ID P1 or P2."
  }
}

run "entra_diagnostics_send_sign_ins_and_audit_to_the_security_workspace" {
  command = plan

  variables {
    entra_diagnostics = true
  }

  assert {
    condition = (
      azurerm_monitor_aad_diagnostic_setting.entra[0].log_analytics_workspace_id == azurerm_log_analytics_workspace.security.id &&
      length(setintersection(toset([for l in azurerm_monitor_aad_diagnostic_setting.entra[0].enabled_log : l.category]), toset(["AuditLogs", "SignInLogs", "ServicePrincipalSignInLogs"]))) == 3
    )
    error_message = "Entra audit and sign-in logs, including service principal sign-ins, go to the security workspace."
  }
}
