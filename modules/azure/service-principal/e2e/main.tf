variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    run_id      = string

    fixtures = object({
      azure = object({
        subscription_uuid = string
        entra_tenant_id   = string
      })
    })
  })

  nullable = false
}

locals {
  azure_scope = "/subscriptions/${var.test_context.fixtures.azure.subscription_uuid}"

  # Reused verbatim in the Azure custom role definition name ("<name>-deploy", unique per scope) and
  # in the backplane app registration display name ("<name>-<name>").
  backplane_name = "${var.test_context.run_id}-sp-bp"

  # Display name of the Entra application/service principal the building block creates.
  application_display_name = "${var.test_context.run_id}-service-principal"
}

module "service_principal" {
  source = "../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }

  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  bbd_display_name = "${var.test_context.run_id} Azure Service Principal"

  azure_tenant_id       = var.test_context.fixtures.azure.entra_tenant_id
  azure_subscription_id = var.test_context.fixtures.azure.subscription_uuid
  azure_scope           = local.azure_scope
  azure_location        = "westeurope"

  backplane_name = local.backplane_name
}

resource "meshstack_building_block" "this" {
  # Depend on the entire backplane to force correct resource ordering at the module boundary, not
  # just on individual backplane resources. Without this the WIF federated identity credential is
  # destroyed in parallel with the building block delete run, which then fails to authenticate.
  depends_on = [module.service_principal]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.service_principal.building_block_definition.version_ref

    display_name = "${var.test_context.run_id}-service-principal"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      display_name = { value = jsonencode(local.application_display_name) }

      # Set explicitly rather than relying on the BBD's default_value: the buildingblock defaults
      # azure_role to null, so if a default_value is only a form pre-fill and is not applied when
      # ordering through the API, no role assignment happens and the role_name assertion below
      # would be testing the default rather than the role assignment path.
      azure_role           = { value = jsonencode("Contributor") }
      create_client_secret = { value = jsonencode(true) }
    }
  }
}
