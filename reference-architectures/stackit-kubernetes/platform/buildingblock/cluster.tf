module "cluster_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/ske/cluster?ref=${var.hub.git_ref}"

  approval_policies = var.approval_policies

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

resource "meshstack_building_block" "cluster" {
  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.platform_federation.ref]
    building_block_definition_version_ref = module.cluster_integration.building_block_definition.version_ref
    display_name                          = "SKE Cluster"
    target_ref                            = local.tenant_ref

    inputs = merge(
      {
        cluster_name                  = { value = jsonencode(var.cluster_name) }
        STACKIT_SERVICE_ACCOUNT_EMAIL = { value = jsonencode(local.service_account_email) }
        output_to_vault = {
          sensitive = {
            secret_value   = local.output_to_vault
            secret_version = nonsensitive(sha256(local.output_to_vault))
          }
        }
        release_on_destroy = { value = jsonencode(var.imports.ske != null && var.playground_mode) }
      },
      var.imports.ske == null ? {} : {
        imports = { value = jsonencode(jsonencode(var.imports.ske)) }
      },
    )
  }
}

locals {
  # `{path, secret_hash}`: the hash versions every input this run fills from the secret.
  cluster_vault_secret = jsondecode(jsondecode(meshstack_building_block.cluster.status.outputs["vault_secret"].value))
}

ephemeral "vault_kv_secret_v2" "cluster_kubeconfig" {
  mount = local.secrets_manager_instance_id
  name  = local.cluster_vault_secret.path
}

locals {
  service_account_full_name = "${lower(var.platform_identifier)}-platform-admin"

  # The service account definition takes a name of at most 63 characters. A longer one keeps the
  # cut identifier in front and ends with a hash of the full name, so two cut names stay apart.
  service_account_name = length(local.service_account_full_name) <= 63 ? local.service_account_full_name : format(
    "%s-%s-platform-admin",
    replace(substr(lower(var.platform_identifier), 0, 43), "/-+$/", ""),
    substr(sha256(local.service_account_full_name), 0, 4)
  )
}

# The client certificate of the SKE kubeconfig expires, this service account's token does not. The
# blocks working inside the cluster use the token.
module "service_account_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/kubernetes/service-account?ref=${var.hub.git_ref}"

  # Delete a child's definition before its parent's: meshStack fails on its `fk_tbb_Parent`
  # constraint otherwise.
  depends_on = [module.cluster_integration]

  kubeconfig          = ephemeral.vault_kv_secret_v2.cluster_kubeconfig.data.kubeconfig
  kubeconfig_version  = tostring(local.cluster_vault_secret.secret_hash)
  cluster_name        = var.cluster_name
  namespace           = "kube-system"
  cluster_roles       = ["cluster-admin"]
  bind_cluster_wide   = true
  supported_platforms = ["STACKIT"]

  approval_policies = var.approval_policies

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

resource "meshstack_building_block" "service_account" {
  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.cluster.ref]
    building_block_definition_version_ref = module.service_account_integration.building_block_definition.version_ref
    display_name                          = "Kubernetes Platform Admin"
    target_ref                            = local.tenant_ref

    inputs = {
      name         = { value = jsonencode(local.service_account_name) }
      cluster_role = { value = jsonencode("cluster-admin") }
      output_to_vault = {
        sensitive = {
          secret_value   = local.output_to_vault
          secret_version = nonsensitive(sha256(local.output_to_vault))
        }
      }
    }
  }
}

locals {
  service_account_vault_secret = jsondecode(jsondecode(meshstack_building_block.service_account.status.outputs["vault_secret"].value))
}

ephemeral "vault_kv_secret_v2" "service_account_kubeconfig" {
  mount = local.secrets_manager_instance_id
  name  = local.service_account_vault_secret.path
}

module "kubernetes_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/kubernetes?ref=${var.hub.git_ref}"

  depends_on = [module.service_account_integration]

  kubeconfig         = ephemeral.vault_kv_secret_v2.service_account_kubeconfig.data.kubeconfig
  kube_host          = jsondecode(meshstack_building_block.cluster.status.outputs["kube_host"].value)
  replicator_token   = ephemeral.vault_kv_secret_v2.kubernetes_platform.data["replicator-token"]
  metering_token     = ephemeral.vault_kv_secret_v2.kubernetes_platform.data["metering-token"]
  kubeconfig_version = tostring(local.service_account_vault_secret.secret_hash)
  tokens_version     = tostring(local.kubernetes_platform_vault_secret.secret_hash)
  landing_zones      = local.landing_zones

  approval_policies = var.approval_policies

  meshstack = {
    owning_workspace_identifier = var.workspace
    location_name               = local.location_name
    platform_identifier         = var.platform_identifier
    tags = {
      landingzone    = var.tags.landingzone
      building_block = var.tags.building_block
    }
  }
  hub = var.hub
}

resource "meshstack_building_block" "kubernetes_platform" {
  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.service_account.ref]
    building_block_definition_version_ref = module.kubernetes_integration.building_block_definition.version_ref
    display_name                          = "Kubernetes meshPlatform Credentials"
    target_ref                            = local.tenant_ref

    inputs = merge(
      {
        output_to_vault = {
          sensitive = {
            secret_value   = local.output_to_vault
            secret_version = nonsensitive(sha256(local.output_to_vault))
          }
        }
        release_on_destroy = { value = jsonencode(var.imports.kubernetes_platform != null && var.playground_mode) }
      },
      var.imports.kubernetes_platform == null ? {} : {
        imports = { value = jsonencode(jsonencode(var.imports.kubernetes_platform)) }
      },
    )
  }
}

locals {
  kubernetes_platform_vault_secret = jsondecode(jsondecode(meshstack_building_block.kubernetes_platform.status.outputs["vault_secret"].value))
}

ephemeral "vault_kv_secret_v2" "kubernetes_platform" {
  mount = local.secrets_manager_instance_id
  name  = local.kubernetes_platform_vault_secret.path
}

# No DNS-01: its solver needs a STACKIT service account key in the cluster, which WIF avoids. HTTP-01
# works because every hostname in the zone resolves to the load balancer.
module "ingress_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/kubernetes/ingress?ref=${var.hub.git_ref}"

  depends_on = [module.service_account_integration]

  kubeconfig            = ephemeral.vault_kv_secret_v2.service_account_kubeconfig.data.kubeconfig
  kubeconfig_version    = tostring(local.service_account_vault_secret.secret_hash)
  acme_email            = var.cluster_issuer_email
  haproxy_replica_count = var.playground_mode ? 1 : 2

  approval_policies = var.approval_policies

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

resource "meshstack_building_block" "ingress" {
  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.service_account.ref]
    building_block_definition_version_ref = module.ingress_integration.building_block_definition.version_ref
    display_name                          = "Kubernetes Ingress"
    target_ref                            = local.tenant_ref

    inputs = merge(
      { release_on_destroy = { value = jsonencode(var.imports.ingress != null && var.playground_mode) } },
      var.imports.ingress == null ? {} : { imports = { value = jsonencode(jsonencode(var.imports.ingress)) } },
    )
  }
}

locals {
  ingress_load_balancer_ip = jsondecode(meshstack_building_block.ingress.status.outputs["haproxy_lb_ip"].value)
}
