variable "stackit_project_id" {
  type        = string
  description = "STACKIT project ID the VM is created in."
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
  description = "Existing STACKIT network to attach the VM to. Empty creates a dedicated one."
}

variable "name" {
  type        = string
  nullable    = false
  description = "Name of the VM, reused for its network, security group, key pair and network interface."

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]+$", var.name))
    error_message = "Name must only contain alphanumeric characters, dots, dashes, or underscores."
  }
}

variable "machine_type" {
  type        = string
  nullable    = false
  description = "STACKIT machine flavor for the VM."
}

variable "image_name_regex" {
  type        = string
  nullable    = false
  description = "Anchored regex matching the STACKIT image name the VM boots from, so it skips the ARM64 variant."
}

variable "disk_size_gb" {
  type        = number
  nullable    = false
  description = "Size of the VM boot volume in GB."
}

variable "ssh_username" {
  type        = string
  nullable    = false
  description = "Login user the chosen image ships with (e.g. `ubuntu`), reported in the SSH command output."
}

variable "ssh_allowed_cidr" {
  type        = string
  nullable    = false
  description = "CIDR allowed to reach the VM on TCP 22. Narrow it to an office range; 0.0.0.0/0 exposes SSH to the internet."
}

variable "cloud_init" {
  type        = string
  nullable    = false
  default     = ""
  description = "Optional personal cloud-init (`#cloud-config` or a shell script) applied on first boot. Empty boots the image unmodified."
}
