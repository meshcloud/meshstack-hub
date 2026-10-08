# No tenant_name: the deploying user's Security Administrator role is domain-scoped, and a
# project-scoped token would not carry it.
provider "opentelekomcloud" {
  auth_url    = local.auth_url
  domain_name = var.otc_domain_name
  region      = var.otc_region
  access_key  = var.otc_access_key
  secret_key  = var.otc_secret_key
}
