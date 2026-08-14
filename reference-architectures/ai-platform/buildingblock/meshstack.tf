# ─────────────────────────────────────────────────────────────────────────────
# Self-service: the gateway as a platform, the AI landing zones, and the one
# tenant-facing building block definition each of them makes mandatory.
#
# The gateway's own concepts already form a tenancy model, so meshStack maps onto them directly:
#
#   meshProject       → LiteLLM team
#   landing zone      → allowed models, budget and budget period
#   tenant credential → virtual key
#
# The platform type itself is not created here. It is one catalog-wide object rather than something
# an order owns, and `../meshstack_integration.tf` creates it next to the building block definition
# that registers this architecture.
# ─────────────────────────────────────────────────────────────────────────────

resource "meshstack_platform" "litellm" {
  metadata = {
    name               = var.platform_name
    owned_by_workspace = var.owning_workspace_identifier
  }

  spec = {
    display_name = "AI Model Gateway"
    description  = "Governed, OpenAI-compatible model access through the LiteLLM gateway. A tenant of this platform is a team on the gateway with a virtual key, a budget and the model allow-list of its landing zone."
    endpoint     = local.litellm_public_url
    support_url  = "https://docs.litellm.ai/docs/proxy/virtual_keys"

    location_ref = {
      name = var.location_identifier
    }

    # A custom platform needs no platform-specific configuration beyond the type it belongs to:
    # tenants are created by the building block the landing zone makes mandatory, not by a
    # replicator.
    config = {
      custom = {
        platform_type_ref = {
          name = var.platform_type_name
        }
      }
    }

    # meshStack operators change publication state and access restriction after the first
    # deployment, so the lifecycle block below keeps Terraform from resetting them.
    availability = {
      publication_state        = "PUBLISHED"
      restriction              = "PUBLIC"
      restricted_to_workspaces = []
    }

    contributing_workspaces = []
  }

  lifecycle {
    ignore_changes = [spec.availability]
  }
}

# One model access definition per landing zone. The models, the budget and the budget period are
# `STATIC` inputs of a definition, so a second set of them is a second definition — which is exactly
# what lets one landing zone resolve to a sovereign backend and another to a pool across several.
module "model_access" {
  for_each = var.landing_zones

  source = "github.com/meshcloud/meshstack-hub//modules/ai/model-access?ref=${var.hub.git_ref}"

  # ── The shared gateway ──
  litellm_api_base           = local.litellm_api_base
  litellm_admin_api_key      = local.litellm_master_key
  litellm_platform_type_name = var.platform_type_name

  litellm_team_models          = each.value.models
  litellm_team_max_budget      = each.value.max_budget
  litellm_team_budget_duration = each.value.budget_duration

  # ── The two clusters ──
  ai_platform_cluster_kubeconfig = var.ai_cluster_kubeconfig
  demo_app_cluster_kubeconfig    = local.app_cluster_kubeconfig
  demo_app_platform_identifier   = var.app_platform_identifier
  kubernetes_secret_name         = var.model_access_secret_name

  # ── The tenant's own tracing instance ──
  langfuse_domain             = var.apps_domain
  langfuse_ingress_class_name = var.ingress_class_name
  langfuse_default_org_role   = var.langfuse_default_org_role

  # ── The shared ClickHouse cluster, straight from the module that installed it ──
  langfuse_clickhouse_host              = module.clickhouse.host
  langfuse_clickhouse_native_port       = module.clickhouse.native_port
  langfuse_clickhouse_namespace         = module.clickhouse.namespace
  langfuse_clickhouse_ddl_cluster_name  = module.clickhouse.ddl_cluster_name
  langfuse_clickhouse_admin_username    = module.clickhouse.admin_username
  langfuse_clickhouse_admin_secret_name = module.clickhouse.admin_secret.name
  langfuse_clickhouse_admin_secret_key  = module.clickhouse.admin_secret.key
  langfuse_clickhouse_client_image      = "clickhouse/clickhouse-server:${var.clickhouse_version}"

  # ── The shared Valkey instance ──
  langfuse_valkey_host           = var.valkey_host
  langfuse_valkey_password       = var.valkey_password
  langfuse_valkey_database_count = var.valkey_database_count

  # ── STACKIT, where each tenant's database, user and bucket are created ──
  stackit_project_id                     = var.stackit_project_id
  stackit_service_account_key            = var.stackit_service_account_key
  stackit_s3_admin_access_key            = var.stackit_s3_admin_access_key
  stackit_s3_admin_secret_access_key     = var.stackit_s3_admin_secret_access_key
  stackit_s3_admin_credentials_group_urn = var.stackit_s3_admin_credentials_group_urn
  langfuse_postgres_instance_id          = var.stackit_postgres_instance_id

  # ── The identity provider ──
  oidc_issuer_url            = var.oidc.issuer_url
  oidc_client_id             = var.oidc.client_id
  oidc_client_secret         = var.oidc.client_secret
  oidc_display_name          = var.oidc.display_name
  oidc_scopes                = var.oidc.scopes
  oidc_allow_account_linking = var.oidc.allow_account_linking

  meshstack = {
    owning_workspace_identifier = var.owning_workspace_identifier
    tags                        = var.building_block_tags
  }

  hub = var.hub
}

# The landing zone carries the policy. Listing the model access definition in
# `mandatory_building_block_refs` is what turns "order model access" into "land in this zone": every
# input of that definition is `STATIC` or assigned from tenant context, so meshStack provisions the
# team, the virtual key, the tracing instance and the Kubernetes Secret when the tenant is created
# and nothing stops to ask a human.
resource "meshstack_landingzone" "ai" {
  for_each = var.landing_zones

  metadata = {
    name               = "${var.platform_name}-${each.key}"
    owned_by_workspace = var.owning_workspace_identifier
    tags               = each.value.tags
  }

  spec = {
    display_name = each.value.display_name
    description  = each.value.description

    automate_deletion_approval    = true
    automate_deletion_replication = true

    platform_ref = {
      uuid = meshstack_platform.litellm.metadata.uuid
    }

    platform_properties = {
      custom = {}
    }

    mandatory_building_block_refs = [
      {
        uuid = module.model_access[each.key].building_block_definition.uuid
      }
    ]
  }
}
