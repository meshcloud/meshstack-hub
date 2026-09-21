locals {
  # ── The one place this module decides whether it has a Forgejo credential ──
  #
  # TODO: mint the token here instead of waiting for one to be handed in. The STACKIT Git API
  # (v1beta, https://git.api.stackit.cloud, spec at
  # https://docs.api.eu01.stackit.cloud/oas/git/version/v1beta) can create a local/technical user:
  #
  #   POST /v1beta/projects/{projectId}/instances/{instanceId}/users
  #        {name, username, email, password, force_send_reset_password}   (permission git.instance.users.create)
  #   PATCH /v1beta/projects/{projectId}/instances/{instanceId}
  #        {acl, admin_login, feature_toggle{enable_local_login}, labels}
  #
  # With that user's password, Forgejo's POST {instance_url}/api/v1/users/{username}/tokens returns
  # the PAT in its `sha1` field — that route takes HTTP Basic auth only (an existing API token
  # cannot mint another), which is exactly what the local user provides. Neither call is in the
  # STACKIT Terraform provider or Go SDK yet, and the `stackit_git` resource has no update support
  # or `feature_toggle` attribute, so both would go out of band (e.g. `restapi`/`http`). The flow is
  # spec-verified, not run-verified.
  #
  # The backplane is already scoped for it: `git.admin` carries `git.instance.users.create` and
  # `git.instance.update`, which are precisely the two permissions those calls need (verified
  # against the live authorization API). A live instance reports Forgejo `16.0.3+gitea-1.22.0` with
  # `enable_local_login: false` and `admin_login: false`, so local login has to be switched on
  # first — and that version clears the route's v16.0.0 gate (an anonymous POST to the admin token
  # route answers 401, not 404). So the manual step is a gap in this module, not a STACKIT limit.
  #
  # Everything below branches on `local.forgejo_token`, never on `var.forgejo_token`, so an
  # automatic mint only has to feed this one expression.
  forgejo_token = var.forgejo_token

  # Whether a token is available is not itself a secret, and `lifecycle.enabled` (like `count`)
  # rejects a condition derived from a sensitive value — so the boolean is unmarked here.
  forgejo_token_provided = nonsensitive(local.forgejo_token != null && local.forgejo_token != "")

  create_forgejo_organization = local.forgejo_token_provided && var.forgejo_organization != null && var.forgejo_organization != ""

  # `<name>.git.onstackit.cloud` — STACKIT derives the instance URL from the instance name. The
  # restapi provider is configured from this rather than from `stackit_git.this.url`, because a
  # provider configuration cannot depend on a resource created in the same apply: on a run that
  # creates the instance and the organization at once, that attribute is still unknown at plan time.
  forgejo_base_url = "https://${var.instance_name}.git.onstackit.cloud"

  # Interpolating a null into the provider header errors out. The header is only ever used by the
  # organization resource, which is disabled unless a token is available.
  forgejo_token_header = local.forgejo_token_provided ? local.forgejo_token : ""
}

resource "stackit_git" "this" {
  project_id = var.stackit_project_id
  name       = var.instance_name
}

# TODO: this instance has no Actions runner, and a fresh instance never does — so every Forgejo
# Actions workflow queues forever and the starterkit's build_image job never runs. CI on this
# platform cannot work until one exists. The STACKIT Git API has
# POST/GET/DELETE /v1beta/projects/{projectId}/instances/{instanceId}/runner, and the backplane's
# `git.admin` role already carries `git.runner.create`. A live instance answers that GET with a
# runner labelled stackit-alpine / stackit-docker / stackit-ubuntu-22 among others, which is what
# a workflow's `runs-on` selects. The `stackit_git` resource has no runner attribute, so this is
# another out-of-band call (`restapi`/`http`). Deliberately not implemented yet.

# The gitea provider is not used here: creating the organization works, but refreshing the plan
# fails with a 403 against STACKIT Git, so every subsequent run breaks. The generic REST resource
# does the same call without that refresh behaviour.
resource "restapi_object" "forgejo_organization" {
  lifecycle {
    enabled = local.create_forgejo_organization
  }

  path          = "/api/v1/orgs"
  id_attribute  = "username"
  object_id     = var.forgejo_organization
  update_method = "PATCH"

  data = jsonencode({
    username   = var.forgejo_organization
    visibility = "private"
  })

  ignore_server_additions = true

  # The instance has to answer before an organization can be created in it. The dependency is not
  # visible to OpenTofu otherwise, because the provider is configured from the derived URL.
  depends_on = [stackit_git.this]
}
