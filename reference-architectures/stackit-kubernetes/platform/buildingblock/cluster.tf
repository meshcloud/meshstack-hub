locals {
  # The cluster and platform credentials blocks keep this month's and the previous month's tokens.
  # Derived from the plan time, a month never gets skipped while the schedule runs this block daily.
  token_generation = formatdate("YYYY-MM", plantimestamp())
}

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
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} ended in ${self.status.status}. See its run in meshPanel."
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
        admin_token_generation = { value = jsonencode(local.token_generation) }
        release_on_destroy     = { value = jsonencode(var.imports.ske != null && var.playground_mode) }
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

  kube_host = terraform_data.kube_host.output
}

# A rotation reruns the cluster block, and the Forgejo connector takes the host as a STATIC input.
resource "terraform_data" "kube_host" {
  input = jsondecode(meshstack_building_block.cluster.status.outputs["kube_host"].value)

  lifecycle {
    ignore_changes = [input]
  }
}

ephemeral "vault_kv_secret_v2" "cluster_kubeconfig" {
  mount = local.secrets_manager_instance_id
  name  = local.cluster_vault_secret.path
}

locals {
  cluster_kubeconfig_input = {
    sensitive = {
      secret_value   = "data:application/yaml;base64,${base64encode(ephemeral.vault_kv_secret_v2.cluster_kubeconfig.data.kubeconfig)}"
      secret_version = tostring(local.cluster_vault_secret.secret_hash)
    }
  }
}

# Platforms built before the cluster created the admin service account had a "Kubernetes Platform
# Admin" block. It stays in meshStack as the parent of the blocks below.
removed {
  from = meshstack_building_block.service_account

  lifecycle {
    destroy = false
  }
}

removed {
  from = module.service_account_integration

  lifecycle {
    destroy = false
  }
}

module "kubernetes_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/kubernetes?ref=${var.hub.git_ref}"

  # Delete a child's definition before its parent's: meshStack fails on its `fk_tbb_Parent`
  # constraint otherwise.
  depends_on = [module.cluster_integration]

  kube_host        = local.kube_host
  replicator_token = ephemeral.vault_kv_secret_v2.kubernetes_platform.data["replicator-token"]
  metering_token   = ephemeral.vault_kv_secret_v2.kubernetes_platform.data["metering-token"]
  tokens_version   = tostring(local.kubernetes_platform_vault_secret.secret_hash)
  landing_zones    = local.landing_zones

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
    # meshStack changes a block's parents only with its definition version, and a changed draft keeps
    # its version: a block created under the Kubernetes Platform Admin keeps it as its parent.
    ignore_changes = [spec.parent_building_block_refs]

    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} ended in ${self.status.status}. See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.cluster.ref]
    building_block_definition_version_ref = module.kubernetes_integration.building_block_definition.version_ref
    display_name                          = "Kubernetes meshPlatform Credentials"
    target_ref                            = local.tenant_ref

    inputs = merge(
      {
        "kubeconfig.yaml" = local.cluster_kubeconfig_input
        token_generation  = { value = jsonencode(local.token_generation) }
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

  depends_on = [module.cluster_integration]

  acme_email            = var.cluster_issuer_email
  haproxy_replica_count = var.playground_mode ? 1 : 2

  approval_policies = var.approval_policies

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

resource "meshstack_building_block" "ingress" {
  wait_for_completion = true

  lifecycle {
    # See the platform credentials block.
    ignore_changes = [spec.parent_building_block_refs]

    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} ended in ${self.status.status}. See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.cluster.ref]
    building_block_definition_version_ref = module.ingress_integration.building_block_definition.version_ref
    display_name                          = "Kubernetes Ingress"
    target_ref                            = local.tenant_ref

    inputs = merge(
      {
        "kubeconfig.yaml"  = local.cluster_kubeconfig_input
        release_on_destroy = { value = jsonencode(var.imports.ingress != null && var.playground_mode) }
      },
      var.imports.ingress == null ? {} : { imports = { value = jsonencode(jsonencode(var.imports.ingress)) } },
    )
  }
}

locals {
  ingress_load_balancer_ip = jsondecode(meshstack_building_block.ingress.status.outputs["haproxy_lb_ip"].value)
}
