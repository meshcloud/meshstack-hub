# ─────────────────────────────────────────────────────────────────────────────
# The AI option
#
# This is the first place a reference architecture is consumed as a component by another one:
# `reference-architectures/ai-platform` is sourced as a module the same way `modules/stackit/network`
# and `modules/stackit/network-area` already are. Its `meshstack_integration.tf` registers the
# `AI-MODEL` platform type and the `AI Platform` building block definition and returns them as
# outputs, and the `meshstack_building_block` below orders that definition once in this workspace —
# exactly the handoff the network option makes for the hub network area.
#
# ── What the option has to supply, and what it derives ───────────────────────
#
# The AI platform installs into a cluster and does not create one. Two of the three things it needs
# from that cluster are already known here, which is what makes this option sit *on top of* the
# kubernetes one rather than next to it:
#
#   apps_domain             `<cluster name>.<shared zone>` — this building block created the zone in
#                           dns.tf and knows whether clusters take a label inside it.
#   app_platform_identifier `<cluster name>.<location>` — `modules/kubernetes/platform` names the
#                           platform after the cluster, and the location is this landing zone's.
#
# The third, the cluster's kubeconfig, is a credential and no output of this run, so it is supplied.
# Deriving it instead would mean ordering a cluster from here, which needs a meshProject, a meshTenant
# on the STACKIT platform and the tenant's project to exist first — a chain this option deliberately
# does not build. The platform team orders one cluster through the kubernetes option and passes its
# kubeconfig in.
#
# ── The identity provider is passed through, not chosen ──────────────────────
#
# `ai-platform` keeps the issuer, the client id, the client secret and the claim mapping as plain
# inputs and names no identity provider. Nothing in this repository names a concrete one either, so
# nothing is invented here: the `oidc_*` fields of `var.ai` are forwarded unchanged.
#
# The accepted risk that comes with them is unchanged too, and worth restating where an operator
# fills the fields in: `ai/model-access` takes `oidc` as a single static input, so every tenant's
# Langfuse instance trusts the same client while `langfuse_default_org_role` defaults to `MEMBER`.
# With `LANGFUSE_DEFAULT_ORG_ID` set, anyone the provider authenticates becomes a member of whichever
# instance they open. Register one client per tenant and set `langfuse_default_org_role = "NONE"` if
# that is not wanted.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  # `var.ai` is sensitive, so the comparison is too, and `count` refuses a sensitive value. Unwrapping
  # only the "is it set" bit leaks nothing.
  ai_enabled = nonsensitive(var.ai != null)

  # The domain every application hostname on the cluster lives under. It already resolves and is
  # already covered by the cluster's wildcard certificate, so the AI platform creates no DNS record
  # and requests no certificate.
  ai_apps_domain = !local.ai_enabled ? null : (
    var.kubernetes.dns_cluster_label_enabled
    ? "${var.ai.cluster_name}.${var.kubernetes.dns_zone_name}"
    : var.kubernetes.dns_zone_name
  )

  # `modules/kubernetes/platform` registers the cluster under its own name, in the location the
  # kubernetes option passes it, which is this landing zone's location.
  ai_app_platform_identifier = local.ai_enabled ? "${var.ai.cluster_name}.${local.location_identifier}" : null

  # The AI platform's own STACKIT assets — the tenants' buckets and the databases inside the shared
  # PostgreSQL Flex instance — default to the foundation project.
  ai_stackit_project_id = !local.ai_enabled ? null : (
    var.ai.stackit_project_id != "" ? var.ai.stackit_project_id : stackit_resourcemanager_project.foundation.project_id
  )
}

module "ai_platform_integration" {
  count  = local.ai_enabled ? 1 : 0
  source = "github.com/meshcloud/meshstack-hub//reference-architectures/ai-platform?ref=${var.hub.git_ref}"

