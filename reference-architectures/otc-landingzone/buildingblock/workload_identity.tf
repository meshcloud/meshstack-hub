# EXPERIMENT: workload identity federation instead of the admin access key.
#
# The provider cannot exchange an OIDC token itself. So this run federates meshStack's run identity
# as a programmatic OIDC identity provider, and prerun.sh exchanges the run's token for temporary
# credentials on the next run. The first run still needs the admin access key to create it.

variable "workload_identity_token_path" {
  type        = string
  default     = "/var/run/secrets/workload-identity/gcp/token"
  nullable    = false
  description = "Run token meshStack mounts. Any of its audiences works; IAM only checks the one registered as client ID."
}

locals {
  workload_identity_enabled = fileexists(var.workload_identity_token_path)

  # Issuer, subject and audience come from the run's own token, so this definition needs no input
  # naming them. A JWT payload is unpadded base64url.
  workload_identity_payload = local.workload_identity_enabled ? split(".", trimspace(file(var.workload_identity_token_path)))[1] : ""
  workload_identity_claims = local.workload_identity_enabled ? jsondecode(base64decode(join("", [
    replace(replace(local.workload_identity_payload, "-", "+"), "_", "/"),
    substr("==", 0, (4 - length(local.workload_identity_payload) % 4) % 4),
  ]))) : null

  workload_identity_audience = local.workload_identity_enabled ? one(flatten([local.workload_identity_claims.aud])) : null

  # Written by prerun.sh when it signed in through workload identity federation.
  workload_identity_credentials_file = "${path.root}/otc_wif_credentials.json"
  workload_identity_credentials      = fileexists(local.workload_identity_credentials_file) ? jsondecode(file(local.workload_identity_credentials_file)) : null
}

data "http" "workload_identity_jwks" {
  lifecycle {
    enabled = local.workload_identity_enabled

    postcondition {
      condition     = self.status_code == 200
      error_message = "Reading the signing keys of the meshStack issuer answered HTTP ${self.status_code}."
    }
  }

  url = "${trimsuffix(local.workload_identity_claims.iss, "/")}/jwks"
}

resource "opentelekomcloud_identity_provider" "workload_identity" {
  lifecycle {
    enabled = local.workload_identity_enabled
  }

  name        = "meshstack-${local.platform_identifier}"
  protocol    = "oidc"
  description = "meshStack building block runs of this reference architecture; programmatic access only."
  status      = true

  # EXPERIMENT: the admin group, to match the admin access key this replaces.
  mapping_rules = jsonencode([
    {
      local  = [{ user = { name = "meshstack-${local.platform_identifier}" } }, { group = { name = "admin" } }]
      remote = [{ type = "sub", any_one_of = [local.workload_identity_claims.sub] }]
    }
  ])

  access_config {
    access_type  = "program"
    provider_url = local.workload_identity_claims.iss
    client_id    = local.workload_identity_audience
    signing_key  = data.http.workload_identity_jwks.response_body
  }
}

output "workload_identity_provider" {
  value       = local.workload_identity_enabled ? opentelekomcloud_identity_provider.workload_identity.name : null
  description = "Identity provider prerun.sh signs in through. Read from the previous run's state."
}

output "workload_identity_signed_in" {
  value       = local.workload_identity_credentials != null
  description = "Whether this run authenticated through workload identity federation instead of the admin access key."
}
