locals {
  # Two projects in different workspaces can carry the same project identifier, so the team alias
  # joins both identifiers. The pair is unique in meshStack and stays readable in the LiteLLM UI.
  team_alias = coalesce(var.team_alias, "${var.workspace_identifier}.${var.project_identifier}")
  key_alias  = coalesce(var.key_alias, "${local.team_alias}-key")

  # LiteLLM's OpenAI-compatible routes live under '/v1'. The gateway also answers without the
  # prefix, but OpenAI client libraries expect it, so the output carries it.
  api_base = "${trimsuffix(var.litellm_api_base, "/")}/v1"
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
