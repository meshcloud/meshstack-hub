data "meshstack_building_block_definitions" "federated" {
  workspace_identifier = var.workspace_identifier
  uuids                = var.federated_building_block_definitions
}

locals {
  # Hub modules order a definition's version_latest, so runs present its identity.
  federated_identities = {
    for definition in data.meshstack_building_block_definitions.federated.building_block_definitions :
    definition.metadata.uuid => definition.version_latest.workload_identity_federation
  }
}

# The service account block owns this grant, so an older state must not delete it.
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
  for_each   = toset(var.federated_building_block_definitions)
  depends_on = [terraform_data.federation_access]

  lifecycle {
    precondition {
      # try() turns every missing step of the lookup into null, so one comparison covers them all.
      condition     = try(local.federated_identities[each.key].azure.audience, null) != null
      error_message = "Building block definition ${each.key} must be owned by workspace ${var.workspace_identifier} and run on a runner whose workload identity federation includes an Azure audience."
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
