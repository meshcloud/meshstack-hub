# A `buildingblock` directory is a meshStack root module: the meshStack Terraform runner checks it
# out and runs `tofu plan` and `tofu apply` inside it. Provider configuration therefore belongs
# here, and this module configures several providers because it touches several systems in one run.

locals {
  # STACKIT serves PostgreSQL Flex and Object Storage from one endpoint per region, and this module
  # fixes the region at eu01 rather than taking it as an input. That mirrors
  # `modules/stackit/storage-bucket/buildingblock/provider.tf`, which fixes the same value for the
  # same reason: the S3 endpoint URL carries the region, so the two cannot be set apart.
  stackit_region      = "eu01"
  stackit_s3_endpoint = "https://object.storage.${local.stackit_region}.onstackit.cloud"

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

# STACKIT, where the tenant's Postgres database, its owner user and its bucket are created. Both
# submodules this module sources for that declare no provider of their own, so they inherit this one.
provider "stackit" {
  # The Object Storage resources of the bucket submodule take the region as an optional attribute and
  # fall back to this value, so it is what puts them in eu01. The PostgreSQL Flex resources take it
  # explicitly, from `local.stackit_region` as well.
  default_region = local.stackit_region

  # A key, not workload identity federation. See the STACKIT credential section of the module README
  # for why, and for what it would take to move.
  service_account_key = var.stackit_service_account_key
}

# The `aws` provider is configured as a generic S3 client against the STACKIT Object Storage
# endpoint. The bucket is created with it and not with the stackit provider, because the stackit
# provider has no permission to create a bucket. This block mirrors
# `modules/stackit/storage-bucket/buildingblock/provider.tf`, including the region.
provider "aws" {
  access_key = var.stackit_s3_admin_access_key
  secret_key = var.stackit_s3_admin_secret_access_key
  region     = local.stackit_region

  endpoints {
    s3 = local.stackit_s3_endpoint
  }

  # STACKIT Object Storage is StorageGRID behind an S3 API, so every check the provider would run
  # against AWS itself has to be skipped: there is no STS to validate the credential with, 'eu01' is
  # not an AWS region name, there is no account id to request and there is no instance metadata
  # service. Buckets are addressed as a path on the endpoint, because virtual-hosted style would
  # need a DNS record per bucket.
  skip_credentials_validation = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true
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
