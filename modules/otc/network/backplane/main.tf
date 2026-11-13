module "workload_identity" {
  source = "../../workload-identity"

  name                         = var.name
  workload_identity_federation = var.workload_identity_federation
  runner_uuid                  = var.runner_uuid
  original_runner_uuid         = var.original_runner_uuid
  trusted_runner_identities    = var.trusted_runner_identities

  # VPC, subnet, NAT gateway and its elastic IP, in whichever project the building block is ordered on.
  policies = {
    iam     = { scope = "domain", actions = ["iam:*:get*", "iam:*:list*"] }
    network = { scope = "all_projects", actions = ["vpc:*:*", "nat:*:*"] }
  }
}
