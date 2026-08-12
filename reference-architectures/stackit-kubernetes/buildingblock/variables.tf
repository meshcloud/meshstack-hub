variable "stackit_project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project UUID of the meshTenant the cluster is created in. meshStack fills this from the STACKIT Project platform tenant."
}

variable "stackit_region" {
  type        = string
  nullable    = false
  default     = "eu01"
  description = "STACKIT region the cluster is created in."
}

variable "stackit_service_account_email" {
  type        = string
  nullable    = true
  default     = null
  description = "Email of the STACKIT service account the SKE module authenticates as through workload identity federation. The account needs `ske.admin` on the organization, because the target project of an order is unknown when the platform team registers the building block."
}

variable "cluster_name" {
  type        = string
  nullable    = false
  description = "Name of the SKE cluster. It is also the meshStack platform name and the label of the delegated DNS subzone, so it has to be unique across the landing zone. STACKIT limits SKE cluster names to 11 characters."

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.cluster_name)) && length(var.cluster_name) <= 11
    error_message = "cluster_name may contain up to 11 lowercase letters, digits and hyphens, and must start and end with a letter or a digit."
  }
}

variable "expose" {
  type        = string
  nullable    = false
  default     = "public"
  description = "How the cluster's ingress is reachable. `public` puts the HAProxy ingress controller behind a public load balancer, `internal` keeps the load balancer inside the STACKIT network, and `none` installs no ingress controller at all."

  validation {
    condition     = contains(["public", "internal", "none"], var.expose)
    error_message = "expose must be one of public, internal or none."
  }
}

variable "owning_workspace_identifier" {
  type        = string
  nullable    = false
  description = "Identifier of the meshStack workspace that owns the Kubernetes platform and its namespace landing zones."
}

variable "location_identifier" {
  type        = string
  nullable    = false
  default     = "global"
  description = "Identifier of the meshStack location the Kubernetes platform is registered in."
}

variable "acme_email" {
  type        = string
  nullable    = false
  default     = ""
  description = "Contact address Let's Encrypt uses for expiry warnings and account recovery. Leave empty to register the ACME account without a contact address."
}

variable "acme_server" {
  type        = string
  nullable    = false
  default     = "https://acme-v02.api.letsencrypt.org/directory"
  description = "ACME directory URL. Point this at the Let's Encrypt staging endpoint while you test, because the production endpoint has strict rate limits."
}

variable "cluster_issuer_name" {
  type        = string
  nullable    = false
  default     = "letsencrypt-prod"
  description = "Name of the ClusterIssuer application teams reference from the `cert-manager.io/cluster-issuer` annotation on their Ingress."
}

variable "ingress_class_name" {
  type        = string
  nullable    = false
  default     = "haproxy"
  description = "Name of the IngressClass the controller serves."
}

variable "dns_parent_zone_name" {
  type        = string
  nullable    = false
  default     = ""
  description = "Parent DNS zone the landing zone owns, for example `likvid.stackit.run`. Every cluster gets a delegated subzone `<cluster_name>.<dns_parent_zone_name>` under it. Leave empty to run without DNS, in which case cert-manager issues per-hostname certificates over HTTP-01. See dns.tf."
}

variable "dns_service_account_key" {
  type        = string
  nullable    = false
  default     = ""
  sensitive   = true
  description = "STACKIT service account key JSON, scoped to the tenant's own STACKIT project, that the cert-manager DNS-01 solver authenticates with. Required for the wildcard certificate. See dns.tf."
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const   = true
  default = { git_ref = "main", bbd_draft = true }

  description = <<-EOT
  `git_ref`: meshstack-hub reference used to source the SKE, Kubernetes platform and ingress modules. `const` so it can be interpolated into the module source at init time.
  `bbd_draft`: Carried for symmetry with the other hub integrations. This building block registers no building block definition of its own.
  EOT
}
