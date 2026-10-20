module "workload_identity" {
  source = "../../workload-identity"

  name                         = var.name
  workload_identity_federation = var.workload_identity_federation

  # The cluster, its node pool and add-ons, and the servers, disks, key pair, KMS key and elastic IP
  # behind them, in whichever project the building block is ordered on.
  policies = {
    iam = { scope = "domain", actions = ["iam:*:get*", "iam:*:list*"] }
    cce = { scope = "all_projects", actions = ["cce:*:*", "ecs:*:*", "evs:*:*", "ims:*:*", "vpc:*:*", "elb:*:*", "kms:*:*"] }
  }
}
