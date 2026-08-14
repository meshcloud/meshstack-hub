# A `buildingblock` directory is a meshStack root module: the meshStack Terraform runner checks it
# out and runs `tofu plan` and `tofu apply` inside it. Provider configuration therefore belongs
# here, and this module configures four providers because one order touches four systems.

locals {
  # `modules/ai/model-access` fixes the same value for the same reason: the STACKIT Object Storage
  # endpoint URL carries the region, so the two cannot be set apart, and the two modules have to
  # agree on where the shared Postgres instance and the tenants' buckets live.
  stackit_region = "eu01"

  ai_kubeconfig         = yamldecode(var.ai_cluster_kubeconfig)
  ai_kubeconfig_cluster = one(local.ai_kubeconfig["clusters"])["cluster"]
  ai_kubeconfig_user    = one(local.ai_kubeconfig["users"])["user"]

  # The gateway module configures its own providers and therefore takes the three values apart
  # rather than the kubeconfig as a whole. Its `cluster_endpoint` carries no scheme.
  ai_cluster_host                   = local.ai_kubeconfig_cluster["server"]
  ai_cluster_endpoint               = replace(local.ai_cluster_host, "https://", "")
  ai_cluster_ca_certificate_base64  = local.ai_kubeconfig_cluster["certificate-authority-data"]
  ai_cluster_token                  = try(local.ai_kubeconfig_user["token"], null)
  ai_cluster_client_certificate_pem = try(base64decode(local.ai_kubeconfig_user["client-certificate-data"]), null)
  ai_cluster_client_key_pem         = try(base64decode(local.ai_kubeconfig_user["client-key-data"]), null)
}

# The AI platform cluster, where the gateway and the shared ClickHouse are installed. A service
# account token is what a platform team usually hands out; the certificate pair is accepted as well,
# because that is what a managed cluster's credential API returns — STACKIT SKE among them.
provider "kubernetes" {
  host                   = local.ai_cluster_host
  cluster_ca_certificate = base64decode(local.ai_cluster_ca_certificate_base64)

  token              = local.ai_cluster_token
  client_certificate = local.ai_cluster_client_certificate_pem
  client_key         = local.ai_cluster_client_key_pem
}

# Helm talks to the same control plane with the same credentials, so both charts land in the AI
# platform cluster without extra wiring.
provider "helm" {
  kubernetes = {
    host                   = local.ai_cluster_host
    cluster_ca_certificate = base64decode(local.ai_cluster_ca_certificate_base64)

    token              = local.ai_cluster_token
    client_certificate = local.ai_cluster_client_certificate_pem
    client_key         = local.ai_cluster_client_key_pem
  }
}

# STACKIT, where the gateway's own database is created inside the shared PostgreSQL Flex instance.
# The sourced `postgresflex/buildingblock/database` module declares no provider of its own and
# inherits this one.
#
# A key, not workload identity federation, for the same reason `modules/ai/model-access` uses one:
# a federated identity provider has to assert the subject of this building block definition, and
# creating one needs a backplane this architecture does not have.
provider "stackit" {
  default_region      = local.stackit_region
  service_account_key = var.stackit_service_account_key
}

# meshStack injects the credentials of an ephemeral API token into the run environment, so the
# provider needs no configuration. The token carries the permissions listed in
# `version_spec.permissions` of the building block definition.
provider "meshstack" {}
