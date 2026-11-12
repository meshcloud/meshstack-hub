locals {
  # The cluster and platform credentials blocks keep this month's and the previous month's tokens.
  # Derived from the plan time, a month never gets skipped while the schedule runs this block daily.
  token_generation = formatdate("YYYY-MM", plantimestamp())
}

module "cluster_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/ske/cluster?ref=${var.hub.git_ref}"

  approval_policies = var.approval_policies

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block, runner_ref = local.runner_ref }
  hub       = local.platform_hub
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
        stackit_region                = { value = jsonencode(var.stackit_region) }
        STACKIT_SERVICE_ACCOUNT_EMAIL = { value = jsonencode(local.service_account_email) }
        output_to_vault = {
          sensitive = {
            secret_value   = local.output_to_vault
            secret_version = nonsensitive(sha256(local.output_to_vault))
          }
        }
        admin_token_generation = { value = jsonencode(local.token_generation) }
        release_on_destroy     = { value = jsonencode(local.imports.adopt_ske && var.playground_mode) }
      },
      local.imports.adopt_ske ? { imports = { value = jsonencode(jsonencode({})) } } : {},
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

# Older platforms have a "Kubernetes Platform Admin" block, which their operators delete by hand.
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

  cluster_definition_ref = module.cluster_integration.building_block_definition.ref
  kube_host              = local.kube_host
  replicator_token       = ephemeral.vault_kv_secret_v2.kubernetes_platform.data["replicator-token"]
  metering_token         = ephemeral.vault_kv_secret_v2.kubernetes_platform.data["metering-token"]
  tokens_version         = tostring(local.kubernetes_platform_vault_secret.secret_hash)
  landing_zones          = local.landing_zones
  quota_definitions      = var.quota_definitions

  approval_policies = var.approval_policies

  meshstack = {
    owning_workspace_identifier = var.workspace
    runner_ref                  = local.runner_ref
    location_name               = local.location_name
    platform_identifier         = local.platform_name
    supported_platforms         = [{ name = "STACKIT" }]
    tags = {
      landingzone    = var.tags.landingzone
      building_block = var.tags.building_block
    }
  }
  hub = local.platform_hub
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
        release_on_destroy = { value = jsonencode(local.imports.kubernetes_platform != null && var.playground_mode) }
      },
      local.imports.kubernetes_platform == null ? {} : {
        # The meshPlatform and its landing zones are this run's own; the child adopts what is in the cluster.
        imports = { value = jsonencode(jsonencode({})) }
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

module "ingress_controller_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/kubernetes/ingress-controller?ref=${var.hub.git_ref}"

  cluster_definition_ref = module.cluster_integration.building_block_definition.ref
  acme_email             = var.cluster_issuer_email
  haproxy_replica_count  = var.playground_mode ? 1 : 2

  approval_policies = var.approval_policies

  meshstack = {
    owning_workspace_identifier = var.workspace
    tags                        = var.tags.building_block
    runner_ref                  = local.runner_ref
    supported_platforms         = [{ name = "STACKIT" }]
  }
  hub = local.platform_hub
}

resource "meshstack_building_block" "ingress_controller" {
  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.cluster.ref]
    building_block_definition_version_ref = module.ingress_controller_integration.building_block_definition.version_ref
    display_name                          = "Kubernetes Ingress Controller"
    target_ref                            = local.tenant_ref

    inputs = merge(
      {
        "kubeconfig.yaml"  = local.cluster_kubeconfig_input
        release_on_destroy = { value = jsonencode(local.imports.adopt_ingress && var.playground_mode) }
      },
      local.imports.adopt_ingress ? { imports = { value = jsonencode(jsonencode({})) } } : {},
    )
  }
}

moved {
  from = module.ingress_integration
  to   = module.ingress_controller_integration
}

moved {
  from = meshstack_building_block.ingress
  to   = meshstack_building_block.ingress_controller
}

locals {
  ingress_load_balancer_ip = jsondecode(meshstack_building_block.ingress_controller.status.outputs["haproxy_lb_ip"].value)
}
