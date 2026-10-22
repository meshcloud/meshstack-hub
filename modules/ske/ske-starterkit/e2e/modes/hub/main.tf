# Stands up an ephemeral meshPlatform and the two definitions the starter kit creates child building
# blocks from, then builds the starter kit definition itself from hub source.
variable "test_context" {
  type = object({
    hub_git_ref          = string
    workspace            = string
    run_id               = string
    forgejo_base_url     = string
    forgejo_organization = string

    stackit_service_account_email = string
    stackit_project_id            = string
    stackit_git_instance_id       = string

    fixtures = object({
      stackit = object({
        project_id                  = string
        secrets_manager_instance_id = string
        secrets_path_prefix         = string
        ske_platform = object({
          project_id    = string
          kube_host     = string
          registry_name = string
        })
        dns = object({
          zone_name = string
        })
      })
    })
  })
  nullable = false
}

locals {
  secrets_manager_address     = "https://prod.sm.eu01.stackit.cloud"
  secrets_manager_instance_id = var.test_context.fixtures.stackit.secrets_manager_instance_id
  secrets_path_prefix         = var.test_context.fixtures.stackit.secrets_path_prefix

  ske_kubeconfig = yamldecode(ephemeral.vault_kv_secret_v2.ske_kubeconfig.data.kubeconfig)
}

resource "stackit_secretsmanager_user" "reader" {
  project_id    = var.test_context.fixtures.stackit.ske_platform.project_id
  instance_id   = local.secrets_manager_instance_id
  description   = "${var.test_context.run_id} ske-starterkit reader"
  write_enabled = false
}

ephemeral "vault_kv_secret_v2" "ske_kubeconfig" {
  # Defers the read to apply, when the user the vault provider logs in with exists.
  depends_on = [stackit_secretsmanager_user.reader]

  mount = local.secrets_manager_instance_id
  name  = "${local.secrets_path_prefix}ske/cluster"
}

module "meshstack_kubernetes_platform" {
  source = "./meshstack_kubernetes_platform"

  kube_host = var.test_context.fixtures.stackit.ske_platform.kube_host
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
  forgejo_organization = var.test_context.forgejo_organization

  vault_reader = {
    address  = local.secrets_manager_address
    mount    = local.secrets_manager_instance_id
    username = stackit_secretsmanager_user.reader.username
    password = stackit_secretsmanager_user.reader.password
  }
  forgejo_api_token_path = "${local.secrets_path_prefix}stackit/git"
  registry_secret_path   = "${local.secrets_path_prefix}stackit/container-registry"

  stackit_service_account_email = var.test_context.stackit_service_account_email
  stackit_project_id            = var.test_context.stackit_project_id
  stackit_git_instance_id       = var.test_context.stackit_git_instance_id

  action_variables = {
    HARBOR_REGISTRY = "registry.onstackit.cloud"
    HARBOR_PROJECT  = var.test_context.fixtures.stackit.ske_platform.registry_name
    APP_NAME        = var.test_context.run_id
  }
}

# Only this test knows the uuid of its definition, so it federates the fixture service account with it.
resource "stackit_service_account_federated_identity_provider" "git_repository" {
  project_id            = var.test_context.fixtures.stackit.project_id
  service_account_email = var.test_context.stackit_service_account_email
  name                  = "${var.test_context.run_id}-git-repository"
  issuer                = module.stackit_git_repository.building_block_definition.version_ref.workload_identity_federation.issuer

  assertions = [
    {
      item     = "aud"
      operator = "equals"
      value    = "api://AzureADTokenExchange"
    },
    {
      item     = "sub"
      operator = "equals"
      value    = module.stackit_git_repository.building_block_definition.version_ref.workload_identity_federation.subject
    }
  ]
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

  kube_host                    = var.test_context.fixtures.stackit.ske_platform.kube_host
  forgejo_host                 = var.test_context.forgejo_base_url
  forgejo_repo_definition_uuid = module.stackit_git_repository.building_block_definition.uuid

  vault_reader = {
    address  = local.secrets_manager_address
    mount    = local.secrets_manager_instance_id
    username = stackit_secretsmanager_user.reader.username
    password = stackit_secretsmanager_user.reader.password
  }
  kubeconfig_path        = "${local.secrets_path_prefix}ske/cluster"
  forgejo_api_token_path = "${local.secrets_path_prefix}stackit/git"
  registry_secret_path   = "${local.secrets_path_prefix}stackit/container-registry"

  # The app chart mounts this secret via `envFrom`.
  additional_kubernetes_secrets = {
    "stackit-ai" = "${local.secrets_path_prefix}stackit/ai-llm"
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
  app_name               = "ai-summarizer"
  repo_clone_addr        = "https://github.com/likvid-bank/starterkit-template-stackit-ai-summarizer.git"
  dns_zone_name          = var.test_context.fixtures.stackit.dns.zone_name
  add_random_name_suffix = false

  building_block_definition_version_refs = {
    "git-repository"    = module.stackit_git_repository.building_block_definition.version_ref
    "forgejo-connector" = module.forgejo_connector.building_block_definition.version_ref
  }

  project_tags = {
    stages = {
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
}

output "version_ref" {
  value = module.ske_starterkit.building_block_definition.version_ref
}
