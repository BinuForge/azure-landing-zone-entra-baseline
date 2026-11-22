# Admin consent requests (ADR-0018, ADR-0019). Users consent to nothing, so they ask instead. Reviewers are
# the members of lab-grp-role-cloudappadmin, a role-assignable group eligible for Cloud Application
# Administrator through PIM: no person is named here, and reviewing grants nothing until they activate.
data "tfe_outputs" "privileged" {
  workspace = "${var.prefix}-entra-l0-privileged-prd"
}

locals {
  # Null until pim/Set-Pim.ps1 has created the group and level 0 privileged has published it. The policy
  # waits for it rather than enabling requests nobody can review.
  consent_reviewer_group = try(data.tfe_outputs.privileged.nonsensitive_values.cloudapp_admin_group_id, null)
}

resource "msgraph_update_resource" "admin_consent" {
  count = local.consent_reviewer_group == null ? 0 : 1

  url           = "policies/adminConsentRequestPolicy"
  update_method = "PUT" # The API takes PUT only, so the whole policy is sent

  body = {
    isEnabled             = true
    notifyReviewers       = true
    remindersEnabled      = true
    requestDurationInDays = 14
    reviewers = [{
      # Written as Graph stores it; any other form shows as a change on every plan.
      query     = "/v1.0/groups/${local.consent_reviewer_group}/transitiveMembers/microsoft.graph.user"
      queryType = "MicrosoftGraph"
      queryRoot = null
    }]
  }
}
