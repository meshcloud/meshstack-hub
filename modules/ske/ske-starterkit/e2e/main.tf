variable "test_context" {
  # Untyped: each mode module re-types it strictly, so every field it needs stays required.
  type     = any
  nullable = false

  validation {
    condition     = can(var.test_context.workspace) && can(var.test_context.name_suffix)
    error_message = "test_context must provide workspace and name_suffix."
  }

  validation {
    # `try` because `test_context` is untyped, so a hub run need not set `mode` at all.
    condition     = contains(["hub", "foundation"], try(var.test_context.mode, "hub"))
    error_message = "test_context.mode must be \"hub\" (the default) or \"foundation\"."
  }
}

# Secrets never travel in `test_context` — it is built from state a CI job can read. They arrive as
# TF_VAR_*, which only the root module sees, so they are declared here and piped down.
variable "stackit_git_forgejo_token" {
  type      = string
  sensitive = true
  default   = null
}

variable "ske_kubeconfig" {
  type        = string
  sensitive   = true
  default     = null
  description = "Kubeconfig for the SKE cluster (YAML or JSON), used by the Forgejo Connector building block."
}

variable "harbor_push_username" {
  type      = string
  sensitive = true
  default   = null
}

variable "harbor_push_password" {
  type      = string
  sensitive = true
  default   = null
}

variable "harbor_pull_username" {
  type      = string
  sensitive = true
  default   = null
}

variable "harbor_pull_password" {
  type      = string
  sensitive = true
  default   = null
}

locals {
  # Statically evaluated at `tofu init`, before any module is installed — so a foundation, which
  # already published the definition, never even resolves the hub build tree.
  mode = try(var.test_context.mode, "hub")
}


module "definition" {
  source = "./modes/${local.mode}"

  test_context = var.test_context

  backplane_secrets = {
    stackit_git_forgejo_token = var.stackit_git_forgejo_token
    ske_kubeconfig            = var.ske_kubeconfig
    harbor_push_username      = var.harbor_push_username
    harbor_push_password      = var.harbor_push_password
    harbor_pull_username      = var.harbor_pull_username
    harbor_pull_password      = var.harbor_pull_password
  }
}

resource "meshstack_building_block" "this" {
  depends_on = [module.definition]

  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = { uuid = module.definition.version_ref.uuid }

    display_name = "smoke-test-ske-starterkit-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      # Kept short on purpose. This name is the stem of a meshProject identifier
      # (`<name>-<stage>`), and a foundation may append a random suffix of its own to avoid
      # collisions on the app hostname and the git repository — both of which are shared across
      # workspaces. `projectIdentifierLength` is per-instance meshStack config, so the budget left
      # for the test is whatever the tightest instance allows: "st-" plus the timestamp fits with
      # room for a foundation's suffix and the stage.
      name = { value = jsonencode("st-${var.test_context.name_suffix}") }
    }
  }
}

# Probe the deployed dev + prod app endpoints: reaching SUCCEEDED means the app was deployed, but
# not that the ingress actually serves traffic with a valid, cert-manager-issued certificate. The
# script GETs the URL over TLS (verified against the system trust store) and retries while
# cert-manager issues the cert; the test asserts each returns 200. Referencing the BB outputs makes
# these data sources read after the building block completes.
data "external" "app_probe" {
  for_each = toset(["dev", "prod"])
  program  = ["python3", "${path.module}/probe_endpoint.py"]
  query = {
    url = try(jsondecode(meshstack_building_block.this.status.outputs["app_link_${each.key}"].value), "")
  }

  # When the building block above fails to apply, `status.outputs` is an empty map and indexing it
  # directly raised a bare "Invalid index" — a second, confusing error on top of the real one. Name
  # the actual cause instead.
  lifecycle {
    precondition {
      condition     = contains(keys(try(meshstack_building_block.this.status.outputs, {})), "app_link_${each.key}")
      error_message = "meshstack_building_block.this has no 'app_link_${each.key}' output (status: ${try(meshstack_building_block.this.status.status, "unknown")}). It did not complete successfully — see the error above."
    }
  }
}
