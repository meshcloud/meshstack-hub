locals {
  # Temporary credentials the pre-run script got through workload identity federation. Without the
  # file, as outside meshStack, the provider reads OS_ACCESS_KEY and OS_SECRET_KEY from the environment.
  credentials_file = "${path.root}/otc_credentials.json"
  credentials      = fileexists(local.credentials_file) ? jsondecode(file(local.credentials_file)) : null
}

# OS_AUTH_URL and OS_DOMAIN_NAME come from the environment the meshStack integration sets. The
# cluster lives in the project this building block is ordered on.
provider "opentelekomcloud" {
  region    = var.region
  tenant_id = var.project_id

  access_key     = local.credentials == null ? null : local.credentials.access
  secret_key     = local.credentials == null ? null : local.credentials.secret
  security_token = local.credentials == null ? null : local.credentials.securitytoken
}
