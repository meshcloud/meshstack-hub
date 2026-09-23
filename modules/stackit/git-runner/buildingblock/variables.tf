variable "stackit_project_id" {
  type        = string
  description = "STACKIT project ID the runner VM is created in."
}

variable "stackit_region" {
  type        = string
  nullable    = false
  description = "STACKIT region for the VM and its network resources."
}

variable "availability_zone" {
  type        = string
  nullable    = false
  description = "STACKIT availability zone for the VM and its boot volume."
}

variable "network_id" {
  type        = string
  nullable    = false
  description = "Existing STACKIT network to attach the runner VM to. Empty creates a dedicated one."
}

variable "name" {
  type        = string
  nullable    = false
  description = "Name of the runner, used for the VM and the runner registration."

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]+$", var.name))
    error_message = "Name must only contain alphanumeric characters, dots, dashes, or underscores."
  }
}

variable "machine_type" {
  type        = string
  nullable    = false
  description = "STACKIT machine flavor for the runner VM."
}

variable "image_name_regex" {
  type        = string
  nullable    = false
  description = "Anchored regex matching the STACKIT image name the runner boots from, so it skips the ARM64 variant."
}

variable "disk_size_gb" {
  type        = number
  nullable    = false
  description = "Size of the runner VM boot volume in GB."
}

variable "runner_version" {
  type        = string
  nullable    = false
  description = "Version of the STACKIT Git Actions runner agent installed on the VM."
}

variable "runner_labels" {
  type        = list(string)
  nullable    = false
  description = "Runner labels, each `<label>:host` or `<label>:docker://<image>`, targeted by workflows via runs-on."
}

variable "node_version" {
  type        = string
  nullable    = false
  description = "Node.js version installed on the VM, used by JavaScript actions such as actions/checkout."
}

variable "git_base_url" {
  type        = string
  description = "Base URL of the STACKIT Git instance, e.g. https://<name>.git.onstackit.cloud."
}

variable "git_organization" {
  type        = string
  description = "STACKIT Git organization the runner is registered for and serves."
}

variable "forgejo_api_token" {
  type        = string
  sensitive   = true
  description = "Org-admin PAT on `git_organization` that mints the registration token; it never reaches the VM."
}
