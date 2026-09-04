variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    name_suffix = string

    # Mode discriminator: set in foundation mode to order an already-deployed BBD version;
    # null in build-from-source mode, which builds the BBD from hub source.
    bbd_version_ref = optional(object({
      uuid = string
    }))

    # Build-from-source only: the starter kit BBD is composed from an ephemeral meshPlatform, a
    # git-repository and a forgejo-connector this module stands up first. A foundation already
    # deployed all of them, so it supplies none of these.
    forgejo_base_url     = optional(string)
    forgejo_organization = optional(string)
    dns_zone_name        = optional(string)
  })
  nullable = false
}

# Secrets for the ephemeral backplane. Foundation mode builds no backplane and omits them.
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
  build_from_source = var.test_context.bbd_version_ref == null

  # yamldecode parses both YAML (the ICF-published Vault value) and JSON (a superset), so it is
  # robust regardless of the format the kubeconfig secret is provided in.
  ske_kubeconfig = var.ske_kubeconfig != null ? yamldecode(var.ske_kubeconfig) : null
}

# Declared here rather than in a provider.tf: a foundation e2e unit generates its meshstack provider
# into `provider.tf`, which would overwrite a file of that name shipped by this module. In foundation
# mode nothing is created on the cluster, so an unconfigured provider is correct.
provider "kubernetes" {
  host                   = try(local.ske_kubeconfig["clusters"][0]["cluster"]["server"], null)
  cluster_ca_certificate = try(base64decode(local.ske_kubeconfig["clusters"][0]["cluster"]["certificate-authority-data"]), null)
  client_certificate     = try(base64decode(local.ske_kubeconfig["users"][0]["user"]["client-certificate-data"]), null)
  client_key             = try(base64decode(local.ske_kubeconfig["users"][0]["user"]["client-key-data"]), null)
}

resource "random_string" "suffix" {
  length  = 16
  special = false
  upper   = false
  numeric = false
}

module "meshstack_kubernetes_platform" {
  count  = local.build_from_source ? 1 : 0
  source = "./meshstack_kubernetes_platform"

  kube_host   = local.ske_kubeconfig["clusters"][0]["cluster"]["server"]
  workspace   = var.test_context.workspace
  test_suffix = random_string.suffix.result
}

module "stackit_git_repository" {
  count  = local.build_from_source ? 1 : 0
  source = "../../../stackit/git-repository"
  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  forgejo_base_url     = var.test_context.forgejo_base_url
  forgejo_token        = var.stackit_git_forgejo_token
  forgejo_organization = var.test_context.forgejo_organization

  action_secrets = {
    HARBOR_USERNAME = var.harbor_push_username
    HARBOR_PASSWORD = var.harbor_push_password
  }

  action_variables = {
    HARBOR_REGISTRY = "registry.onstackit.cloud"
    HARBOR_PROJECT  = "stackit_kubernetes_platform"               # TODO
    APP_NAME        = "smoke-test-${random_string.suffix.result}" # TODO
  }
}

module "forgejo_connector" {
  count  = local.build_from_source ? 1 : 0
  source = "../../forgejo-connector"
  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  kubeconfig                   = local.ske_kubeconfig
  forgejo_host                 = var.test_context.forgejo_base_url
  forgejo_api_token            = var.stackit_git_forgejo_token
  forgejo_repo_definition_uuid = module.stackit_git_repository[0].building_block_definition.uuid
  harbor_username              = var.harbor_push_username
  harbor_password              = var.harbor_push_password

  # Smoke tests don't exercise real inference — the app only needs the `stackit-ai`
  # secret to exist so its pods can start (the app chart mounts it via `envFrom`, so a
  # missing secret leaves pods in CreateContainerConfigError and `helm --wait --atomic`
  # rolls the deploy back). Static foundations (e.g. trial) inject a real STACKIT
  # model-serving token here via their own `ai.tf`; the smoke test uses dummy values.
  additional_kubernetes_secrets = {
    "stackit-ai" = {
      STACKIT_AI_BASE_URL = "https://ai.invalid/v1"
      STACKIT_AI_API_KEY  = "dummy-smoke-test"
      STACKIT_AI_MODEL    = "dummy-model"
    }
  }
}

module "ske_starterkit" {
  count  = local.build_from_source ? 1 : 0
  source = "../"
  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  platform_ref           = module.meshstack_kubernetes_platform[0].platform_ref
  landing_zone_refs      = module.meshstack_kubernetes_platform[0].landing_zone_refs
  repo_clone_addr        = "https://github.com/likvid-bank/starterkit-template-stackit-ai-summarizer.git"
  dns_zone_name          = var.test_context.dns_zone_name
  add_random_name_suffix = false

  building_block_definition_version_refs = {
    "git-repository"    = module.stackit_git_repository[0].building_block_definition.version_ref
    "forgejo-connector" = module.forgejo_connector[0].building_block_definition.version_ref
  }

  project_tags = {
    dev = {
      "confidentiality" = ["Internal"]
      "environment"     = ["dev"]
    }
    prod = {
      "confidentiality" = ["Internal"]
      "environment"     = ["prod"]
    }
  }
}

locals {
  version_ref = local.build_from_source ? module.ske_starterkit[0].building_block_definition.version_ref : var.test_context.bbd_version_ref
}

resource "meshstack_building_block" "this" {
  # The building block (and its delete run) must be fully destroyed before the backplane it ran
  # against is torn down — otherwise OpenTofu is free to remove the meshPlatform, the child
  # definitions or the cluster credentials while the delete run still needs them.
  depends_on = [
    module.meshstack_kubernetes_platform,
    module.stackit_git_repository,
    module.forgejo_connector,
    module.ske_starterkit,
  ]

  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = { uuid = local.version_ref.uuid }

    display_name = "smoke-test-ske-starterkit-hub-${var.test_context.name_suffix}"
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
