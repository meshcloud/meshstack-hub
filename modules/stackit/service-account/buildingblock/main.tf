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

resource "stackit_service_account" "this" {
  project_id = var.project_id
  name       = var.service_account_name
}

resource "stackit_authorization_project_role_assignment" "this" {
  for_each = toset(var.roles)

  resource_id = var.project_id
  role        = each.value
  subject     = stackit_service_account.this.email
}

# `iam.service-account-federation.create` is the one permission this run needs that its backplane
# identity cannot hold up front. At organization scope only `owner`, `organization.owner` and
# `organization.admin` carry it, and all three are 952-permission roles — far too broad to grant a
# self-service automation identity. At project scope the narrowest roles that carry it are `editor`
# and `project.member` (844 permissions each). The backplane holds `iam.member-admin` organization
# wide, so it is already entitled to assign any project role to anyone; this makes it assign itself
# the one it needs, on this project only. All role contents read from the live authorization API.
resource "stackit_authorization_project_role_assignment" "federation_admin" {
  lifecycle {
    enabled = length(local.federated_subjects) > 0
  }

  resource_id = var.project_id
  role        = "editor"
  subject     = var.automation_service_account_email
}

# The assignment above is applied asynchronously, so it is not enough to order the federation calls
# after it — they have to wait until it is in effect. The script polls the federations collection
# itself rather than sleeping for a guessed duration; see its header for why that probe is exact.
resource "terraform_data" "federation_access" {
  lifecycle {
    enabled = length(local.federated_subjects) > 0
  }

  triggers_replace = [
    stackit_authorization_project_role_assignment.federation_admin.id,
    stackit_service_account.this.email,
  ]

  provisioner "local-exec" {
    command = "${path.module}/wait-for-federation-access.sh"

    environment = {
      PROJECT_ID                   = var.project_id
      TARGET_SERVICE_ACCOUNT_EMAIL = stackit_service_account.this.email
    }
  }
}

resource "stackit_service_account_federated_identity_provider" "this" {
  for_each   = local.federated_subjects
  depends_on = [terraform_data.federation_access]

  project_id            = var.project_id
  service_account_email = stackit_service_account.this.email
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
