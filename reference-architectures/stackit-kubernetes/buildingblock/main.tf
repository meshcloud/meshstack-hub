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

  # ── What this run inherits from the landing zone ──
  # Building block outputs are stored JSON-encoded, so each is decoded once. These three drive the
  # backplanes this architecture deploys: the service accounts are created in the foundation project,
  # their role grants land on the landing-zone folder (inherited by the hosting project created
  # below), and the whole STACKIT apply authenticates as the landing zone's bootstrap identity.
  landingzone_foundation_project_id = jsondecode(data.meshstack_building_block.landingzone.status.outputs["foundation_project_id"].value)
  landingzone_folder_id             = jsondecode(data.meshstack_building_block.landingzone.status.outputs["lz_folder_id"].value)

  # Long-lived STACKIT credential, published unencrypted by the landing zone on purpose — see that
  # output's comment. It is read here rather than passed in so nobody has to copy a credential
  # between two building blocks by hand.
  landingzone_service_account_key = jsondecode(data.meshstack_building_block.landingzone.status.outputs["platform_bootstrap_service_account_key"].value)

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

  # ── Two-phase bootstrap: the one place this architecture decides whether it has a Forgejo token ──
  #
  # A fresh Forgejo instance carries no credential, so this architecture is ordered once without a
  # token and updated once with it.
  #
  # TODO: the manual mint is avoidable. The STACKIT Git API (v1beta,
  # https://docs.api.eu01.stackit.cloud/oas/git/version/v1beta) creates a local/technical user in an
  # instance, whose password mints a PAT through Forgejo's own
  # POST {instance_url}/api/v1/users/{username}/tokens. The STACKIT Git Instance building block is
  # where that belongs — it already holds the project and instance ids — and it would then report
  # the token as an output this local reads instead of `var.forgejo_api_token`. See the TODO in
  # modules/stackit/git/buildingblock/main.tf. Spec-verified, not run-verified, and not wired up.
  #
  # Everything below branches on `local.forgejo_api_token`, never on the variable, so wiring the
  # automatic mint means changing this one expression.
  forgejo_api_token = var.forgejo_api_token

  # Whether a token is available is not itself a secret, and `lifecycle.enabled` rejects a condition
  # derived from a sensitive value, so the marker is dropped here; the token itself stays sensitive.
  forgejo_token_provided = nonsensitive(local.forgejo_api_token != null && local.forgejo_api_token != "")

  # `try`: in phase 1 the Git building block reports no organization (it creates none without a
  # token), and meshStack omits a null output entirely. Falling back to null keeps phase 1
  # evaluating; the run-status postcondition on the building block is what fails loudly if the
  # instance itself did not come up.
  forgejo_instance_url = try(jsondecode(meshstack_building_block.git.status.outputs["instance_url"].value), null)
  forgejo_organization = try(jsondecode(meshstack_building_block.git.status.outputs["forgejo_organization"].value), null)
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

# The STACKIT Landing Zone this platform is built on. Read at order time for the STACKIT coordinates
# and the bootstrap credential the definitions registered below need — see the locals at the top.
data "meshstack_building_block" "landingzone" {
  metadata = {
    uuid = var.landingzone_building_block_uuid
  }
}

# ── Definitions this platform registers for itself ──
# Both are registered per ordered platform rather than once per landing zone, so each platform owns
# its own definitions and its own backplane identities. Their backplanes create a service account in
# the landing zone's foundation project and grant it roles on the landing-zone folder, which the
# hosting project created above inherits.

module "cluster_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/ske/cluster?ref=${var.hub.git_ref}"

  stackit_backplane_project_id = local.landingzone_foundation_project_id
  stackit_backplane_folder_id  = local.landingzone_folder_id

  # Every ordered platform registers its own definition, so its backplane account needs its own name
  # — the module's fixed default would collide on the second order into the same foundation project.
  # STACKIT caps the name at 20 characters, which the 8-character suffix leaves room for.
  stackit_service_account_name = "mesh-ske-${random_string.identifier_suffix.result}"

  # `roles` stays at the module default (`editor`), the narrowest folder role that both manages SKE
  # and can enable the service on a freshly created project — see that variable for the reasoning.

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

module "git_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/git?ref=${var.hub.git_ref}"

  stackit_backplane_project_id = local.landingzone_foundation_project_id
  stackit_backplane_folder_id  = local.landingzone_folder_id

  # Per-platform name, for the same reason as the cluster backplane above.
  stackit_service_account_name = "mesh-git-${random_string.identifier_suffix.result}"

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

