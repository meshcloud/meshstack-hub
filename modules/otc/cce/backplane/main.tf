module "workload_identity" {
  source = "../../workload-identity"

  name                         = var.name
  workload_identity_federation = var.workload_identity_federation

  # What the CCE documentation names for creating clusters and nodes, in whichever project the
  # building block is ordered on. CCE itself acts through the cce_admin_trust agency below. Names as
  # IAM lists them, display name alongside.
  project_roles = [
    "system_all_27", # CCE FullAccess: cluster, node pool and add-ons
    "system_all_51", # ECS FullAccess: the nodes' servers and key pair
    "vpc_netadm",    # VPC Administrator: the API server's elastic IP
  ]

  policies = {
    iam = { scope = "domain", actions = ["iam:*:get*", "iam:*:list*"] }
  }
}

# CCE manages nodes and networks through this agency, which the CCE console otherwise creates on a
# user's first visit to a region. It is one per domain, holds Tenant Administrator for CCE's own
# service account, and creating it takes IAM permissions the building block must not have. On the
# region's project alone, CCE cannot see the networks of the projects below it ("VPC not found").
resource "opentelekomcloud_identity_agency_v3" "cce_admin_trust" {
  lifecycle {
    enabled = var.create_cce_admin_trust
  }

  name                  = "cce_admin_trust"
  description           = "Lets CCE manage the resources of its clusters."
  delegated_domain_name = "op_svc_cce"

  project_role {
    all_projects = true
    roles        = ["Tenant Administrator"]
  }
}
