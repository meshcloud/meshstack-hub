locals {
  # Temporary credentials prerun.sh got through workload identity federation. Without the file, as
  # outside meshStack, the provider reads OS_ACCESS_KEY and OS_SECRET_KEY from the environment.
  credentials_file = "${path.root}/otc_credentials.json"
  credentials      = fileexists(local.credentials_file) ? jsondecode(file(local.credentials_file)) : null
}

# OBS and KMS only work on a region's own project, and the upstream module fails the run otherwise,
# so the provider targets that project rather than the application project this building block is
# ordered on. The bucket belongs to the domain either way; only its KMS key lives in the region's
# project. OS_AUTH_URL and OS_DOMAIN_NAME come from the environment the meshStack integration sets.
provider "opentelekomcloud" {
  region      = var.region
  tenant_name = var.region

  access_key     = local.credentials == null ? null : local.credentials.access
  secret_key     = local.credentials == null ? null : local.credentials.secret
  security_token = local.credentials == null ? null : local.credentials.securitytoken
}
