# AWS registers an OIDC provider per issuer URL per AWS account, so the meshStack runner's issuer
# can only be registered once in an account no matter how many building block backplanes federate
# through it. That makes it platform infrastructure rather than something a backplane owns — see
# .agents/references/aws-backplane.md#the-shared-oidc-provider.
#
# Apply this once per AWS account that hosts building block backplanes and pass its `arn` output to
# every backplane in that account.

data "meshstack_integrations" "this" {}

locals {
  # The replicator's entry is what Terraform can read. The authority for what a building block run
  # presents is the runner's own registration, and the two agree as long as the runner shares the
  # replicator's cluster and namespace — the assumption every hub module already makes.
  replicator = data.meshstack_integrations.this.workload_identity_federation.replicator
}

resource "aws_iam_openid_connect_provider" "meshstack" {
  url            = local.replicator.issuer
  client_id_list = [local.replicator.aws.audience]

  # This issuer is not in the AWS trust store, unlike the well-known providers, so the thumbprint
  # is required.
  thumbprint_list = [local.replicator.aws.thumbprint]
}
