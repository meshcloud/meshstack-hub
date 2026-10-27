variable "project_id" {
  type        = string
  nullable    = false
  description = "ID of the T Cloud Public project the cluster is created in."
}

variable "region" {
  type        = string
  default     = "eu-de"
  nullable    = false
  description = "T Cloud Public region of the project."
}

variable "name" {
  type        = string
  nullable    = false
  description = "Name of the CCE cluster. Also prefixes its node pools and key pair."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,50}[a-z0-9]$", var.name))
    error_message = "name must be 4-52 characters of lowercase letters, digits and dashes, start with a letter and not end with a dash."
  }
}

variable "cluster_version" {
  type        = string
  default     = "v1.31"
  nullable    = false
  description = "Kubernetes version of the cluster, as CCE names it, e.g. `v1.31`. Must be one CCE still offers."
}

variable "vpc_id" {
  type        = string
  nullable    = false
  description = "ID of the VPC, from the parent T Cloud Public Network building block."
}

variable "subnet_id" {
  type        = string
  nullable    = false
  description = "ID of the subnet, from the parent T Cloud Public Network building block."
}

variable "availability_zones" {
  type        = list(string)
  default     = ["eu-de-01"]
  nullable    = false
  description = "Availability zones of the worker nodes. Each zone gets its own node pool of `node_count` nodes."

  validation {
    condition     = length(var.availability_zones) > 0
    error_message = "Choose at least one availability zone."
  }
}

variable "node_count" {
  type        = number
  default     = 2
  nullable    = false
  description = "Number of worker nodes per availability zone."

  validation {
    condition     = var.node_count >= 1 && var.node_count <= 20
    error_message = "node_count must be between 1 and 20."
  }
}

variable "node_flavor" {
  type        = string
  default     = "s3.xlarge.4"
  nullable    = false
  description = "ECS flavor of the worker nodes, e.g. `s3.xlarge.4` (4 vCPUs, 16 GiB)."
}

variable "public_api" {
  type        = bool
  default     = true
  nullable    = false
  description = "Bind an elastic IP to the Kubernetes API, so it is reachable from the internet. Without it the API is reachable only from inside the VPC."
}