  # ── The cluster ──
  # `app_cluster_kubeconfig` stays empty: the application teams' namespaces are on the same cluster,
  # which is what the kubernetes option delivers.
  ai_cluster_kubeconfig   = var.ai.cluster_kubeconfig
  app_cluster_kubeconfig  = ""
  app_platform_identifier = local.ai_app_platform_identifier
  apps_domain             = local.ai_apps_domain
  ingress_class_name      = var.kubernetes.ingress_class_name

  # ── The gateway ──
  litellm_hostname_label         = var.ai.litellm_hostname_label
  litellm_model_backends         = var.ai.model_backends
  litellm_model_backend_api_keys = var.ai.model_backend_api_keys
  litellm_console_sso_enabled    = var.ai.litellm_console_sso_enabled
  litellm_replica_count          = var.ai.litellm_replica_count
  litellm_redis_enabled          = var.ai.litellm_redis_enabled

  # ── The shared trace storage ──
  clickhouse_replicas        = var.ai.clickhouse_replicas
  clickhouse_storage         = var.ai.clickhouse_storage
  clickhouse_keeper_replicas = var.ai.clickhouse_keeper_replicas

  valkey_host           = var.ai.valkey_host
  valkey_password       = var.ai.valkey_password
  valkey_database_count = var.ai.valkey_database_count

  # ── STACKIT ──
  # The landing zone's own service account key is reused. It already creates projects and service
  # accounts under this organization, so a second credential for the same organization would add a
  # rotation burden without narrowing anything.
  stackit_project_id                     = local.ai_stackit_project_id
  stackit_service_account_key            = var.stackit_service_account_key
  stackit_postgres_instance_id           = var.ai.postgres_instance_id
  stackit_s3_admin_access_key            = var.ai.s3_admin_access_key
  stackit_s3_admin_secret_access_key     = var.ai.s3_admin_secret_access_key
  stackit_s3_admin_credentials_group_urn = var.ai.s3_admin_credentials_group_urn

  # ── The identity provider, forwarded unchanged ──
  oidc_issuer_url             = var.ai.oidc_issuer_url
  oidc_client_id              = var.ai.oidc_client_id
  oidc_client_secret          = var.ai.oidc_client_secret
  oidc_scopes                 = var.ai.oidc_scopes
  oidc_display_name           = var.ai.oidc_display_name
  oidc_allow_account_linking  = var.ai.oidc_allow_account_linking
  oidc_proxy_admin_id         = var.ai.oidc_proxy_admin_id
  oidc_allowed_email_domains  = var.ai.oidc_allowed_email_domains
  oidc_auto_redirect_to_sso   = var.ai.oidc_auto_redirect_to_sso
  oidc_logout_url             = var.ai.oidc_logout_url
  oidc_authorization_endpoint = var.ai.oidc_authorization_endpoint
  oidc_token_endpoint         = var.ai.oidc_token_endpoint
  oidc_userinfo_endpoint      = var.ai.oidc_userinfo_endpoint

  # ── What a tenant receives ──
  model_access_secret_name  = var.ai.model_access_secret_name
  langfuse_default_org_role = var.ai.langfuse_default_org_role
  landing_zones             = var.ai.landing_zones

  # ── meshStack registration ──
  location_identifier        = local.location_identifier
  platform_name              = var.ai.platform_name
  platform_type_name         = var.ai.platform_type_name
  platform_type_display_name = var.ai.platform_type_display_name

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

# One order, in the platform team's own workspace. Every input of the AI Platform definition is
# static — the whole configuration is on the definition above — so this passes none.
resource "meshstack_building_block" "ai_platform" {
  count               = local.ai_enabled ? 1 : 0
  wait_for_completion = true
  depends_on          = [module.ai_platform_integration]

  spec = {
    building_block_definition_version_ref = {
      uuid = module.ai_platform_integration[0].building_block_definition.version_ref.uuid
    }
    display_name = "AI Platform"
    target_ref   = { kind = "meshWorkspace", name = var.workspace }

    # Empty, but not omittable: the attribute is required on the resource.
    inputs = {}
  }
}
