module "workload_identity" {
  source = "../../workload-identity"

  name                         = var.name
  workload_identity_federation = var.workload_identity_federation

  # The upstream module creates an IAM user, a group and custom roles for every bucket, which only
  # Security Administrator may do.
  domain_roles = ["secu_admin"]

  # OBS buckets are global; their KMS keys live in the region's project the provider targets.
  policies = {
    obs = { scope = "obs", actions = ["obs:*:*"] }
    kms = { scope = "region", actions = ["kms:*:*"] }
  }
}

# Before the shared module, this backplane declared the same resources itself.
moved {
  from = opentelekomcloud_identity_group_v3.building_block
  to   = module.workload_identity.opentelekomcloud_identity_group_v3.building_block
}

moved {
  from = opentelekomcloud_identity_role_assignment_v3.security_administrator
  to   = module.workload_identity.opentelekomcloud_identity_role_assignment_v3.domain_role["secu_admin"]
}

moved {
  from = opentelekomcloud_identity_role_v3.obs
  to   = module.workload_identity.opentelekomcloud_identity_role_v3.policy["obs"]
}

moved {
  from = opentelekomcloud_identity_role_assignment_v3.obs
  to   = module.workload_identity.opentelekomcloud_identity_role_assignment_v3.policy_obs["obs"]
}

moved {
  from = opentelekomcloud_identity_role_v3.kms
  to   = module.workload_identity.opentelekomcloud_identity_role_v3.policy["kms"]
}

moved {
  from = opentelekomcloud_identity_role_assignment_v3.kms
  to   = module.workload_identity.opentelekomcloud_identity_role_assignment_v3.policy_region["kms"]
}

moved {
  from = opentelekomcloud_identity_provider.building_block
  to   = module.workload_identity.opentelekomcloud_identity_provider.building_block
}
