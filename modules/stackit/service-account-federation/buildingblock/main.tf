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

# The service account block owns this grant now, so an older state must not delete it.
removed {
  from = stackit_authorization_project_role_assignment.federation_admin

  lifecycle {
    destroy = false
  }
}

# The service account block grants `editor` asynchronously, possibly just before this run starts.
resource "terraform_data" "federation_access" {
  triggers_replace = [var.service_account_email]

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
