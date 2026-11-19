# Countries sign-ins are expected from. CA003 blocks the rest. Unknown countries are not trusted, so an
# address that cannot be placed is blocked too.
resource "azuread_named_location" "trusted_countries" {
  display_name = "${var.prefix}-nl-trusted-countries"

  country {
    countries_and_regions                 = var.trusted_countries
    include_unknown_countries_and_regions = false
    country_lookup_method                 = "clientIpAddress"
  }
}
