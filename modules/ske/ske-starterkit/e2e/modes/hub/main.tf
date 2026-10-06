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
    dns_zone_name                 = string

    fixtures = object({
      stackit = object({
        project_id                  = string
        secrets_manager_instance_id = string
      })
    })
  })
  nullable = false
}

variable "backplane_secrets" {
  type = object({
    stackit_git_forgejo_api_token = string
    ske_kubeconfig                = string
    harbor_push_username          = string
    harbor_push_password          = string
    harbor_pull_username          = string
    harbor_pull_password          = string
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

  secrets_manager_address     = "https://prod.sm.eu01.stackit.cloud"
  secrets_manager_instance_id = var.test_context.fixtures.stackit.secrets_manager_instance_id

  # Runs share the fixture instance, so each one writes only under its own id.
  vault_paths = {
    forgejo_api_token = "${var.test_context.run_id}/git/forgejo-api-token"
    registry_push     = "${var.test_context.run_id}/registry/push"
    registry_pull     = "${var.test_context.run_id}/registry/pull"
    ai                = "${var.test_context.run_id}/ai/model-serving"
  }
}

resource "stackit_secretsmanager_user" "writer" {
  project_id    = var.test_context.fixtures.stackit.project_id
  instance_id   = local.secrets_manager_instance_id
  description   = "${var.test_context.run_id} ske-starterkit writer"
  write_enabled = true
}

resource "stackit_secretsmanager_user" "reader" {
  project_id    = var.test_context.fixtures.stackit.project_id
  instance_id   = local.secrets_manager_instance_id
  description   = "${var.test_context.run_id} ske-starterkit reader"
  write_enabled = false
}

resource "vault_kv_secret_v2" "forgejo_api_token" {
  mount                = local.secrets_manager_instance_id
  name                 = local.vault_paths.forgejo_api_token
  data_json_wo         = jsonencode({ forgejo_api_token = var.backplane_secrets.stackit_git_forgejo_api_token })
  data_json_wo_version = 1
}

resource "vault_kv_secret_v2" "registry_push" {
  mount                = local.secrets_manager_instance_id
  name                 = local.vault_paths.registry_push
  data_json_wo         = jsonencode({ username = var.backplane_secrets.harbor_push_username, password = var.backplane_secrets.harbor_push_password })
  data_json_wo_version = 1
}

resource "vault_kv_secret_v2" "registry_pull" {
  mount                = local.secrets_manager_instance_id
  name                 = local.vault_paths.registry_pull
  data_json_wo         = jsonencode({ username = var.backplane_secrets.harbor_pull_username, password = var.backplane_secrets.harbor_pull_password })
  data_json_wo_version = 1
}

# Smoke tests don't exercise real inference. The app only needs the `stackit-ai` secret to exist so
# its pods can start: the app chart mounts it via `envFrom`, and `helm --wait --atomic` rolls the
# deploy back while a pod waits for a missing secret.
resource "vault_kv_secret_v2" "ai" {
  mount = local.secrets_manager_instance_id
  name  = local.vault_paths.ai
  data_json_wo = jsonencode({
    STACKIT_AI_BASE_URL = "https://ai.invalid/v1"
    STACKIT_AI_API_KEY  = "dummy-smoke-test"
    STACKIT_AI_MODEL    = "dummy-model"
  })
  data_json_wo_version = 1
}

# The connector takes the token kubeconfig of a cluster-admin service account, as the STACKIT
# Kubernetes reference architecture gives it.
resource "kubernetes_service_account_v1" "connector" {
  metadata {
    name      = "${var.test_context.run_id}-connector"
    namespace = "kube-system"
  }
}

resource "kubernetes_secret_v1" "connector_token" {
  metadata {
    name      = "${var.test_context.run_id}-connector"
    namespace = "kube-system"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.connector.metadata[0].name
    }
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}

resource "kubernetes_cluster_role_binding_v1" "connector" {
  metadata {
    name = "${var.test_context.run_id}-connector"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.connector.metadata[0].name
    namespace = "kube-system"
  }
}

locals {
  connector_kubeconfig = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = "connector"
    clusters = [{
      name    = local.ske_kubeconfig["clusters"][0]["name"]
      cluster = local.ske_kubeconfig["clusters"][0]["cluster"]
    }]
    users = [{
      name = "connector"
      user = { token = kubernetes_secret_v1.connector_token.data["token"] }
    }]
    contexts = [{
      name    = "connector"
      context = { cluster = local.ske_kubeconfig["clusters"][0]["name"], user = "connector" }
    }]
  })
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
  forgejo_organization = var.test_context.forgejo_organization

  vault_reader = {
    address  = local.secrets_manager_address
    mount    = local.secrets_manager_instance_id
    username = stackit_secretsmanager_user.reader.username
    password = stackit_secretsmanager_user.reader.password
  }
  forgejo_api_token_path = vault_kv_secret_v2.forgejo_api_token.name
  registry_push_path     = vault_kv_secret_v2.registry_push.name

  stackit_service_account_email = var.test_context.stackit_service_account_email
  stackit_project_id            = var.test_context.stackit_project_id
  stackit_git_instance_id       = var.test_context.stackit_git_instance_id

  action_variables = {
    HARBOR_REGISTRY = "registry.onstackit.cloud"
    HARBOR_PROJECT  = "stackit_kubernetes_platform" # TODO
    APP_NAME        = var.test_context.run_id       # TODO
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

  kubeconfig                   = local.connector_kubeconfig
  forgejo_host                 = var.test_context.forgejo_base_url
  forgejo_repo_definition_uuid = module.stackit_git_repository.building_block_definition.uuid

  vault_reader = {
    address  = local.secrets_manager_address
    mount    = local.secrets_manager_instance_id
    username = stackit_secretsmanager_user.reader.username
    password = stackit_secretsmanager_user.reader.password
  }
  forgejo_api_token_path = vault_kv_secret_v2.forgejo_api_token.name
  registry_pull_path     = vault_kv_secret_v2.registry_pull.name

  additional_kubernetes_secrets = {
    "stackit-ai" = vault_kv_secret_v2.ai.name
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
  dns_zone_name          = var.test_context.dns_zone_name
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
