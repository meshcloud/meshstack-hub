data "meshstack_integrations" "this" {}

locals {
  wif_issuer         = data.meshstack_integrations.this.workload_identity_federation.replicator.issuer
  wif_subject_prefix = trimsuffix(data.meshstack_integrations.this.workload_identity_federation.replicator.subject, ":replicator")
  wif_audience       = data.meshstack_integrations.this.workload_identity_federation.replicator.azure.audience

  federated_subjects = {
    for uuid in var.federated_building_block_definitions :
    uuid => "${local.wif_subject_prefix}:workspace.${var.workspace_identifier}.buildingblockdefinition.${uuid}"
  }
}

# At project scope the narrowest roles that carry `iam.service-account-federation.create` are `editor`
# and `project.member`. The backplane's organization-wide `iam.member-admin` lets it assign itself one,
# on this project only.
resource "stackit_authorization_project_role_assignment" "federation_admin" {
  resource_id = var.project_id
  role        = "editor"
  subject     = var.automation_service_account_email
}

# The assignment above is applied asynchronously, so the federation calls have to wait until it is in
# effect, not only run after it.
resource "terraform_data" "federation_access" {
  triggers_replace = [
    stackit_authorization_project_role_assignment.federation_admin.id,
    var.service_account_email,
  ]

  provisioner "local-exec" {
    command = "${path.module}/wait-for-federation-access.sh"

    environment = {
      PROJECT_ID                   = var.project_id
      TARGET_SERVICE_ACCOUNT_EMAIL = var.service_account_email
    }
  }
}

resource "stackit_service_account_federated_identity_provider" "this" {
  for_each   = local.federated_subjects
  depends_on = [terraform_data.federation_access]

  project_id            = var.project_id
  service_account_email = var.service_account_email
  name                  = "meshstack-${substr(each.key, 0, 8)}"
  issuer                = local.wif_issuer

  assertions = [
    {
      item     = "aud"
      operator = "equals"
      value    = local.wif_audience
    },
    {
      item     = "sub"
      operator = "equals"
      value    = each.value
    }
  ]
}
