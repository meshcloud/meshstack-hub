locals {
  platform_identifier = "ske-platform-${random_string.identifier_suffix.result}"

  location_name = var.use_global_location ? "global" : meshstack_location.this.metadata.name

  # meshStack may enforce a mandatory owner tag on projects; write the creator's display name into it.
  # Empty project_owner_tag_key sets none.
  owner_tags = var.tags.project_owner_tag_key == "" ? {} : { (var.tags.project_owner_tag_key) = [var.creator.displayName] }

  landingzone_outputs = data.meshstack_building_block.stackit_lz_ref_arch.status.outputs

  host_platform_ref               = jsondecode(local.landingzone_outputs["platform_ref"].value)
  host_landingzone_ref            = jsondecode(local.landingzone_outputs["landingzone_refs"].value)[var.landingzone_variant]
  service_account_bbd_version_ref = jsondecode(local.landingzone_outputs["service_account_bbd_version_ref"].value)

  wif_issuer         = data.meshstack_integrations.this.workload_identity_federation.replicator.issuer
  wif_subject_prefix = trimsuffix(data.meshstack_integrations.this.workload_identity_federation.replicator.subject, ":replicator")
  wif_audience       = "api://AzureADTokenExchange"

  platform_service_account_email = jsondecode(meshstack_building_block.platform_service_account.status.outputs["service_account_email"].value)

  cluster_name = coalesce(var.cluster_name, format(
    "%s-%s",
    replace(substr(local.platform_identifier, 0, 6), "/-+$/", ""),
    substr(sha256(local.platform_identifier), 0, 4)
  ))
  # It's fine that by default, Let's Encrypt Expiry notifications go nowhere.
  cluster_issuer_email = coalesce(var.cluster_issuer_email, local.platform_service_account_email)

  stackit_project_id = meshstack_tenant.hosting.spec.platform_tenant_id

  # Child building block outputs are stored JSON-encoded, so each is decoded once here.
  cluster_kubeconfig = jsondecode(meshstack_building_block.cluster.status.outputs["kubeconfig"].value)
  cluster_kube_host  = jsondecode(meshstack_building_block.cluster.status.outputs["kube_host"].value)

  replicator_token = jsondecode(meshstack_building_block.kubernetes_platform.status.outputs["replicator_token"].value)
  metering_token   = jsondecode(meshstack_building_block.kubernetes_platform.status.outputs["metering_token"].value)

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
    landing_zone_ref = local.host_landingzone_ref
  }

  # Destroying this tenant deletes the STACKIT project the whole platform runs in. Guard a real
  # deployment against an accidental replacement; a playground stays destroyable.
  lifecycle {
    prevent_destroy = !var.playground_mode
  }
}

data "meshstack_integrations" "this" {}

module "cluster_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/ske/cluster?ref=${var.hub.git_ref}"

  external_service_account = true

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

module "git_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/git?ref=${var.hub.git_ref}"

  external_service_account = true

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
    building_block_definition_version_ref = { uuid = local.service_account_bbd_version_ref.uuid }
    display_name                          = "Platform Automation Identity"
    target_ref                            = { kind = "meshTenant", uuid = meshstack_tenant.hosting.metadata.uuid }

    inputs = {
      service_account_name = { value = jsonencode("mesh-plat-${random_string.identifier_suffix.result}") }
      roles                = { value = jsonencode(jsonencode(["editor", "ske.admin", "git.admin"])) }
      federated_identities = {
        value = jsonencode(jsonencode([
          for uuid in [
            module.cluster_integration.building_block_definition.uuid,
            module.git_integration.building_block_definition.uuid,
            ] : {
            issuer   = local.wif_issuer
            subject  = "${local.wif_subject_prefix}:workspace.${var.workspace}.buildingblockdefinition.${uuid}"
            audience = local.wif_audience
          }
        ]))
      }
    }
  }
}

# ── SKE cluster ──
resource "meshstack_building_block" "cluster" {
  wait_for_completion = true

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
    parent_building_block_refs = [meshstack_building_block.cluster.ref]
    building_block_definition_version_ref = {
      uuid = module.kubernetes_integration.building_block_definition.version_ref.uuid
    }
    display_name = "Kubernetes meshPlatform Credentials"
    target_ref   = { kind = "meshWorkspace", name = var.workspace }

    inputs = {
      kubeconfig = { sensitive = { secret_value = local.cluster_kubeconfig } }
    }
  }
}

# ── Ingress: cert-manager, HAProxy and the Let's Encrypt ClusterIssuer (one child building block) ──
# This used to be two blocks, because a ClusterIssuer is a cert-manager custom resource and
# `kubernetes_manifest` looks its CRD up at plan time — impossible in the run that installs
# cert-manager. The module renders the ClusterIssuer through an inline Helm chart instead, which
# needs no plan-time schema lookup, so the split is gone and the ordering constraint with it.
#
# `dns01` is left at its null default: it would issue a wildcard certificate, but that needs a DNS
# zone and a credential for it and no hub module on this branch produces either yet. Certificates
# are issued per hostname over HTTP-01 until then.
module "ingress_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/kubernetes/ingress?ref=${var.hub.git_ref}"

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
    parent_building_block_refs = [meshstack_building_block.cluster.ref]
    building_block_definition_version_ref = {
      uuid = module.ingress_integration.building_block_definition.version_ref.uuid
    }
    display_name = "Kubernetes Ingress"
    target_ref   = { kind = "meshWorkspace", name = var.workspace }

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
    # meshstack provider throws "inconsistent values for sensitive attribute" on such a mix, which
    # is why every other block above passes only its sensitive kubeconfig and keeps the rest STATIC
    # on the definition. Here the mix is not avoidable — the instance name is per-order, so it
    # cannot move onto the definition. If phase 2 hits that error, the fix is to declare
    # `instance_name` sensitive on the definition too, not to drop it.
    inputs = merge(
      {
        instance_name                 = { value = jsonencode(local.platform_identifier) }
        STACKIT_SERVICE_ACCOUNT_EMAIL = { value = jsonencode(local.platform_service_account_email) }
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
  # The order-time Harbor inputs are gone for now — see the phase-2 Harbor TODO in
  # meshstack_integration.tf — so the connector always starts without pull credentials.
  harbor_username = ""
  harbor_password = ""

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}
