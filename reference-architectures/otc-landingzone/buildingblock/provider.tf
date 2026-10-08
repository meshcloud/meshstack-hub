# AK/SK authentication requires a project, and the region's own project always exists. IAM
# resources do not depend on it: the provider sends them through a separate domain-scoped client.
provider "opentelekomcloud" {
  auth_url    = local.auth_url
  domain_name = var.otc_domain_name
  tenant_name = var.otc_region
  region      = var.otc_region
  access_key  = var.otc_access_key
  secret_key  = var.otc_secret_key
}
