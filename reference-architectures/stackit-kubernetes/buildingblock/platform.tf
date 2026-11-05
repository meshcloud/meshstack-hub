locals {
  cluster_name = coalesce(local.overrides.cluster_name, format(
    "%s-%s",
    replace(substr(local.platform_identifier, 0, 6), "/-+$/", ""),
    substr(sha256(local.platform_identifier), 0, 4)
  ))

  # It's fine that by default, Let's Encrypt Expiry notifications go nowhere.
  cluster_issuer_email = coalesce(local.overrides.cluster_issuer_email, local.platform_service_account_email)

  # STACKIT allows a single label under its free domains.
  dns_domain_labels = regex("^(?:([a-z0-9-]+)\\.)?(stackit\\.(?:run|zone|rocks|gg)|runs\\.onstackit\\.cloud)$", local.dns_domain)
  dns_subdomain     = lower(coalesce(local.dns_domain_labels[0], local.platform_identifier))
}

# The stackit provider rejects a service account email that is unknown while planning, so this run
# cannot act as the account it creates. The nested definition gets the email as a known input and
# acts as the account from its first run.
module "platform_integration" {
  source = "github.com/meshcloud/meshstack-hub//reference-architectures/stackit-kubernetes/platform?ref=${var.hub.git_ref}"

  approval_policies            = local.approval_policies
  starterkit_approval_policies = local.starterkit_approval_policies

  starterkit_add_random_name_suffix = local.starterkit_add_random_name_suffix

  meshstack = { owning_workspace_identifier = var.workspace, tags = local.tag_maps.building_block }
  hub       = var.hub
}

resource "meshstack_building_block" "platform" {
  wait_for_completion = true

  # meshStack fills the USER_PERMISSIONS inputs of the Git and registry blocks from the project's
  # members when their runs start, so the admins have to be members before the nested run.
  depends_on = [module.project_admin_bindings]

  lifecycle {
    postcondition {
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.bootstrap_federation.ref]
    building_block_definition_version_ref = module.platform_integration.building_block_definition.version_ref
    display_name                          = "Platform Services"
    target_ref                            = module.tenant.tenant.ref

    inputs = {
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
      dns_subdomain        = { value = jsonencode(local.dns_subdomain) }
      dns_parent_domain    = { value = jsonencode(local.dns_domain_labels[1]) }
      phase2_completed     = { value = jsonencode(var.phase2_completed) }

      starterkit_app_name        = { value = jsonencode(var.starterkit_demo.name) }
      starterkit_repo_clone_addr = { value = jsonencode(var.starterkit_demo.template_repo) }
      ai_model                   = { value = jsonencode(var.starterkit_demo.ai_model) }

      tags = { value = jsonencode(jsonencode({
        landingzone               = local.tag_maps.landingzone
        building_block            = local.tag_maps.building_block
        starterkit_building_block = local.tag_maps.starterkit_building_block
        starterkit_project        = local.tag_maps.starterkit_project
        project_owner_tag_key     = var.tags.project_owner_tag_key
      })) }
      stages            = { value = jsonencode(jsonencode(local.stages)) }
      quota_definitions = { value = jsonencode(jsonencode(var.quota_definitions)) }
      imports           = { value = jsonencode(jsonencode(length(local.platform_imports) == 0 ? null : local.platform_imports)) }
    }
  }
}
