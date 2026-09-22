locals {
  # The identifier lands in the platform, location, hosting project and landing zone names and must be
  # unique across the whole meshStack instance. Nobody needs a meaningful value, so it is generated
  # from a random suffix. The random_string lives in state, so it stays stable across the two-phase run.
  platform_identifier = "ske-platform-${random_string.identifier_suffix.result}"

  location_name = var.use_global_location ? "global" : meshstack_location.this[0].metadata.name

  # meshStack may enforce a mandatory owner tag on projects; write the creator's display name into it.
  # Empty project_owner_tag_key sets none.
  owner_tags = var.tags.project_owner_tag_key == "" ? {} : { (var.tags.project_owner_tag_key) = [var.creator.displayName] }

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

  # Replication and metering tokens the platform-services building block created in-cluster; consumed
  # by the meshStack platform. Stored JSON-encoded, so decoded once.
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
    tags                      = merge(var.tags.project, local.owner_tags)
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

# ── SKE cluster ──
# The STACKIT SKE Cluster building block the landing zone registered, ordered on the hosting tenant.
# It is TENANT_LEVEL, so its STACKIT project id is injected from the tenant (PLATFORM_TENANT_ID) and it
# deploys as its own folder-scoped backplane identity — the platform supplies neither here.
resource "meshstack_building_block" "cluster" {
  wait_for_completion = true
  depends_on          = [meshstack_tenant.hosting]

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    building_block_definition_version_ref = { uuid = var.cluster_bbd_version_ref }
    display_name                          = "SKE Cluster"
    target_ref                            = { kind = "meshTenant", uuid = meshstack_tenant.hosting.metadata.uuid }

    inputs = {
      cluster_name = { value = jsonencode(var.cluster_name) }
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
    parent_building_block_refs = [meshstack_building_block.cluster.ref]
    building_block_definition_version_ref = {
      uuid = module.platform_services_integration.building_block_definition.version_ref.uuid
    }
    display_name = "SKE Platform Services"
    target_ref   = { kind = "meshWorkspace", name = var.workspace }

    inputs = {
      # kubeconfig is a sensitive input, so it must be passed via the sensitive form (secret_value),
      # not as a plain `value`. secret_value takes the raw string, not a jsonencode()'d one.
      kubeconfig = { sensitive = { secret_value = local.cluster_kubeconfig } }
    }
  }
}

# ── Let's Encrypt ClusterIssuer (separate child building block) ──
# Ordered AFTER platform-services so cert-manager (and its CRDs) already exist on the cluster. A
# ClusterIssuer is a cert-manager custom resource whose CRD kubernetes_manifest validates at plan time,
# which cannot work in the same run that installs cert-manager — hence its own building block.
module "cluster_issuer_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/ske/cluster-issuer?ref=${var.hub.git_ref}"

  cluster_issuer_email = var.cluster_issuer_email

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

resource "meshstack_building_block" "cluster_issuer" {
  wait_for_completion = true
  depends_on          = [module.cluster_issuer_integration, meshstack_building_block.platform_services]

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs = [meshstack_building_block.cluster.ref]
    building_block_definition_version_ref = {
      uuid = module.cluster_issuer_integration.building_block_definition.version_ref.uuid
    }
    display_name = "SKE Cluster Issuer"
    target_ref   = { kind = "meshTenant", uuid = meshstack_tenant.hosting.metadata.uuid }

    # Only the sensitive kubeconfig here — do NOT add a plain `value` input alongside it. The meshstack
    # provider throws "inconsistent values for sensitive attribute" when a single building block's
    # inputs map mixes a `sensitive` and a `value` input. cluster_issuer_email is a STATIC input on the
    # definition (set via module.cluster_issuer_integration), so it must not be passed at order time.
    inputs = {
      kubeconfig = { sensitive = { secret_value = local.cluster_kubeconfig } }
    }
  }
}