# ── SKE cluster ──
# The STACKIT SKE Cluster building block registered above, ordered on the hosting tenant. It is
# TENANT_LEVEL, so its STACKIT project id is injected from the tenant (PLATFORM_TENANT_ID) and it
# deploys as its own folder-scoped backplane identity — the platform supplies neither here.
resource "meshstack_building_block" "cluster" {
  wait_for_completion = true
  depends_on          = [module.cluster_integration, meshstack_tenant.hosting]

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    building_block_definition_version_ref = { uuid = module.cluster_integration.building_block_definition.version_ref.uuid }
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

# ── STACKIT Git instance (created in phase 1, handed its token in phase 2) ──
# The STACKIT Git Instance building block registered above, ordered on the hosting tenant. It
# creates the Forgejo the platform's CI/CD runs on. Ordered in both phases: phase 1 creates the bare
# instance, phase 2 hands it the token so it can create the organization.
resource "meshstack_building_block" "git" {
  wait_for_completion = true
  depends_on          = [module.git_integration, meshstack_tenant.hosting]

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    building_block_definition_version_ref = { uuid = module.git_integration.building_block_definition.version_ref.uuid }
    display_name                          = "STACKIT Git Instance"
    target_ref                            = { kind = "meshTenant", uuid = meshstack_tenant.hosting.metadata.uuid }

    # The token input only appears once the operator has minted it — adding it is what makes the
    # second order of this architecture re-run this building block. Until then the definition's
    # `is_optional` lets meshStack send no value at all.
    #
    # This is the one building block here that mixes a plain `value` with a `sensitive` input. The
    # cluster-issuer block above documents the meshstack provider throwing "inconsistent values for
    # sensitive attribute" on such a mix; there the mix was avoidable, here it is not — the instance
    # name is per-order, so it cannot move onto the definition. If phase 2 hits that error, the fix
    # is to declare `instance_name` sensitive on the definition too, not to drop it.
    inputs = merge(
      {
        instance_name = { value = jsonencode(local.platform_identifier) }
      },
      local.forgejo_token_provided ? {
        forgejo_token = { sensitive = { secret_value = local.forgejo_api_token } }
      } : {}
    )
  }
}

# ── Application-team building blocks (phase 2 — only once the Forgejo token is supplied) ──
# Both definitions authenticate against Forgejo with the token, so neither can be registered before
# it exists. Registering them is the whole point of the second run: it is what lets application
# teams order a repository and wire it to their namespace.

module "git_repository_integration" {
  lifecycle {
    enabled = local.forgejo_token_provided
  }

  source = "github.com/meshcloud/meshstack-hub//modules/stackit/git-repository?ref=${var.hub.git_ref}"

  forgejo_base_url     = local.forgejo_instance_url
  forgejo_token        = local.forgejo_api_token
  forgejo_organization = local.forgejo_organization

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

module "forgejo_connector_integration" {
  lifecycle {
    enabled = local.forgejo_token_provided
  }

  source = "github.com/meshcloud/meshstack-hub//modules/ske/forgejo-connector?ref=${var.hub.git_ref}"

  # The connector `yamlencode`s this into a FILE input, so it takes the decoded kubeconfig, not the
  # raw string the cluster building block outputs.
  kubeconfig = yamldecode(local.cluster_kubeconfig)

  forgejo_host      = local.forgejo_instance_url
  forgejo_api_token = local.forgejo_api_token
  # Guarded: `module.git_repository_integration` is null while phase 2 has not run.
  forgejo_repo_definition_uuid = local.forgejo_token_provided ? module.git_repository_integration.building_block_definition.uuid : null

  # Image pull credentials for the shared STACKIT Harbor registry. Empty by default: the Harbor
  # project is shared across STACKIT customers and we hold robot credentials for it rather than
  # admin rights, so nothing here creates them. A deployment without them still gets a working
  # connector — it just cannot pull private images until they are filled in.
  #
  # TODO: bootstrapping Harbor from here would need three roles together, none of which is a subset
  # of another (all read from the live authorization and service-enablement APIs):
  #   * `editor` / `owner` / a `folder.*` role — for `service-enablement.service-state.edit`.
  #     `cloud.stackit.container-registry` is DISABLED by default on every project checked, so the
  #     service has to be switched on before anything can be created in it.
  #   * `container-registry.admin` — for `container-registry.project.create`.
  #   * `container-registry.artifactory.admin` — for
  #     `container-registry.project.permission.administer`, the Harbor project-admin permission that
  #     mints robot accounts. Neither `editor` nor `owner` includes it.
  # Nothing Harbor-related is implemented; this is recorded so the next person does not rediscover it.
  harbor_username = var.harbor_username == null ? "" : var.harbor_username
  harbor_password = var.harbor_password == null ? "" : var.harbor_password

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}
