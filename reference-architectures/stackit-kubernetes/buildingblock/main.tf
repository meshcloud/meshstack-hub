locals {
  # The identifier lands in the platform, location, hosting project and landing zone names and must be
  # unique across the whole meshStack instance. Nobody needs a meaningful value, so it is generated
  # from a random suffix. The random_string lives in state, so it stays stable across the two-phase run.
  platform_identifier = "ske-platform-${random_string.identifier_suffix.result}"

  location_name = var.use_global_location ? "global" : meshstack_location.this[0].metadata.name

  # The Forgejo bot token cannot be supplied on the first run — the git instance must exist before its
  # token can be created. Until the token is provided, the organization and the starterkit definitions
  # that need it are gated off; the git instance and the rest of the platform still deploy.
  forgejo_enabled = var.forgejo_token != null

  # The starterkit additionally needs the Harbor credentials (CI push + cluster pull). It is only
  # registered once the Forgejo token AND all Harbor inputs are present, so they can all be supplied
  # together on the run that turns on self-service.
  starterkit_enabled = local.forgejo_enabled && alltrue([
    for v in [
      var.stackit_harbor_project,
      var.stackit_harbor_push_robot_user,
      var.stackit_harbor_push_robot_password,
      var.stackit_harbor_pull_robot_user,
      var.stackit_harbor_pull_robot_password,
    ] : v != null
  ])

  # Null on the first run, while the starterkit definition is still gated off. try() turns the
  # null-attribute access on the disabled module into a null instead of an error.
  starterkit_bbd_uuid = try(module.ske_starterkit.building_block_definition.uuid, null)

  # Resolved once the host STACKIT platform is looked up. `one()` fails loudly if the identifier ever
  # stops matching exactly one platform.
  host_platform_ref = one(data.meshstack_platforms.host.platforms).ref

  # The STACKIT project the whole platform runs in is self-hosted as a meshStack tenant on the host
  # STACKIT platform. `wait_for_completion` on the tenant guarantees the project exists and its id is
  # populated before anything downstream reads it.
  stackit_project_id = meshstack_tenant.hosting.spec.platform_tenant_id

  # Child building block outputs are stored JSON-encoded, so each is decoded once here.
  cluster_kubeconfig = jsondecode(meshstack_building_block.cluster.status.outputs["kubeconfig"].value)
  cluster_kube_host  = jsondecode(meshstack_building_block.cluster.status.outputs["kube_host"].value)

  haproxy_lb_ip    = jsondecode(meshstack_building_block.platform_services.status.outputs["haproxy_lb_ip"].value)
  replicator_token = jsondecode(meshstack_building_block.platform_services.status.outputs["replicator_token"].value)
  metering_token   = jsondecode(meshstack_building_block.platform_services.status.outputs["metering_token"].value)
}

resource "random_string" "identifier_suffix" {
  length  = 8
  special = false
  upper   = false
}

# ── meshStack location ──

resource "meshstack_location" "this" {
  count = var.use_global_location ? 0 : 1

  metadata = {
    name               = local.platform_identifier
    owned_by_workspace = var.workspace
  }

  spec = {
    display_name = local.platform_identifier
    description  = "STACKIT SKE location created by the STACKIT Kubernetes Platform."
  }
}

# ── Hosting project (self-hosted STACKIT project the cluster and its assets run in) ──

resource "meshstack_project" "hosting" {
  metadata = {
    name               = "${local.platform_identifier}-ske"
    owned_by_workspace = var.workspace
  }

  spec = {
    display_name              = "STACKIT Kubernetes Platform: ${local.platform_identifier}"
    payment_method_identifier = var.payment_method_identifier
    tags                      = var.tags.project
  }
}

# Provisions the STACKIT project through the host platform's replication. wait_for_completion makes
# the run block until the project exists, so spec.platform_tenant_id (the STACKIT project id) is set.
resource "meshstack_tenant" "hosting" {
  wait_for_completion = true

  metadata = {
    owned_by_workspace = var.workspace
    owned_by_project   = meshstack_project.hosting.metadata.name
  }

  spec = {
    platform_ref     = local.host_platform_ref
    landing_zone_ref = { name = var.host_landing_zone_name }
  }

  # Destroying this tenant deletes the STACKIT project the whole platform runs in. Guard a real
  # deployment against an accidental replacement; a playground stays destroyable.
  lifecycle {
    prevent_destroy = !var.playground_mode
  }
}

data "meshstack_platforms" "host" {
  identifier = var.host_platform_identifier
}

# ── SKE cluster (child building block, so its kubeconfig is available to later applies) ──

module "cluster_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/ske/cluster?ref=${var.hub.git_ref}"

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

resource "meshstack_building_block" "cluster" {
  wait_for_completion = true
  depends_on          = [module.cluster_integration]

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    building_block_definition_version_ref = {
      uuid = module.cluster_integration.building_block_definition.version_ref.uuid
    }
    display_name = "SKE Cluster"
    target_ref   = { kind = "meshWorkspace", name = var.workspace }

    inputs = {
      STACKIT_SERVICE_ACCOUNT_KEY = { value = jsonencode(var.stackit_service_account_key) }
      stackit_project_id          = { value = jsonencode(local.stackit_project_id) }
      cluster_name                = { value = jsonencode(var.cluster_name) }
    }
  }
}

# ── In-cluster platform services (child building block; configures its providers from the kubeconfig) ──

module "platform_services_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/ske/platform-services?ref=${var.hub.git_ref}"

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

resource "meshstack_building_block" "platform_services" {
  wait_for_completion = true
  depends_on          = [module.platform_services_integration, meshstack_building_block.cluster]

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    building_block_definition_version_ref = {
      uuid = module.platform_services_integration.building_block_definition.version_ref.uuid
    }
    display_name = "SKE Platform Services"
    target_ref   = { kind = "meshWorkspace", name = var.workspace }

    inputs = {
      kubeconfig           = { value = jsonencode(local.cluster_kubeconfig) }
      cluster_issuer_email = { value = jsonencode(var.cluster_issuer_email) }
    }
  }
}
