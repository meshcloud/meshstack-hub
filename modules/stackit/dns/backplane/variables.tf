variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID where the service account will be created."
}

variable "zone_project_ids" {
  type     = set(string)
  nullable = false
  default  = []

  description = <<-EOT
  STACKIT projects that own the zones the building block writes into. The service account is granted
  `dns.admin` on each of them, at **project** scope.

  Use this wherever the projects are knowable when the backplane is deployed — a composition that
  fixes the zone project as a static input, or the delegation path, where the parent zone's project
  is named by `delegation.parent_zone_project_id`. Fall back to `folder_id` only when they are not.
  EOT
}

variable "folder_id" {
  type     = string
  nullable = true
  default  = null

  description = <<-EOT
  STACKIT folder ID under which the zones' projects live. The service account is granted `dns.admin`
  on this folder, which covers every project below it.

  This is the fallback for the one case where no project can be named: the `TENANT_LEVEL` building
  block definition takes its `project_id` from `PLATFORM_TENANT_ID`, so the zone lands in whichever
  tenant project places the order. Prefer `zone_project_ids` whenever the projects are known.
  STACKIT offers no dns role at organization scope, so a folder is the widest scope available for it.
  EOT

  validation {
    condition     = var.folder_id != null || length(var.zone_project_ids) > 0
    error_message = "The service account needs dns.admin somewhere. Name the zones' projects in zone_project_ids, or set folder_id when the target project is unknowable at grant time."
  }
}

variable "organization_id" {
  type        = string
  nullable    = false
  description = "STACKIT organization ID the folder lives under. The service account is granted 'iam.member-admin' here, which lets the building block assign 'dns.admin' to the DNS service account it creates."
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer URL and subject list for the meshStack building block identity provider."
}

variable "service_account_name" {
  type        = string
  default     = "mesh-dns"
  nullable    = false
  description = "Name of the service account created in the STACKIT project. Override when deploying multiple backplane instances in the same project."
}

variable "additional_organization_roles" {
  type        = list(string)
  default     = []
  nullable    = false
  description = "Extra STACKIT roles granted to the service account at organization scope. Use this for the role your organization uses to create service accounts and service account keys in tenant projects, which the building block needs for the DNS credential. See backplane/README.md."
}
