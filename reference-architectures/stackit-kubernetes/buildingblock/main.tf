locals {
  # The identifier is unique across the whole meshStack instance and lands in the platform name, the
  # location and the STACKIT project, so a playground deployment suffixes it instead of occupying the
  # plain name.
  platform_identifier = var.playground_mode ? "${var.platform_identifier}-${random_string.playground_suffix.result}" : var.platform_identifier

  # STACKIT caps a service account name at 20 characters and rejects one ending in a dash, so cutting
  # the identifier to length can produce an invalid name. Cut shorter instead, drop whatever dashes
  # the cut exposed, and end with a hash of the full identifier so two names sharing a prefix stay
  # apart. A name that already fits passes through untouched.
  platform_service_account_name = length(local.platform_identifier) <= 20 ? local.platform_identifier : format(
    "%s-%s",
    replace(substr(local.platform_identifier, 0, 15), "/-+$/", ""),
    substr(sha256(local.platform_identifier), 0, 4)
  )

  location_name = var.use_global_location ? "global" : meshstack_location.this.metadata.name

  owner_tags = var.tags.project_owner_tag_key == "" ? {} : { (var.tags.project_owner_tag_key) = [var.creator.displayName] }

  landing_zones = {
    for stage, cfg in var.stages : stage => {
      tags = merge({ environment = [stage] }, cfg.landingzone)
    }
  }

  stage_project_tags = {
    for stage, cfg in var.stages : stage => merge(var.tags.project, { environment = [stage] }, cfg.project)
  }

  landingzone_outputs = data.meshstack_building_block.stackit_lz_ref_arch.status.outputs

  platform_service_account_email = jsondecode(meshstack_building_block.platform_service_account.status.outputs["service_account_email"].value)
  platform_service_account_id    = jsondecode(meshstack_building_block.platform_service_account.status.outputs["service_account_id"].value)

  cluster_name = coalesce(var.cluster_name, format(
    "%s-%s",
    replace(substr(local.platform_identifier, 0, 6), "/-+$/", ""),
    substr(sha256(local.platform_identifier), 0, 4)
  ))
  # It's fine that by default, Let's Encrypt Expiry notifications go nowhere.
  cluster_issuer_email = coalesce(var.cluster_issuer_email, local.platform_service_account_email)

  stackit_project_id = meshstack_tenant.stackit_project.spec.platform_tenant_id

  # A Harbor project name is lowercase only, while the platform identifier also allows capitals. The
  # registry block appends a suffix of its own, so the name it reports back is the one to show.
  registry_base_name = lower(local.platform_identifier)
  registry_name      = jsondecode(meshstack_building_block.container_registry.status.outputs["registry_name"].value)
  registry_host      = jsondecode(meshstack_building_block.container_registry.status.outputs["registry_host"].value)
  registry_url       = jsondecode(meshstack_building_block.container_registry.status.outputs["registry_url"].value)
  registry_robot_url = jsondecode(meshstack_building_block.container_registry.status.outputs["registry_robot_url"].value)

  # The registry block mints these from the bootstrap robot, so this is null until that robot is
  # supplied. One pair covers the platform: a Harbor robot is scoped to a project, and there is one.
  registry_access_credentials = sensitive(jsondecode(jsondecode(meshstack_building_block.container_registry.status.outputs["access_credentials"].value)))

  cluster_kubeconfig = jsondecode(meshstack_building_block.cluster.status.outputs["kubeconfig"].value)
  cluster_kube_host  = jsondecode(meshstack_building_block.cluster.status.outputs["kube_host"].value)

  replicator_token = jsondecode(meshstack_building_block.kubernetes_platform.status.outputs["replicator_token"].value)
  metering_token   = jsondecode(meshstack_building_block.kubernetes_platform.status.outputs["metering_token"].value)

  haproxy_lb_ip = jsondecode(meshstack_building_block.ingress.status.outputs["haproxy_lb_ip"].value)

  dns_subdomain = trimspace(var.dns_subdomain == null ? "" : var.dns_subdomain) != "" ? lower(var.dns_subdomain) : lower(local.platform_identifier)
  dns_zone_name = "${local.dns_subdomain}.${var.dns_parent_domain}"

  ai_credentials = sensitive(jsondecode(jsondecode(meshstack_building_block.ai_llm.status.outputs["access_credentials"].value)))

  # The Git building block mints this itself on its first run: it creates a technical user through
  # the STACKIT Git API and exchanges that user's password for a Personal Access Token.
  forgejo_api_token = sensitive(jsondecode(meshstack_building_block.git.status.outputs["forgejo_api_token"].value))

  forgejo_instance_url = jsondecode(meshstack_building_block.git.status.outputs["instance_url"].value)
  forgejo_organization = jsondecode(meshstack_building_block.git.status.outputs["forgejo_organization"].value)

  platform_admins = toset([
    for member in var.workspace_members : member.username
    if contains(member.roles, "Workspace Owner") || contains(member.roles, "Workspace Manager")
  ])

  # The Harbor robot is the last step still done by hand, so it is the one thing that takes a second
  # order. Only the username decides, and it is deliberately not a sensitive input: meshStack sends a
  # non-empty value for a sensitive input left blank, which read as a robot that does not exist.
  phase2_completed = trimspace(var.harbor_username == null ? "" : var.harbor_username) != ""
}

