variable "test_context" {
  type = object({
    hub_git_ref          = string
    workspace            = string
    name_suffix          = string
    forgejo_base_url     = string
    forgejo_organization = string
  })
  nullable = false
}

variable "stackit_git_forgejo_token" {
  type      = string
  sensitive = true
  nullable  = false
}

variable "ske_kubeconfig" {
  type        = string
  sensitive   = true
  nullable    = false
  description = "Kubeconfig JSON object for the SKE cluster, used by the Forgejo Connector building block."
}

variable "harbor_push_username" {
  type      = string
  sensitive = true
  nullable  = false
}

variable "harbor_push_password" {
  type      = string
  sensitive = true
  nullable  = false
}

variable "harbor_pull_username" {
  type      = string
  sensitive = true
  nullable  = false
}

variable "harbor_pull_password" {
  type      = string
  sensitive = true
  nullable  = false
}

locals {
  ske_kubeconfig = jsondecode(var.ske_kubeconfig)
}

resource "random_string" "suffix" {
  length  = 16
  special = false
  upper   = false
  numeric = false
}

module "meshstack_kubernetes_platform" {
  source = "./meshstack_kubernetes_platform"

  kube_host   = jsondecode(var.ske_kubeconfig)["clusters"][0]["cluster"]["server"]
  workspace   = var.test_context.workspace
  test_suffix = random_string.suffix.result
}

module "stackit_git_repository" {
  source = "../../../stackit/git-repository"
  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags = {
      "BBEnvironment" = ["dev"]
    }
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
  source = "../../forgejo-connector"
  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags = {
      "BBEnvironment" = ["dev"]
    }
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  kubeconfig                   = local.ske_kubeconfig
  forgejo_host                 = var.test_context.forgejo_base_url
  forgejo_api_token            = var.stackit_git_forgejo_token
  forgejo_repo_definition_uuid = module.stackit_git_repository.building_block_definition.uuid
  harbor_username              = var.harbor_push_username
  harbor_password              = var.harbor_push_password
}

module "ske_starterkit" {
  source = "../"
  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags = {
      "BBEnvironment" = ["dev"]
    }
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  full_platform_identifier = module.meshstack_kubernetes_platform.full_platform_identifier
  landing_zone_identifiers = {
    dev  = module.meshstack_kubernetes_platform.landing_zone_identifiers.dev
    prod = module.meshstack_kubernetes_platform.landing_zone_identifiers.prod
  }
  repo_clone_addr        = "https://github.com/likvid-bank/starterkit-template-stackit-ai-summarizer.git"
  dns_zone_name          = "meshcloud-dev-ske-starterkit"
  add_random_name_suffix = false

  building_block_definitions = {
    "git-repository"    = module.stackit_git_repository.building_block_definition
    "forgejo-connector" = module.forgejo_connector.building_block_definition
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

resource "meshstack_building_block_v2" "this" {
  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = module.ske_starterkit.building_block_definition.version_ref

    display_name = "smoke-test-ske-starterkit-hub-${var.test_context.name_suffix}"
    target_ref = {
      kind       = "meshWorkspace"
      identifier = var.test_context.workspace
    }

    inputs = {
      name = { value_string = "smoke-test-${var.test_context.name_suffix}" }
    }
  }

  depends_on = [module.meshstack_kubernetes_platform]
}
