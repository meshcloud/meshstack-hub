# AWS registers an OIDC provider per issuer URL per AWS account, so the meshStack runner's issuer
# can only be registered once in an account no matter how many building block backplanes federate
# through it. That makes it platform infrastructure rather than something a backplane owns — see
# .agents/references/aws-backplane.md#the-shared-oidc-provider.
#
# Apply this once per AWS account that hosts building block backplanes and pass its `arn` output to
# every backplane in that account.

variable "building_block_runner_uuid" {
  type        = string
  default     = null
  description = "Registers the issuer of this meshStack building block runner instead of the shared one meshStack hosts."
}

data "meshstack_building_block_runner" "this" {
  metadata = {
    uuid = var.building_block_runner_uuid
  }
}

locals {
  workload_identity_federation = data.meshstack_building_block_runner.this.spec.workload_identity_federation
}

data "tls_certificate" "issuer" {
  url = local.workload_identity_federation.issuer
}

resource "aws_iam_openid_connect_provider" "meshstack" {
  url            = local.workload_identity_federation.issuer
  client_id_list = [local.workload_identity_federation.aws.audience]

  # This issuer is not in the AWS trust store, unlike the well-known providers, so the thumbprint
  # is required. AWS documents taking it from the root of the issuer's TLS chain, which the
  # `tls_certificate` data source returns last.
  thumbprint_list = [
    data.tls_certificate.issuer.certificates[length(data.tls_certificate.issuer.certificates) - 1].sha1_fingerprint
  ]
}
