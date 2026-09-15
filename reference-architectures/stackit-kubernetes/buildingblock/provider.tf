# The meshstack provider is configured by the meshStack runtime at order time (mesh http backend), so
# it is intentionally not declared here.

# Authentication comes entirely from the environment via Workload Identity Federation:
# STACKIT_SERVICE_ACCOUNT_EMAIL, STACKIT_USE_OIDC and STACKIT_FEDERATED_TOKEN_FILE are injected by
# meshStack. The architecture's backplane (registered with the definition) provisions the identity.
provider "stackit" {
  default_region = var.stackit_region
  # Required for the authorization role assignments the nested SKE Cluster backplane creates.
  experiments = ["iam"]
}

# Forgejo organization management on the STACKIT Git instance.
#
# The uri is built from the instance name rather than read from stackit_git.this.url on purpose: the
# git instance is created in this same apply and lives in a project that itself comes from a
# same-apply meshStack tenant, so stackit_git.this.url is unknown at plan time — and a provider
# configuration must be known at plan time. The public URL of a STACKIT Git instance is
# deterministically `https://<name>.git.onstackit.cloud`, so we can construct it from the known input.
provider "restapi" {
  uri                  = "https://${var.git_instance_name}.git.onstackit.cloud"
  write_returns_object = true

  # coalesce keeps this a valid string on the first run, when the token is still null and no restapi
  # resource is active anyway (the organization is gated off until the token is provided).
  headers = {
    Authorization = "token ${coalesce(var.forgejo_token, "unset")}"
    Content-Type  = "application/json"
  }
}
