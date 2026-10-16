data "meshstack_building_block_definitions" "federated" {
  workspace_identifier = var.workspace_identifier
}

locals {
  # Composing architectures order released versions, so the latest release decides. A definition that
  # has none yet is trusted as its latest draft.
  federated_identities = {
    for definition in data.meshstack_building_block_definitions.federated.building_block_definitions :
    definition.metadata.uuid => (
      definition.version_latest_release != null
      ? definition.version_latest_release.workload_identity_federation
      : definition.version_latest.workload_identity_federation
    )
    if contains(var.federated_building_block_definitions, definition.metadata.uuid)
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
  for_each   = toset(var.federated_building_block_definitions)
  depends_on = [terraform_data.federation_access]

  lifecycle {
    precondition {
      condition     = try(local.federated_identities[each.key].azure.audience, null) != null
      error_message = "Building block definition ${each.key} is not owned by workspace ${var.workspace_identifier}, or meshStack resolves no workload identity with an Azure audience for it. Check the uuid, and that the definition's runner declares workload identity federation."
    }
  }

  project_id            = var.project_id
  service_account_email = var.service_account_email
  name                  = "meshstack-${substr(each.key, 0, 8)}"
  issuer                = local.federated_identities[each.key].issuer

  assertions = [
    {
      item     = "aud"
      operator = "equals"
      value    = local.federated_identities[each.key].azure.audience
    },
    {
      item     = "sub"
      operator = "equals"
      value    = local.federated_identities[each.key].subject
    }
  ]
}
