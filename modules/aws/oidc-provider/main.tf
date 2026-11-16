# AWS registers an OIDC provider per issuer URL per AWS account, so the meshStack runner's issuer
# can only be registered once in an account no matter how many building block backplanes federate
# through it. That makes it platform infrastructure rather than something a backplane owns — see
# .agents/references/aws-backplane.md#the-shared-oidc-provider.

variable "workload_identity_federation" {
  type = object({
    issuer    = string
    audiences = list(string)
  })
  nullable    = false
  description = "`issuer` is the URL of the issuer of the runner tokens. `audiences` usually has one value, the AWS audience of the runner. AWS allows one provider per issuer and account. Two runners whose tokens come from the same issuer share the provider, so add the audience of both. The `meshstack_building_block_runner` data source returns both values in `spec.workload_identity_federation`."
}

data "tls_certificate" "issuer" {
  url = var.workload_identity_federation.issuer
}

resource "aws_iam_openid_connect_provider" "meshstack" {
  url            = var.workload_identity_federation.issuer
  client_id_list = var.workload_identity_federation.audiences

  # This issuer is not in the AWS trust store, unlike the well-known providers, so the thumbprint
  # is required. AWS documents taking it from the root of the issuer's TLS chain, which the
  # `tls_certificate` data source returns last.
  thumbprint_list = [
    data.tls_certificate.issuer.certificates[length(data.tls_certificate.issuer.certificates) - 1].sha1_fingerprint
  ]
}
