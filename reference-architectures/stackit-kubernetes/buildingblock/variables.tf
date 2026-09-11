# ── meshStack context ──

variable "workspace" {
  type        = string
  nullable    = false
  description = "Identifier of the meshStack workspace that owns the platform, location, landing zones, hosting project and the building block definitions this architecture registers."
}

variable "use_global_location" {
  type        = bool
  nullable    = false
  default     = false
  description = "Use the global meshStack location instead of creating a dedicated one for this platform."
}

variable "payment_method_identifier" {
  type        = string
  nullable    = false
  description = "Payment method identifier assigned to the hosting project and the starterkit's dev/prod projects."
}

variable "tags" {
  type = object({
    landingzone           = map(list(string))
    building_block        = map(list(string))
    project               = map(list(string))
    project_owner_tag_key = string
  })
  nullable    = false
  description = <<-EOT
  Tags forwarded to the nested integrations.
  `landingzone` tags are applied to the created SKE landing zones.
  `building_block` tags are applied to the nested building block definitions.
  `project` tags are applied to the meshProjects the starterkit creates.
  `project_owner_tag_key` names the tag that receives the creator's display name.
  EOT
}

variable "playground_mode" {
  type        = bool
  nullable    = false
  description = "Deploy a throwaway platform: the platform identifier gets a random suffix so it does not occupy a name for good, and the hosting project and tenant are left destroyable. Set to false for a platform that is actually used."
}

# ── STACKIT authentication and self-hosting ──

variable "stackit_backplane_project_id" {
  type        = string
  nullable    = false
  description = "Existing STACKIT project the automation service accounts (this architecture's and the SKE cluster's) are created in — e.g. a foundation project. Not the hosting project, which is provisioned at order time."
}

variable "stackit_organization_id" {
  type        = string
  nullable    = false
  description = "STACKIT organization the automation service accounts are granted roles on, so the grants are inherited by the hosting project created at order time."
}

variable "host_platform_identifier" {
  type        = string
  nullable    = false
  description = "Full `<platform>.<location>` identifier of the existing STACKIT Project platform (e.g. from the STACKIT Landing Zone) on which the cluster's hosting project is provisioned as a meshStack tenant."
}

variable "host_landing_zone_name" {
  type        = string
  nullable    = false
  description = "Name of the landing zone on the host STACKIT platform that the hosting tenant is placed in."
}

variable "stackit_region" {
  type        = string
  nullable    = false
  default     = "eu01"
  description = "STACKIT region for the git instance, DNS zone and model serving token."
}

# ── SKE cluster ──

variable "cluster_name" {
  type        = string
  nullable    = false
  default     = "starterkit"
  description = "Name of the SKE cluster (2-11 chars, lowercase alphanumeric or dashes, no leading/trailing dash)."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,9}[a-z0-9]$", var.cluster_name))
    error_message = "cluster_name must be 2-11 characters, lowercase alphanumeric or dashes, and not start or end with a dash."
  }
}

variable "cluster_issuer_email" {
  type        = string
  nullable    = false
  default     = "ske@meshcloud.io"
  description = "Contact email registered with Let's Encrypt for the ACME ClusterIssuer installed on the cluster."
}

# ── Git / Forgejo ──

variable "git_instance_name" {
  type        = string
  nullable    = false
  description = "Name of the STACKIT Git (Forgejo) instance. Globally unique across STACKIT; forms the instance URL `https://<name>.git.onstackit.cloud`."
}

variable "forgejo_organization" {
  type        = string
  nullable    = false
  description = "Forgejo organization created on the git instance and used for the application repositories."
}

variable "forgejo_token" {
  type        = string
  sensitive   = true
  default     = null
  description = "Personal access token of a Forgejo bot account on the STACKIT Git instance, used to manage the organization and repositories. Optional on the first run: the git instance is created without it, then you create the token manually on that instance, enter it, and run again to provision the organization and the starterkit definitions. Null until provided."
}

# ── Harbor container registry ──
# STACKIT's Harbor registry is a single global instance shared across all STACKIT customers. We only
# hold robot-account credentials for it, not admin rights, so the registry, its project and robot
# accounts cannot be provisioned from Terraform — they are supplied here as inputs. See the ske/
# platform README on mirroring base images.

# All Harbor inputs are only consumed by the starterkit, which is gated on them together with the
# Forgejo token (see local.starterkit_enabled), so they are optional on the first (bootstrap) run and
# supplied on the run that enables the starterkit. The robot secrets are shown only once at creation
# time in the Harbor UI, which is why they are inputs rather than provisioned.

variable "stackit_harbor_project" {
  type        = string
  default     = null
  description = "Harbor project name in the global STACKIT registry that application images are pushed to and pulled from. Required only for the starterkit."
}

variable "stackit_harbor_push_robot_user" {
  type        = string
  sensitive   = true
  default     = null
  description = "Harbor robot account username with push access (used by CI to publish images). Required only for the starterkit."
}

variable "stackit_harbor_push_robot_password" {
  type        = string
  sensitive   = true
  default     = null
  description = "Harbor robot account secret with push access. Required only for the starterkit."
}

variable "stackit_harbor_pull_robot_user" {
  type        = string
  sensitive   = true
  default     = null
  description = "Harbor robot account username with pull access (used by the cluster to pull images). Required only for the starterkit."
}

variable "stackit_harbor_pull_robot_password" {
  type        = string
  sensitive   = true
  default     = null
  description = "Harbor robot account secret with pull access. Required only for the starterkit."
}

# ── DNS ──

variable "dns_name" {
  type        = string
  nullable    = false
  description = "Subdomain label under `stackit.run` for application ingress. Creates the DNS zone `<dns_name>.stackit.run` and a wildcard A record pointing at the ingress load balancer."
}

variable "dns_contact_email" {
  type        = string
  nullable    = false
  default     = "support@meshcloud.io"
  description = "Contact email registered on the STACKIT DNS zone."
}

# ── Starterkit ──

variable "template_name" {
  type        = string
  nullable    = false
  default     = "ai-summarizer"
  description = "Name of the sample application; used to name the model serving token and passed to CI as APP_NAME."
}

variable "template_repo_clone_url" {
  type        = string
  nullable    = false
  default     = "https://github.com/likvid-bank/starterkit-template-stackit-ai-summarizer.git"
  description = "Template repository the starterkit clones new application repositories from."
}

variable "ai_model" {
  type        = string
  nullable    = false
  default     = "openai/gpt-oss-120b"
  description = "STACKIT Model Serving model id provisioned into the starterkit's dev/prod namespaces."
}

variable "add_random_name_suffix" {
  type        = bool
  nullable    = false
  default     = false
  description = "Whether the starterkit appends a random suffix to the names it creates."
}

variable "project_tags" {
  type = object({
    dev           = map(list(string))
    prod          = map(list(string))
    owner_tag_key = optional(string, null)
  })
  nullable    = false
  description = "Tags applied to the dev and prod meshProjects the starterkit creates. `owner_tag_key` names the tag that receives the creator's display name."
}

# ── Hub ──

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const   = true
  default = { git_ref = "main", bbd_draft = true }

  description = <<-EOT
  `git_ref`: meshstack-hub reference used to source the nested cluster, platform-services, git-repository, forgejo-connector and starterkit modules. `const` so it can be interpolated into the module source at init time.
  `bbd_draft`: Forwarded to those nested integrations' `hub.bbd_draft`, so their building block definition draft state tracks this architecture's own release state.
  EOT
}
