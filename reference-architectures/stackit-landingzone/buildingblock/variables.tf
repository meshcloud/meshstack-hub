variable "workspace" {
  type        = string
  nullable    = false
  description = "Identifier of the meshStack workspace that will own the created platform, location, landing zones, and (when networking is enabled) the hub network-area instance."
}

variable "use_global_location" {
  type        = bool
  nullable    = false
  description = "Use the global location instead of creating a dedicated location for this platform."
}

variable "stackit_org" {
  type        = string
  nullable    = false
  description = "STACKIT organization UUID under which the landing-zone folder, foundation project and tenant projects are created."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.stackit_org))
    error_message = "stackit_org must be a valid UUID."
  }
}

variable "stackit_owner_email" {
  type        = string
  nullable    = false
  description = "Owner email assigned to the STACKIT resourcemanager folder and foundation project."
}

variable "stackit_service_account_key" {
  type        = string
  sensitive   = true
  nullable    = false
  description = "STACKIT service account key JSON with `resource-manager.admin` on the organization. Used to create the landing-zone folder and foundation project."
}

variable "platform_identifier" {
  type        = string
  nullable    = false
  description = "Identifier for the STACKIT sandbox platform created in meshStack (letters, digits and dashes only)."

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.platform_identifier))
    error_message = "platform_identifier must only contain letters, digits, and dashes."
  }
}

variable "tags" {
  type = object({
    landingzone    = map(list(string))
    building_block = map(list(string))
  })
  nullable    = false
  description = "Tags forwarded to the nested STACKIT integrations. `landingzone` tags are applied to the created landing zones; `building_block` tags are applied to the nested building block definitions."
}

variable "role_mapping" {
  type        = map(list(string))
  nullable    = false
  description = "Default mapping from meshStack roles to STACKIT project roles for the nested STACKIT Project integration. Values can be built-in STACKIT roles or custom STACKIT role names."
}

variable "stackit_organization_onboarding_enabled" {
  type        = bool
  nullable    = false
  description = "Whether the nested STACKIT Project integration adds meshStack project users to the STACKIT organization before applying project-level role assignments. Disable if organization membership is managed outside this landing zone."
}

variable "network" {
  type = object({
    hub_network_area_name            = optional(string, "hub")
    hub_network_ranges               = optional(list(string), ["10.0.0.0/16"])
    hub_transfer_network             = optional(string, "10.1.255.0/24")
    hub_min_prefix_length            = optional(number, 24)
    hub_max_prefix_length            = optional(number, 28)
    hub_default_prefix_length        = optional(number, 28)
    hub_default_nameservers          = optional(list(string), [])
    tenant_network_min_prefix_length = optional(number, 24)
    tenant_network_max_prefix_length = optional(number, 28)
  })
  default     = null
  description = "Optional hub-and-spoke network topology. Leave unset (null) to deploy only the sandbox landing zone. When set, additionally provisions a shared hub network area with the given address plan (`hub_*` fields), registers the self-service spoke `STACKIT Network` building block (`tenant_network_*` prefix bounds), and adds a dedicated `networked` STACKIT Project building block definition and landing zone whose projects are placed in the hub network area."
}

variable "kubernetes" {
  type = object({
    dns_zone_name             = string
    dns_zone_default_ttl      = optional(number, 300)
    dns_cluster_label_enabled = optional(bool, true)

    stackit_region               = optional(string, "eu01")
    stackit_service_account_name = optional(string, "mesh-ske")

    acme_server         = optional(string, "https://acme-v02.api.letsencrypt.org/directory")
    cluster_issuer_name = optional(string, "letsencrypt-prod")
    ingress_class_name  = optional(string, "haproxy")
  })
  default = null

  description = <<-EOT
  Optional Kubernetes platform. Leave unset (null) to deploy only the sandbox landing zone. When
  set, this building block creates the shared DNS zone `dns_zone_name` in the foundation project
  together with the credential that writes into it, and registers the `stackit-kubernetes`
  reference architecture as a `TENANT_LEVEL` building block definition. An application team then
  orders a cluster into its own STACKIT project and receives a Kubernetes platform whose landing
  zones hand out namespaces with a working HTTPS hostname.

  The zone is created **once, here**. An ordered cluster never creates a zone; it writes the record
  set `*.<cluster name>` into this one, which is what `dns_cluster_label_enabled` turns on. A free
  STACKIT subdomain admits exactly one label, so a zone per cluster is impossible — see dns.tf.
  EOT

  validation {
    condition     = var.kubernetes == null ? true : can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", var.kubernetes.dns_zone_name))
    error_message = "kubernetes.dns_zone_name must be a lowercase domain name with at least two labels and no trailing dot, for example likvid.stackit.run."
  }

  validation {
    condition = var.kubernetes == null ? true : (
      !endswith(var.kubernetes.dns_zone_name, ".stackit.run") || length(split(".", var.kubernetes.dns_zone_name)) == 3
    )
    error_message = "A zone under stackit.run may carry exactly one label, for example likvid.stackit.run. STACKIT rejects a deeper name with \"subdomain '<name>' should only have one level\", so every cluster below it is a record set and not a zone of its own."
  }
}

