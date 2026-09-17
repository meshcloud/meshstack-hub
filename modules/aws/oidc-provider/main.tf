# AWS registers an OIDC provider per issuer URL per AWS account, so the meshStack runner's issuer
# can only be registered once in an account no matter how many building block backplanes federate
# through it. That makes it platform infrastructure rather than something a backplane owns — see
# .agents/references/aws-backplane.md#the-shared-oidc-provider.
#
# Apply this once per AWS account that hosts building block backplanes and pass its `arn` output to
# every backplane in that account.

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    audience = string
  })
  nullable    = false
  description = "OIDC issuer URL and AWS audience of the meshStack building block runner. Take `issuer` and `aws.audience` from `status.workload_identity_federation` of any building block definition that runs on it."
}

data "tls_certificate" "issuer" {
  url = var.workload_identity_federation.issuer
}

resource "aws_iam_openid_connect_provider" "meshstack" {
  url            = var.workload_identity_federation.issuer
  client_id_list = [var.workload_identity_federation.audience]

  # This issuer is not in the AWS trust store, unlike the well-known providers, so the thumbprint
  # is required. AWS documents taking it from the root of the issuer's TLS chain, which the
  # `tls_certificate` data source returns last.
  thumbprint_list = [
    data.tls_certificate.issuer.certificates[length(data.tls_certificate.issuer.certificates) - 1].sha1_fingerprint
  ]
}
