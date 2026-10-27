module "workload_identity" {
  source = "../../workload-identity"

  name                         = var.name
  workload_identity_federation = var.workload_identity_federation

  # What the RDS documentation names for creating an instance, in whichever project the building
  # block is ordered on. It requires KMS Administrator itself for an encrypted instance; a custom
  # `kms:*:*` policy is not enough. Names as IAM lists them, display name alongside.
  project_roles = [
    "system_all_12", # RDS FullAccess
    "kms_adm",       # KMS Administrator: the volume key, and encrypting the instance with it
    "vpc_netadm",    # VPC Administrator: the security group, its rules and the elastic IP
    "system_all_61", # CES FullAccess: the alarm rule
  ]

  policies = {
    iam = { scope = "domain", actions = ["iam:*:get*", "iam:*:list*"] }
  }
}
