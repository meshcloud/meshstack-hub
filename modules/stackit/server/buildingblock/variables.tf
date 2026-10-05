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
  description = "Name of the VM, also used to name its network resources and SSH key pair."

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]+$", var.name))
    error_message = "Name must only contain alphanumeric characters, dots, dashes, or underscores."
  }
}

variable "machine_type" {
  type        = string
  nullable    = false
  description = "STACKIT machine flavor for the VM, e.g. g1a.1d or c1a.2d."
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

variable "cloud_init" {
  type        = string
  nullable    = false
  default     = ""
  description = "Optional cloud-init user data run on first boot. Empty boots the image unmodified. The SSH key is injected via the key pair, not this file, so a personal cloud-init needs no key handling."
}

variable "ssh_public_key" {
  type        = string
  nullable    = false
  default     = ""
  description = "OpenSSH public key authorized on the VM. Empty generates an ed25519 key pair and returns the private key as an output."
}

variable "enable_public_ip" {
  type        = bool
  nullable    = false
  description = "Attaches a public IP and opens inbound SSH, so the VM is reachable directly after creation. Disable to keep it private (reachable only from inside the network)."
}

variable "ssh_allowed_cidr" {
  type        = string
  nullable    = false
  description = "CIDR allowed to reach SSH (port 22) when a public IP is attached. Has no effect without a public IP."
}
