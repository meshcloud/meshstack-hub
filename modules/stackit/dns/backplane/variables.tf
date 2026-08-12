variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID where the service account will be created."
}

variable "folder_id" {
  type        = string
  nullable    = false
  description = "STACKIT folder ID under which the zones' projects live. The service account is granted 'dns.admin' on this folder, which covers every project below it, including the parent zone's project on the delegation path. STACKIT offers no dns role at organization scope, so a folder is the widest scope available for it."
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
