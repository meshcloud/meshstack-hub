variable "stackit_project_id" {
  type        = string
  description = "STACKIT project ID the runner VM is created in."
}

variable "stackit_region" {
  type        = string
  description = "STACKIT region for the VM and its network resources."
  default     = "eu01"
}

variable "availability_zone" {
  type        = string
  description = "STACKIT availability zone for the VM and its boot volume."
  default     = "eu01-1"
}

variable "network_id" {
  type        = string
  description = "ID of an existing STACKIT network to attach the runner VM to. Leave null to create a dedicated network for the runner."
  default     = null
}

variable "name" {
  type        = string
  description = "Name of the runner (used for the VM name and the runner registration)."
  default     = "git-runner"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]+$", var.name))
    error_message = "Name must only contain alphanumeric characters, dots, dashes, or underscores."
  }
}

variable "machine_type" {
  type        = string
  description = "STACKIT machine flavor for the runner VM. Verify the flavor exists in the target region before ordering."
  default     = "c1.2"
}

variable "image_id" {
  type        = string
  description = "STACKIT image UUID to boot from (Ubuntu 22.04 recommended). Image UUIDs are region-specific — look up the current one for var.stackit_region."
}

variable "disk_size_gb" {
  type        = number
  description = "Size of the runner VM boot volume in GB."
  default     = 50
}

variable "runner_version" {
  type        = string
  description = "Version of the STACKIT Git Actions runner agent to install on the VM. Pin explicitly so a re-provision is reproducible."
  default     = "6.3.1"
}

variable "runner_labels" {
  type        = list(string)
  description = "STACKIT Git Actions runner labels. Each is either <label>:host (run on the VM) or <label>:docker://<image> (run in that container). Referenced by workflows via runs-on."
  default = [
    "self-hosted:host",
    "stackit-docker:docker://code.forgejo.org/oci/node:20-bookworm",
  ]
}

variable "git_base_url" {
  type        = string
  description = "Base URL of the STACKIT Git instance, e.g. https://<name>.git.onstackit.cloud."
}

variable "git_organization" {
  type        = string
  description = "STACKIT Git organization the runner is registered for. It serves all repositories in this org."
}

variable "git_token" {
  type        = string
  sensitive   = true
  description = "STACKIT Git PAT with organization-admin rights on var.git_organization — used to mint the runner registration token. Not placed on the VM."
}
