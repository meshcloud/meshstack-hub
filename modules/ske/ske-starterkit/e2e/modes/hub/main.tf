# Stands up an ephemeral meshPlatform and the two definitions the starter kit creates child building
# blocks from, then builds the starter kit definition itself from hub source.
variable "test_context" {
  type = object({
    hub_git_ref          = string
    workspace            = string
    run_id               = string
    forgejo_base_url     = string
    forgejo_organization = string
    dns_zone_name        = string
  })
  nullable = false
}

variable "backplane_secrets" {
  type = object({
    stackit_git_forgejo_token = string
    ske_kubeconfig            = string
    harbor_push_username      = string
    harbor_push_password      = string
    harbor_pull_username      = string
    harbor_pull_password      = string
  })
  sensitive = true
  nullable  = false

  validation {
    # `nullable = false` rejects only the whole object, so the attributes are checked explicitly.
    condition     = alltrue([for secret in values(var.backplane_secrets) : secret != null])
    error_message = "Every backplane secret must be set; the test runner exports them as TF_VAR_<name>."
  }
}

locals {
  # yamldecode parses both YAML (the ICF-published Vault value) and JSON (a superset), so it is
  # robust regardless of the format the kubeconfig secret is provided in.
  ske_kubeconfig = yamldecode(var.backplane_secrets.ske_kubeconfig)
}

module "meshstack_kubernetes_platform" {
  source = "./meshstack_kubernetes_platform"

  kube_host = local.ske_kubeconfig["clusters"][0]["cluster"]["server"]
  workspace = var.test_context.workspace
  run_id    = var.test_context.run_id
}

module "stackit_git_repository" {
  source = "../../../../../stackit/git-repository"
  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  forgejo_base_url     = var.test_context.forgejo_base_url
  forgejo_token        = var.backplane_secrets.stackit_git_forgejo_token
  forgejo_organization = var.test_context.forgejo_organization

  action_secrets = {
    HARBOR_USERNAME = var.backplane_secrets.harbor_push_username
    HARBOR_PASSWORD = var.backplane_secrets.harbor_push_password
  }

  action_variables = {
    HARBOR_REGISTRY = "registry.onstackit.cloud"
    HARBOR_PROJECT  = "stackit_kubernetes_platform" # TODO
    APP_NAME        = var.test_context.run_id       # TODO
  }
}

module "forgejo_connector" {
  source = "../../../../forgejo-connector"
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
  forgejo_api_token            = var.backplane_secrets.stackit_git_forgejo_token
  forgejo_repo_definition_uuid = module.stackit_git_repository.building_block_definition.uuid
  harbor_username              = var.backplane_secrets.harbor_push_username
  harbor_password              = var.backplane_secrets.harbor_push_password

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
  source = "../../../"
  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  bbd_display_name = "${var.test_context.run_id} SKE Starterkit"

  platform_ref           = module.meshstack_kubernetes_platform.platform_ref
  landing_zone_refs      = module.meshstack_kubernetes_platform.landing_zone_refs
  repo_clone_addr        = "https://github.com/likvid-bank/starterkit-template-stackit-ai-summarizer.git"
  dns_zone_name          = var.test_context.dns_zone_name
  add_random_name_suffix = false

  building_block_definition_version_refs = {
    "git-repository"    = module.stackit_git_repository.building_block_definition.version_ref
    "forgejo-connector" = module.forgejo_connector.building_block_definition.version_ref
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

output "version_ref" {
  value = module.ske_starterkit.building_block_definition.version_ref
}