resource "random_string" "playground_suffix" {
  lifecycle {
    enabled = var.playground_mode
  }

  length  = 6
  special = false
  upper   = false
}

resource "meshstack_location" "this" {
  lifecycle {
    enabled = !var.use_global_location
  }

  metadata = {
    name               = local.platform_identifier
    owned_by_workspace = var.workspace
  }

  spec = {
    display_name = local.platform_identifier
    description  = "STACKIT SKE location created by the STACKIT Kubernetes Platform."
  }
}

resource "meshstack_project" "platform" {
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

# Without these the platform's own project has no human members, and everything the architecture
# creates below onboards its project users: the container registry grants them a STACKIT registry
# role, which is what makes the Harbor project visible to them.
#
# The workspace is the source of truth rather than the creator: `AUTHOR` reports whoever ordered the
# building block, and a platform ordered through the meshStack API — from a foundation repository,
# say — is authored by a service account, not a person.
resource "meshstack_project_user_binding" "admin" {
  for_each = local.platform_admins

  # A binding name is capped at 45 characters and has to be unique across the whole meshStack, which
  # a username spelled out does not fit into. The identifier stays in front so the binding is still
  # recognisable, and the hash covers the full identifier and username so two platforms sharing a
  # truncated prefix cannot collide.
  metadata = {
    name = format(
      "%s-admin-%s",
      substr(local.platform_identifier, 0, 20),
      substr(sha256("${local.platform_identifier}:${each.value}"), 0, 12),
    )
  }

  role_ref = {
    name = "Project Admin"
  }

  target_ref = {
    owned_by_workspace = var.workspace
    name               = meshstack_project.platform.metadata.name
  }

  subject = {
    name = each.value
  }
}

# Provisions the STACKIT project through the landing zone platform's replication. wait_for_completion makes
# the run block until the project exists, so spec.platform_tenant_id (the STACKIT project id) is set.
resource "meshstack_tenant" "stackit_project" {
  wait_for_completion = true

  metadata = {
    owned_by_workspace = var.workspace
    owned_by_project   = meshstack_project.platform.metadata.name
  }

  spec = {
    platform_ref     = jsondecode(jsondecode(local.landingzone_outputs["platform_ref"].value))
    landing_zone_ref = jsondecode(jsondecode(local.landingzone_outputs["landingzone_refs"].value))[var.landingzone_variant]
  }

  # Destroying this tenant deletes the STACKIT project the whole platform runs in. Guard a real
  # deployment against an accidental replacement; a playground stays destroyable.
  lifecycle {
    prevent_destroy = !var.playground_mode
  }
}

module "cluster_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/ske/cluster?ref=${var.hub.git_ref}"

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

module "git_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/git?ref=${var.hub.git_ref}"

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

module "container_registry_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/container-registry?ref=${var.hub.git_ref}"

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

resource "meshstack_building_block" "platform_service_account" {
  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    building_block_definition_version_ref = jsondecode(jsondecode(local.landingzone_outputs["service_account_bbd_version_ref"].value))
    display_name                          = "Automation Identity"
    target_ref                            = meshstack_tenant.stackit_project.ref

    inputs = {
      service_account_name = { value = jsonencode(local.platform_service_account_name) }
      # `editor` covers every permission the blocks below need, including `ske.*`, `git.*`,
      # `container-registry.*`, `dns.*` and `service-enablement.service-state.edit`, so naming those
      # service roles as well adds nothing. `iam.member-admin` is the one addition: it carries
      # `iam.member.add` and `.remove`, which `editor` lacks and the registry block needs to grant
      # project members their registry role.
      roles = { value = jsonencode(jsonencode([
        "editor",
        "iam.member-admin",
      ])) }
    }
  }
}

# Separate from the service account, so that the account depends on no definition below. Every block
# that acts as the account is a child of this one.
resource "meshstack_building_block" "platform_federation" {
  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.platform_service_account.ref]
    building_block_definition_version_ref = jsondecode(jsondecode(local.landingzone_outputs["service_account_federation_bbd_version_ref"].value))
    display_name                          = "Automation Identity Federation"
    target_ref                            = meshstack_tenant.stackit_project.ref

    inputs = {
      service_account_email = { value = jsonencode(local.platform_service_account_email) }
      federated_building_block_definitions = {
        value = jsonencode(jsonencode([
          module.cluster_integration.building_block_definition.uuid,
          module.git_integration.building_block_definition.uuid,
          module.container_registry_integration.building_block_definition.uuid,
          module.dns_integration.building_block_definition.uuid,
          module.ai_llm_integration.building_block_definition.uuid,
        ]))
      }
    }
  }
}

