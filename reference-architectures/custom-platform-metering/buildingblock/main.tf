locals {
  # meshStack writes kubeconfig.yaml from the FILE input at run time. The committed mock lets the
  # module validate without it, and a precondition stops an apply against the mock.
  kubeconfig_path    = fileexists("${path.module}/kubeconfig.yaml") ? "${path.module}/kubeconfig.yaml" : "${path.module}/kubeconfig-mock.yaml"
  kubeconfig_cluster = one(yamldecode(file(local.kubeconfig_path)).clusters)

  # The provider reads a ref without a uuid as unknown, not as the shared runner.
  runner_ref = var.runner_ref.uuid == null ? null : var.runner_ref

  meshstack = {
    owning_workspace_identifier = var.workspace
    runner_ref                  = local.runner_ref
  }

  # Keyed by the cloud name on the Platform Metering order form, which also names each metering
  # building block.
  metering_definitions = merge(
    var.stackit_enabled ? { STACKIT = module.stackit_metering[0].building_block_definition } : {},
    var.tcloud_enabled ? { "T Cloud" = module.tcloud_metering[0].building_block_definition } : {},
  )
}

# The filter matches the full `<platform>.<location>` identifier; `one()` fails loudly if it stops
# matching exactly one platform.
data "meshstack_platforms" "kubernetes" {
  identifier = var.kubernetes.platform_identifier

  lifecycle {
    precondition {
      condition     = local.kubeconfig_cluster.cluster.server != "https://example.invalid"
      error_message = "kubeconfig.yaml is missing, so this run would use the mock kubeconfig. Upload the admin kubeconfig of the cluster."
    }
  }
}

module "service_account" {
  source = "github.com/meshcloud/meshstack-hub//modules/kubernetes/service-account?ref=${var.hub.git_ref}"

  cluster_name     = local.kubeconfig_cluster.name
  cluster_server   = local.kubeconfig_cluster.cluster.server
  cluster_roles    = var.kubernetes.cluster_roles
  bbd_display_name = var.kubernetes.service_account_bbd_display_name

  meshstack = local.meshstack
  hub       = var.hub
}

module "stackit_metering" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/metering?ref=${var.hub.git_ref}"
  count  = var.stackit_enabled ? 1 : 0

  stackit_organization_id      = var.stackit.organization_id
  stackit_project_id           = var.stackit.project_id
  kubernetes_oidc_issuer       = var.stackit.kubernetes_oidc_issuer
  metering_platform_identifier = var.stackit.platform_identifier
  metering_image_tag           = var.stackit.image_tag

  kubernetes_service_account_definition_ref = module.service_account.building_block_definition.ref

  metering_meshfed_url = var.metering.meshfed_url
  metering_kraken_url  = var.metering.kraken_url
  metering_api_user    = var.metering.api_user
  metering_api_secret  = var.metering_api_secret
  metering_schedule    = var.metering.schedule

  meshstack = local.meshstack
  hub       = var.hub
}

module "tcloud_metering" {
  source = "github.com/meshcloud/meshstack-hub//modules/otc/metering?ref=${var.hub.git_ref}"
  count  = var.tcloud_enabled ? 1 : 0

  tcloud_api_token             = var.tcloud_api_token
  tcloud_contract_ids          = var.tcloud.contract_ids
  metering_platform_identifier = var.tcloud.platform_identifier
  metering_image_tag           = var.tcloud.image_tag

  kubernetes_service_account_definition_ref = module.service_account.building_block_definition.ref

  metering_meshfed_url = var.metering.meshfed_url
  metering_kraken_url  = var.metering.kraken_url
  metering_api_user    = var.metering.api_user
  metering_api_secret  = var.metering_api_secret
  metering_schedule    = var.metering.schedule

  meshstack = local.meshstack
  hub       = var.hub
}

module "platform_metering" {
  source = "github.com/meshcloud/meshstack-hub//modules/kubernetes/platform-metering?ref=${var.hub.git_ref}"

  kubernetes_platform_ref      = one(data.meshstack_platforms.kubernetes.platforms).ref
  kubernetes_landing_zone_name = var.kubernetes.landing_zone_name

  kubernetes_service_account_definition_version_ref = module.service_account.building_block_definition.version_ref
  metering_building_block_definition_version_refs   = { for cloud, definition in local.metering_definitions : cloud => definition.version_ref }

  metering_project_name         = var.metering_project.name
  metering_project_display_name = var.metering_project.display_name
  metering_project_tags         = { for entry in var.metering_project.tags : entry.key => entry.values }
  metering_schedule             = var.metering.schedule

  meshstack = local.meshstack
  hub       = var.hub
}