variable "ai" {
  type = object({
    # ── The cluster this platform is installed into ──
    # Ordered through the `kubernetes` option above. Its name is all that is needed to address it:
    # the application domain and the meshStack platform identifier are both derived from it.
    #
    # `cluster_kubeconfig` is that cluster's `kubeconfig` output verbatim. SKE returns a
    # client-certificate kubeconfig rather than a service account token, which is what the charts
    # below accept as their cluster credential.
    cluster_name       = string
    cluster_kubeconfig = string

    # ── The models the gateway offers ──
    model_backends         = map(object({ model = string, api_base = string }))
    model_backend_api_keys = map(string)

    # ── Shared backends the platform team runs and this landing zone does not create ──
    stackit_project_id             = optional(string, "")
    postgres_instance_id           = string
    valkey_host                    = string
    valkey_password                = string
    valkey_database_count          = optional(number, 16)
    s3_admin_access_key            = string
    s3_admin_secret_access_key     = string
    s3_admin_credentials_group_urn = string

    # ── The identity provider ──
    # Passed through to `ai-platform` unchanged. No identity provider is named here, because none is
    # named anywhere in this repository — see ai.tf.
    oidc_issuer_url             = string
    oidc_client_id              = string
    oidc_client_secret          = string
    oidc_scopes                 = optional(string, "openid email profile")
    oidc_display_name           = optional(string, "Single Sign-On")
    oidc_allow_account_linking  = optional(bool, true)
    oidc_proxy_admin_id         = optional(string)
    oidc_allowed_email_domains  = optional(list(string))
    oidc_auto_redirect_to_sso   = optional(bool, false)
    oidc_logout_url             = optional(string)
    oidc_authorization_endpoint = optional(string)
    oidc_token_endpoint         = optional(string)
    oidc_userinfo_endpoint      = optional(string)

    # ── The gateway and the shared trace storage ──
    litellm_hostname_label      = optional(string, "litellm")
    litellm_console_sso_enabled = optional(bool, true)
    litellm_replica_count       = optional(number, 1)
    litellm_redis_enabled       = optional(bool, false)
    clickhouse_replicas         = optional(number, 1)
    clickhouse_storage          = optional(string, "20Gi")
    clickhouse_keeper_replicas  = optional(number, 1)

    # ── What a tenant receives ──
    model_access_secret_name  = optional(string, "ai-model-access")
    langfuse_default_org_role = optional(string, "MEMBER")

    # ── meshStack registration ──
    platform_name              = optional(string, "ai")
    platform_type_name         = optional(string, "AI-MODEL")
    platform_type_display_name = optional(string, "AI Model Gateway")

    landing_zones = optional(map(object({
      display_name    = string
      description     = string
      models          = optional(list(string), [])
      max_budget      = optional(number, 100)
      budget_duration = optional(string, "30d")
      tags            = optional(map(list(string)), {})
      })), {
      standard = {
        display_name    = "AI Model Access"
        description     = "Governed access to every model the gateway offers, with a budget of 100 per 30 days per project."
        models          = []
        max_budget      = 100
        budget_duration = "30d"
        tags            = {}
      }
    })
  })
  default   = null
  sensitive = true

  description = <<-EOT
  Optional AI platform, layered on top of the `kubernetes` option. Leave unset (null) to deploy
  without one. When set, this building block registers the `ai-platform` reference architecture —
  the LiteLLM gateway, the shared ClickHouse, the `AI-MODEL` platform type and one AI landing zone
  per entry — and orders it once in this workspace.

  It requires `kubernetes`, because `cluster_name` names a cluster ordered through that option and
  the application domain is derived from the shared DNS zone this building block created there.

  The object carries six credentials — the cluster kubeconfig, the upstream model keys, the Valkey
  password, both object storage keys and the OIDC client secret — so the whole value is a sensitive
  input and never appears in a plan or a summary.
  EOT

  validation {
    condition     = var.ai == null ? true : can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.ai.cluster_name))
    error_message = "ai.cluster_name must be the name of a cluster ordered through the kubernetes option: lowercase letters, digits and hyphens, starting and ending with a letter or a digit."
  }

  validation {
    condition     = var.ai == null ? true : startswith(var.ai.oidc_issuer_url, "https://")
    error_message = "ai.oidc_issuer_url must be an https URL. It is the discovery base URL of the identity provider, not its authorization endpoint."
  }

  validation {
    condition     = var.ai == null ? true : length(var.ai.landing_zones) > 0
    error_message = "Define at least one AI landing zone. Without one there is no way to order model access."
  }

  # The AI platform installs into a cluster the kubernetes option delivers and publishes itself in the
  # DNS zone that option creates, so the layering is enforced rather than documented.
  validation {
    condition     = var.ai == null || var.kubernetes != null
    error_message = "The ai option sits on top of the kubernetes one: it installs into a cluster ordered through it and derives the application domain from the DNS zone it creates. Set kubernetes as well, or leave ai unset."
  }
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const   = true
  default = { git_ref = "main", bbd_draft = true }

  description = <<-EOT
  `git_ref`: meshstack-hub reference used to source the nested foundation, network-area, and network integration modules. `const` so it can be interpolated into the module source at init time.
  `bbd_draft`: Forwarded as-is to those nested integrations' own `hub.bbd_draft`, so their building block definition draft state tracks this building block's own release state.
  EOT
}