resource "meshstack_building_block" "cluster" {
  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.platform_federation.ref]
    building_block_definition_version_ref = module.cluster_integration.building_block_definition.version_ref
    display_name                          = "SKE Cluster"
    target_ref                            = meshstack_tenant.stackit_project.ref

    inputs = {
      cluster_name                  = { value = jsonencode(local.cluster_name) }
      STACKIT_SERVICE_ACCOUNT_EMAIL = { value = jsonencode(local.platform_service_account_email) }
    }
  }
}

module "kubernetes_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/kubernetes?ref=${var.hub.git_ref}"

  kube_host        = local.cluster_kube_host
  replicator_token = local.replicator_token
  metering_token   = local.metering_token
  landing_zones    = local.landing_zones

  meshstack = {
    owning_workspace_identifier = var.workspace
    location_name               = local.location_name
    platform_identifier         = local.platform_identifier
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
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.cluster.ref]
    building_block_definition_version_ref = module.kubernetes_integration.building_block_definition.version_ref
    display_name                          = "Kubernetes meshPlatform Credentials"
    target_ref                            = meshstack_tenant.stackit_project.ref

    inputs = {
      kubeconfig = {
        sensitive = {
          secret_value   = local.cluster_kubeconfig
          secret_version = sha256(local.cluster_kubeconfig)
        }
      }
    }
  }
}

# `dns01` is left at its null default. The zone now exists, but a DNS-01 solver also needs a STACKIT
# service account key inside the cluster, and this architecture authenticates through workload
# identity federation precisely so that no such key exists. Certificates are issued per hostname over
# HTTP-01, which the zone makes reliable: every hostname resolves to the load balancer.
module "ingress_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/kubernetes/ingress?ref=${var.hub.git_ref}"

  depends_on = [module.cluster_integration]

  # STATIC on the definition rather than an order-time input, so the building block below passes
  # only the sensitive kubeconfig — see that module's integration for why the two must not mix.
  acme_email = local.cluster_issuer_email

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

resource "meshstack_building_block" "ingress" {
  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.cluster.ref]
    building_block_definition_version_ref = module.ingress_integration.building_block_definition.version_ref
    display_name                          = "Kubernetes Ingress"
    target_ref                            = meshstack_tenant.stackit_project.ref

    inputs = {
      kubeconfig = {
        sensitive = {
          secret_value   = local.cluster_kubeconfig
          secret_version = sha256(local.cluster_kubeconfig)
        }
      }
    }
  }
}

module "ai_llm_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/ai-llm?ref=${var.hub.git_ref}"

  model = var.ai_model

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

resource "meshstack_building_block" "ai_llm" {
  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.platform_federation.ref]
    building_block_definition_version_ref = module.ai_llm_integration.building_block_definition.version_ref
    display_name                          = "AI Model Serving"
    target_ref                            = meshstack_tenant.stackit_project.ref

    inputs = {
      token_name                    = { value = jsonencode(local.platform_identifier) }
      STACKIT_SERVICE_ACCOUNT_EMAIL = { value = jsonencode(local.platform_service_account_email) }
    }
  }
}

module "dns_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/dns?ref=${var.hub.git_ref}"

  depends_on = [module.ingress_integration]

  parent_domain = var.dns_parent_domain

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

resource "meshstack_building_block" "dns" {
  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.ingress.ref, meshstack_building_block.platform_federation.ref]
    building_block_definition_version_ref = module.dns_integration.building_block_definition.version_ref
    display_name                          = "DNS Zone"
    target_ref                            = meshstack_tenant.stackit_project.ref

    inputs = {
      subdomain                     = { value = jsonencode(local.dns_subdomain) }
      wildcard_target_ip            = { value = jsonencode(local.haproxy_lb_ip) }
      contact_email                 = { value = jsonencode(local.cluster_issuer_email) }
      STACKIT_SERVICE_ACCOUNT_EMAIL = { value = jsonencode(local.platform_service_account_email) }
    }
  }
}

resource "meshstack_building_block" "git" {
  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.platform_federation.ref]
    building_block_definition_version_ref = module.git_integration.building_block_definition.version_ref
    display_name                          = "STACKIT Git Instance"
    target_ref                            = meshstack_tenant.stackit_project.ref

    inputs = {
      instance_name = { value = jsonencode(local.platform_identifier) }
      # One organization per instance, sharing its name. The Git block would take any name here;
      # this architecture is what ties the two together.
      forgejo_organization          = { value = jsonencode(local.platform_identifier) }
      shared_runner_labels          = { value = jsonencode(jsonencode(["stackit-ubuntu-22"])) }
      STACKIT_SERVICE_ACCOUNT_EMAIL = { value = jsonencode(local.platform_service_account_email) }
    }
  }
}

