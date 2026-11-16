# One-off. Azure created the gateway diagnostic before level 3 first applied it (PR #40), so it is
# imported here, in a reviewed plan, rather than with the CLI. Remove this file and
# adopt_gateway_diagnostic in the next level 3 change: on a fresh build there is nothing to import.
import {
  for_each = var.enable_apim && var.adopt_gateway_diagnostic ? toset(["azuremonitor"]) : toset([])

  to = azurerm_api_management_diagnostic.azuremonitor[0]
  id = "${data.azurerm_resource_group.aiservices.id}/providers/Microsoft.ApiManagement/service/${local.apim_name}/diagnostics/azuremonitor"
}
