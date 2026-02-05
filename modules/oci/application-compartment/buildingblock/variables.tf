variable "tenancy_ocid" {
  type        = string
  description = "OCID of the OCI tenancy"
}

variable "foundation" {
  type        = string
  description = "Foundation name prefix"
}

variable "workspace_id" {
  type        = string
  description = "Workspace identifier (e.g., team name or business unit)"
}

variable "project_id" {
  type        = string
  description = "Project identifier (e.g., application name)"
}

variable "region" {
  type        = string
  description = "OCI region identifier (e.g., eu-frankfurt-1, us-ashburn-1)"
}

variable "users" {
  description = "List of users from authoritative system"
  type = list(object({
    meshIdentifier = string
    username       = string
    firstName      = string
    lastName       = string
    email          = string
    euid           = string
    roles          = list(string)
  }))
  default = []
}

variable "tag_relations" {
  type        = string
  description = "YAML configuration for tag-based compartment mapping"
  default     = <<-EOT
    # meshStack tag names to read
    tag_names:
      environment: "Environment"
      landing_zone: "landingzone_family"

    # Landing zone configurations
    landing_zones:
      # Sandbox: single compartment for all environments
      sandbox:
        compartment_id: "ocid1.compartment.oc1..aaaaaaaa...sandbox"

      # Cloud-native: per-environment compartments
      cloud-native:
        environments:
          dev:
            compartment_id: "ocid1.compartment.oc1..aaaaaaaa...cloudnative-dev"
          qa:
            compartment_id: "ocid1.compartment.oc1..aaaaaaaa...cloudnative-qa"
          test:
            compartment_id: "ocid1.compartment.oc1..aaaaaaaa...cloudnative-test"
          prod:
            compartment_id: "ocid1.compartment.oc1..aaaaaaaa...cloudnative-prod"

    # Fallback if no match
    default_compartment_id: "ocid1.compartment.oc1..aaaaaaaa...default"
  EOT
}

