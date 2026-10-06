locals {
  cluster_name = coalesce(var.cluster_name, format(
    "%s-%s",
    replace(substr(local.platform_identifier, 0, 6), "/-+$/", ""),
    substr(sha256(local.platform_identifier), 0, 4)
  ))

  # It's fine that by default, Let's Encrypt Expiry notifications go nowhere.
  cluster_issuer_email = coalesce(var.cluster_issuer_email, local.platform_service_account_email)

  dns_subdomain = trimspace(var.dns_subdomain == null ? "" : var.dns_subdomain) != "" ? lower(var.dns_subdomain) : lower(local.platform_identifier)
}

# The stackit provider rejects a service account email that is unknown while planning, so this run
# cannot act as the account it creates. The nested definition is ordered with the email as a known
# input instead, and so acts as the account from its first run.
module "platform_integration" {
  source = "github.com/meshcloud/meshstack-hub//reference-architectures/stackit-kubernetes/platform?ref=${var.hub.git_ref}"

  approval_policies            = var.approval_policies
  starterkit_approval_policies = var.starterkit_approval_policies

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

resource "meshstack_building_block" "platform" {
  wait_for_completion = true

  # meshStack fills the USER_PERMISSIONS inputs of the Git and registry blocks from the project's
  # members when their runs start, so the admins have to be members before the nested run.
  depends_on = [meshstack_project_user_binding.admin]

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.bootstrap_federation.ref]
    building_block_definition_version_ref = module.platform_integration.building_block_definition.version_ref
    display_name                          = "Platform Services"
    target_ref                            = module.tenant.tenant.ref

    inputs = merge({
      STACKIT_SERVICE_ACCOUNT_EMAIL = { value = jsonencode(local.platform_service_account_email) }
      automation_identity = { value = jsonencode(jsonencode({
        building_block_ref    = meshstack_building_block.platform_service_account.ref
        service_account_email = local.platform_service_account_email
        service_account_id    = local.platform_service_account_id
      })) }
      service_account_federation_bbd_version_ref = { value = jsonencode(jsonencode(var.landingzone.service_account_federation_bbd_version_ref)) }

      platform_identifier  = { value = jsonencode(local.platform_identifier) }
      playground_mode      = { value = jsonencode(var.playground_mode) }
      use_global_location  = { value = jsonencode(var.use_global_location) }
      cluster_name         = { value = jsonencode(local.cluster_name) }
      cluster_issuer_email = { value = jsonencode(local.cluster_issuer_email) }
      harbor_username      = { value = jsonencode(var.harbor_username == null ? "" : var.harbor_username) }
      dns_subdomain        = { value = jsonencode(local.dns_subdomain) }
      dns_parent_domain    = { value = jsonencode(var.dns_parent_domain) }
      ai_model             = { value = jsonencode(var.ai_model) }

      starterkit_app_name        = { value = jsonencode(var.starterkit_app_name) }
      starterkit_repo_clone_addr = { value = jsonencode(var.starterkit_repo_clone_addr) }

      tags = { value = jsonencode(jsonencode({
        landingzone           = var.tags.landingzone
        building_block        = var.tags.building_block
        starterkit_project    = var.tags.starterkit_project
        project_owner_tag_key = var.tags.project_owner_tag_key
      })) }
      stages = { value = jsonencode(jsonencode(var.stages)) }
      }, local.imports.ske == null && local.imports.git == null ? {} : {
      imports = { value = jsonencode(jsonencode({ ske = local.imports.ske, git = local.imports.git })) }
      }, var.existing == null ? {} : {
      existing = { value = jsonencode(jsonencode(var.existing)) }
      }, nonsensitive(length(var.import_secrets)) == 0 ? {} : {
      import_secrets = {
        sensitive = {
          secret_value   = jsonencode(var.import_secrets)
          secret_version = nonsensitive(sha256(jsonencode(var.import_secrets)))
        }
      }
    })
  }
}
