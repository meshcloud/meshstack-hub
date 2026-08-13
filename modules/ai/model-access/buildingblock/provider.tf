# A `buildingblock` directory is a meshStack root module: the meshStack Terraform runner checks it
# out and runs `tofu plan` and `tofu apply` inside it. Provider configuration therefore belongs
# here, and this module configures several providers because it touches several systems in one run.

locals {
  ai_platform_kubeconfig         = yamldecode(var.ai_platform_cluster_kubeconfig)
  ai_platform_kubeconfig_cluster = one(local.ai_platform_kubeconfig["clusters"])["cluster"]
  ai_platform_kubeconfig_user    = one(local.ai_platform_kubeconfig["users"])["user"]

  demo_app_kubeconfig         = yamldecode(var.demo_app_cluster_kubeconfig)
  demo_app_kubeconfig_cluster = one(local.demo_app_kubeconfig["clusters"])["cluster"]
  demo_app_kubeconfig_user    = one(local.demo_app_kubeconfig["users"])["user"]
}

provider "litellm" {
  api_base = var.litellm_api_base
  api_key  = var.litellm_api_key
}

# The AI platform cluster. The tenant's Langfuse instance is deployed here, next to the shared
# LiteLLM gateway and the shared ClickHouse.
provider "kubernetes" {
  alias = "ai_platform"

  host                   = local.ai_platform_kubeconfig_cluster["server"]
  cluster_ca_certificate = base64decode(local.ai_platform_kubeconfig_cluster["certificate-authority-data"])

  # A service account token is what the platform team hands out. The certificate pair is accepted
  # as well, so a kubeconfig produced by a cluster's own credential API also works.
  token              = try(local.ai_platform_kubeconfig_user["token"], null)
  client_certificate = try(base64decode(local.ai_platform_kubeconfig_user["client-certificate-data"]), null)
  client_key         = try(base64decode(local.ai_platform_kubeconfig_user["client-key-data"]), null)
}

# Helm talks to the same control plane with the same credentials, so the Langfuse namespace, its
# secret and its release all land in the AI platform cluster.
provider "helm" {
  alias = "ai_platform"

  kubernetes = {
    host                   = local.ai_platform_kubeconfig_cluster["server"]
    cluster_ca_certificate = base64decode(local.ai_platform_kubeconfig_cluster["certificate-authority-data"])

    token              = try(local.ai_platform_kubeconfig_user["token"], null)
    client_certificate = try(base64decode(local.ai_platform_kubeconfig_user["client-certificate-data"]), null)
    client_key         = try(base64decode(local.ai_platform_kubeconfig_user["client-key-data"]), null)
  }
}

# The demo application cluster, a different cluster with a different credential. Only the Secret
# carrying the model credential is written here. See the residual risk section of the module README
# for what this credential may do.
provider "kubernetes" {
  alias = "demo_app"

  host                   = local.demo_app_kubeconfig_cluster["server"]
  cluster_ca_certificate = base64decode(local.demo_app_kubeconfig_cluster["certificate-authority-data"])

  token              = try(local.demo_app_kubeconfig_user["token"], null)
  client_certificate = try(base64decode(local.demo_app_kubeconfig_user["client-certificate-data"]), null)
  client_key         = try(base64decode(local.demo_app_kubeconfig_user["client-key-data"]), null)
}

# meshStack injects the credentials of an ephemeral API token into the run environment, so the
# provider needs no configuration. The token carries the permissions listed in
# `version_spec.permissions` of the building block definition, which is `TENANT_LIST` here.
provider "meshstack" {}
