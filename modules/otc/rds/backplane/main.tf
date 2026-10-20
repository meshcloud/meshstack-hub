module "workload_identity" {
  source = "../../workload-identity"

  name                         = var.name
  workload_identity_federation = var.workload_identity_federation

  # The instance, its KMS key, security group, elastic IP and alarm rule, in whichever project the
  # building block is ordered on.
  policies = {
    iam = { scope = "domain", actions = ["iam:*:get*", "iam:*:list*"] }
    rds = { scope = "all_projects", actions = ["rds:*:*", "vpc:*:*", "kms:*:*", "ces:*:*"] }
  }
}