resource "meshstack_building_block" "container_registry" {
  wait_for_completion = true

  # meshStack fills the block's USER_PERMISSIONS input from the project's members when the run
  # starts, so the creator has to be a member before the run, not after it.
  depends_on = [meshstack_project_user_binding.admin]

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.platform_federation.ref]
    building_block_definition_version_ref = module.container_registry_integration.building_block_definition.version_ref
    display_name                          = "STACKIT Container Registry"
    target_ref                            = meshstack_tenant.stackit_project.ref

    inputs = {
      registry_name                 = { value = jsonencode(local.registry_base_name) }
      STACKIT_SERVICE_ACCOUNT_EMAIL = { value = jsonencode(local.platform_service_account_email) }

      bootstrap_robot_username = { value = jsonencode(var.harbor_username == null ? "" : var.harbor_username) }
      mirrored_base_images     = { value = jsonencode(jsonencode(["docker.io/library/python:3.12.9-slim-bookworm"])) }
    }
  }
}

module "git_repository_integration" {
  lifecycle {
    enabled = local.phase2_completed
  }

  source = "github.com/meshcloud/meshstack-hub//modules/stackit/git-repository?ref=${var.hub.git_ref}"

  forgejo_base_url     = local.forgejo_instance_url
  forgejo_api_token    = local.forgejo_api_token
  forgejo_organization = local.forgejo_organization

  # Read by the workflow the template repository ships. Only the platform-wide constants are set
  # here; the starter kit sets APP_NAME and the connector the push robot per repository.
  action_variables = {
    HARBOR_REGISTRY = local.registry_host
    HARBOR_PROJECT  = local.registry_name
  }

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

# Not registered until the Harbor robot exists. The connector's whole job is wiring a repository to a
# namespace for CI/CD, and that pipeline pushes an image — without pull credentials the definition
# would be orderable but the workload it produces could not start. Better absent than broken.
#
# TODO: what blocks minting the first robot is Harbor, not STACKIT IAM.
# `container-registry.artifactory.admin` is assignable at project scope, and granting it is what
# makes the Harbor project visible to a user — the container registry building block does that for
# every project member. But the Harbor API still only opens to an identity Harbor already knows, and
# only the portal can create that first link between a robot and a STACKIT service account. Every
# later robot can then go through the Harbor API.
module "forgejo_connector_integration" {
  lifecycle {
    enabled = local.phase2_completed
  }

  source = "github.com/meshcloud/meshstack-hub//modules/ske/forgejo-connector?ref=${var.hub.git_ref}"

  # The connector `yamlencode`s this into a FILE input, so it takes the decoded kubeconfig, not the
  # raw string the cluster building block outputs.
  kubeconfig = yamldecode(local.cluster_kubeconfig)

  forgejo_host                 = local.forgejo_instance_url
  forgejo_api_token            = local.forgejo_api_token
  forgejo_repo_definition_uuid = module.git_repository_integration.building_block_definition.uuid

  harbor_host                           = "https://${local.registry_host}"
  container_registry_access_credentials = local.registry_access_credentials

  # `stackit-ai` with these three keys is the convention the starter kit's demo application reads
  # inference configuration by.
  additional_kubernetes_secrets = {
    "stackit-ai" = {
      STACKIT_AI_BASE_URL = local.ai_credentials.base_url
      STACKIT_AI_API_KEY  = local.ai_credentials.api_key
      STACKIT_AI_MODEL    = local.ai_credentials.model
    }
  }

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

# The offering application teams actually order: one building block that creates a project, a
# repository from a template and a namespace per stage, out of the two definitions above. It is
# registered on the same condition as they are, because it orders them.
module "ske_starterkit_integration" {
  lifecycle {
    enabled = local.phase2_completed
  }

  source = "github.com/meshcloud/meshstack-hub//modules/ske/ske-starterkit?ref=${var.hub.git_ref}"

  platform_ref      = module.kubernetes_integration.platform_ref
  landing_zone_refs = module.kubernetes_integration.landingzone_refs

  building_block_definition_version_refs = {
    "git-repository"    = module.git_repository_integration.building_block_definition.version_ref
    "forgejo-connector" = module.forgejo_connector_integration.building_block_definition.version_ref
  }

  app_name        = var.starterkit_app_name
  repo_clone_addr = var.starterkit_repo_clone_addr
  dns_zone_name   = local.dns_zone_name

  project_tags = {
    stages        = local.stage_project_tags
    owner_tag_key = var.tags.project_owner_tag_key == "" ? null : var.tags.project_owner_tag_key
  }

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}
