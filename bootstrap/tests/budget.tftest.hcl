# Runs with a mock provider: no Azure login, no network calls, nothing created.
mock_provider "azurerm" {}

variables {
  subscription_id       = "00000000-0000-0000-0000-000000000000"
  budget_contact_emails = ["alerts@example.com"]
}

run "budget_alerts_on_actual_and_forecast" {
  command = plan

  assert {
    condition     = length(azurerm_consumption_budget_subscription.monthly.notification) == 4
    error_message = "The budget must have four alerts."
  }

  assert {
    condition     = contains([for n in azurerm_consumption_budget_subscription.monthly.notification : n.threshold_type], "Forecasted")
    error_message = "One alert must be on forecast spend, so a runaway resource is caught early."
  }

  assert {
    condition     = alltrue([for n in azurerm_consumption_budget_subscription.monthly.notification : n.enabled])
    error_message = "Every alert must be enabled."
  }
}

run "budget_is_monthly_and_follows_naming" {
  command = plan

  assert {
    condition     = azurerm_consumption_budget_subscription.monthly.time_grain == "Monthly"
    error_message = "The budget must reset monthly."
  }

  assert {
    condition     = azurerm_consumption_budget_subscription.monthly.name == "lab-budget-monthly"
    error_message = "The budget name must follow docs/naming.md."
  }
}

run "budget_needs_a_contact" {
  command = plan

  variables {
    budget_contact_emails = []
  }

  expect_failures = [var.budget_contact_emails]
}

run "budget_start_must_be_first_of_month" {
  command = plan

  variables {
    budget_start_date = "2026-11-14T00:00:00Z"
  }

  expect_failures = [var.budget_start_date]
}
