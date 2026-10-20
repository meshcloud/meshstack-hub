# AK/SK authentication requires a project, and the region's own project always exists. IAM
# resources do not depend on it: the provider sends them through a separate domain-scoped client.
provider "opentelekomcloud" {
  auth_url    = local.auth_url
  domain_name = var.otc_domain_name
  tenant_name = var.otc_region
  region      = var.otc_region

  access_key     = local.workload_identity_credentials != null ? local.workload_identity_credentials.access : var.otc_access_key
  secret_key     = local.workload_identity_credentials != null ? local.workload_identity_credentials.secret : var.otc_secret_key
  security_token = local.workload_identity_credentials != null ? local.workload_identity_credentials.securitytoken : null
}
