locals {
  # The team alias joins both identifiers for the same reason every derived name does: a project
  # identifier alone can repeat across workspaces. It stays readable in the LiteLLM UI.
  team_alias = local.tenant_key
  key_alias  = "${local.team_alias}-key"

  # LiteLLM's OpenAI-compatible routes live under '/v1'. The gateway also answers without the
  # prefix, but OpenAI client libraries expect it, so the endpoint carries it.
  api_base = "${trimsuffix(var.litellm_api_base, "/")}/v1"

  # The two keys of the Secret are the environment variable names the OpenAI client libraries read,
  # so a workload can mount the Secret with `envFrom` and needs no code that knows about a gateway.
  secret_keys = {
    api_key  = "OPENAI_API_KEY"
    api_base = "OPENAI_BASE_URL"
  }
}

resource "litellm_team" "this" {
  team_alias = local.team_alias
  models     = var.models

  # The budget belongs on the team rather than on the key. LiteLLM counts the spend of every key
  # of a team against the team budget, so a single limit here covers the tenant even if the
  # platform team later hands out a second key.
  max_budget      = var.max_budget
  budget_duration = var.budget_duration

  metadata = {
    meshstack_workspace_identifier = var.workspace_identifier
    meshstack_project_identifier   = var.project_identifier
    meshstack_tenant_uuid          = var.meshstack_tenant_uuid
  }
}

# The key deliberately omits `models`: the provider sends "all-team-models" when `team_id` is set
# and `models` is left out, which keeps the allow-list on the team alone.
resource "litellm_key" "this" {
  key_alias = local.key_alias
  team_id   = litellm_team.this.id
}

# --- The sibling tenant of the same meshProject -------------------------------------------------
#
# This block runs on the AI model tenant. The workload runs on a second tenant of the same
# meshProject, a namespace on the demo application cluster, and that namespace is where the model
# credential has to land. meshStack does not hand the sibling to a building block run, so the run
# asks for it with the ephemeral API token that `version_spec.permissions` grants.
#
# The filter is on `platform`, the full '<platform>.<location>' identifier, and never on
# `platform_type`: two Kubernetes clusters are two platforms of one type, and a type filter would
# match a tenant on the wrong cluster.
data "meshstack_tenants" "sibling" {
  workspace = var.workspace_identifier
  project   = var.project_identifier
  platform  = var.demo_app_platform_identifier
}

locals {
  sibling_tenants      = data.meshstack_tenants.sibling.tenants
  sibling_tenant_count = length(local.sibling_tenants)

  # `one()` raises an error of its own on a collection with more than one element, which would
  # replace the precondition below with a message that names neither the platform nor the project.
  # The conditional keeps it out of the way until the count is known to be one.
  #
  # `platform_tenant_id` of a Kubernetes tenant is the namespace name itself.
  sibling_namespace = local.sibling_tenant_count == 1 ? one(local.sibling_tenants).spec.platform_tenant_id : null
}

# --- The model credential, in the namespace of the application team -----------------------------

resource "kubernetes_secret_v1" "model_access" {
  provider = kubernetes.demo_app

  metadata {
    name      = var.secret_name
    namespace = local.sibling_namespace

    labels = {
      "app.kubernetes.io/managed-by" = "meshstack"
      "app.kubernetes.io/part-of"    = "ai-model-access"
    }
  }

  type = "Opaque"

  data = {
    (local.secret_keys.api_key)  = litellm_key.this.key
    (local.secret_keys.api_base) = local.api_base
  }

  lifecycle {
    precondition {
      condition     = local.sibling_tenant_count > 0
      error_message = "No tenant of platform '${var.demo_app_platform_identifier}' exists in project '${var.project_identifier}' of workspace '${var.workspace_identifier}'. The project needs a tenant on that platform, because its namespace is where the model credential is delivered."
    }

    precondition {
      condition     = local.sibling_tenant_count < 2
      error_message = "Project '${var.project_identifier}' of workspace '${var.workspace_identifier}' has ${local.sibling_tenant_count} tenants of platform '${var.demo_app_platform_identifier}'. The namespace the model credential is delivered to would be ambiguous, so the run stops instead of picking one."
    }

    # A null platform tenant id means meshStack has not replicated the sibling tenant yet, so its
    # namespace does not exist. This is the dangerous case: the Kubernetes provider falls back to
    # the namespace of the kubeconfig's current context when `metadata.namespace` is null, and the
    # Secret would silently land in a namespace that belongs to somebody else. The condition holds
    # for every matched tenant, so it says nothing about the number of matches and leaves that to
    # the two preconditions above.
    precondition {
      condition = alltrue([
        for tenant in local.sibling_tenants :
        tenant.spec.platform_tenant_id != null && tenant.spec.platform_tenant_id != ""
      ])
      error_message = "The tenant of platform '${var.demo_app_platform_identifier}' in project '${var.project_identifier}' of workspace '${var.workspace_identifier}' carries no platform tenant id, so meshStack has not replicated it yet and its namespace does not exist. Wait for the replication and apply this building block again."
    }
  }
}
