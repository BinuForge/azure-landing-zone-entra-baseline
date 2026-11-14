locals {
  # Three alerts on actual spend and one on forecast, so a runaway resource is caught before the month ends.
  budget_alerts = {
    actual-50    = { threshold = 50, type = "Actual" }
    actual-80    = { threshold = 80, type = "Actual" }
    actual-100   = { threshold = 100, type = "Actual" }
    forecast-100 = { threshold = 100, type = "Forecasted" }
  }
}

# Lives in bootstrap so no destroy workflow can remove it.
resource "azurerm_consumption_budget_subscription" "monthly" {
  name            = "${var.prefix}-budget-monthly"
  subscription_id = "/subscriptions/${var.subscription_id}"
  amount          = var.budget_amount
  time_grain      = "Monthly"

  time_period {
    start_date = var.budget_start_date
  }

  dynamic "notification" {
    for_each = local.budget_alerts

    content {
      enabled        = true
      operator       = "GreaterThan"
      threshold      = notification.value.threshold
      threshold_type = notification.value.type
      contact_emails = var.budget_contact_emails
    }
  }
}
