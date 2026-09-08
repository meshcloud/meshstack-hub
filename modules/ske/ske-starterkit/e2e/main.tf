variable "test_context" {
  # Untyped: each mode module re-types it strictly, so every field it needs stays required.
  type     = any
  nullable = false

  validation {
    condition     = can(var.test_context.workspace) && can(var.test_context.name_suffix)
    error_message = "test_context must provide workspace and name_suffix."
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
  # already deployed the definition and passes its version ref, never even resolves the hub build
  # tree. A wrong or missing test_context fails at init rather than halfway through an apply.
  mode = try(var.test_context.bbd_version_ref, null) == null ? "hub" : "foundation"

  # yamldecode parses both YAML (the ICF-published Vault value) and JSON (a superset), so it is
  # robust regardless of the format the kubeconfig secret is provided in.
  ske_kubeconfig = var.ske_kubeconfig != null ? yamldecode(var.ske_kubeconfig) : null
}

# Declared here rather than in a provider.tf: a foundation e2e unit generates its meshstack provider
# into `provider.tf`, which would overwrite a file of that name shipped by this module. Foundation
# mode creates nothing on a cluster, so the null arguments are correct there.
provider "kubernetes" {
  host                   = try(local.ske_kubeconfig["clusters"][0]["cluster"]["server"], null)
  cluster_ca_certificate = try(base64decode(local.ske_kubeconfig["clusters"][0]["cluster"]["certificate-authority-data"]), null)
  client_certificate     = try(base64decode(local.ske_kubeconfig["users"][0]["user"]["client-certificate-data"]), null)
  client_key             = try(base64decode(local.ske_kubeconfig["users"][0]["user"]["client-key-data"]), null)
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
      name = { value = jsonencode("smoke-test-${var.test_context.name_suffix}") }
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
    url = jsondecode(meshstack_building_block.this.status.outputs["app_link_${each.key}"].value)
  }
}
