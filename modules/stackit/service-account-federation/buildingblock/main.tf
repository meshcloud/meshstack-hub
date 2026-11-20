data "meshstack_building_block_definition" "federated" {
  for_each = toset(var.federated_building_block_definitions)

  metadata = {
    uuid               = each.key
    owned_by_workspace = var.workspace_identifier
  }

  lifecycle {
    postcondition {
      condition = alltrue([
        # try() turns every missing step of the lookup into null, so one comparison covers them all.
        for version in [self.version_latest, self.version_latest_release] : version == null || try(version.workload_identity_federation.azure.audience, null) != null
      ])
      error_message = "The latest and latest released versions of building block definition ${each.key} must run on a runner whose workload identity federation includes an Azure audience."
    }
  }
}

locals {
  # A block keeps running on the version it was created with, so a released version and a newer one
  # on another runner present different identities.
  federated_identities = {
    for identity in distinct(flatten([
      for uuid, definition in data.meshstack_building_block_definition.federated : [
        for version in [definition.version_latest, definition.version_latest_release] : {
          definition_uuid = uuid
          issuer          = version.workload_identity_federation.issuer
          subject         = version.workload_identity_federation.subject
          audience        = version.workload_identity_federation.azure.audience
        } if version != null
      ]
    ])) : "meshstack-${substr(identity.definition_uuid, 0, 8)}-${substr(sha256(join(" ", [identity.issuer, identity.subject, identity.audience])), 0, 8)}" => identity
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
  for_each   = local.federated_identities
  depends_on = [terraform_data.federation_access]

  project_id            = var.project_id
  service_account_email = var.service_account_email
  name                  = each.key
  issuer                = each.value.issuer

  assertions = [
    {
      item     = "aud"
      operator = "equals"
      value    = each.value.audience
    },
    {
      item     = "sub"
      operator = "equals"
      value    = each.value.subject
    }
  ]
}
