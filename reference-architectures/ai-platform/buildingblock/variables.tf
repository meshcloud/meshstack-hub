# ── The clusters ───────────────────────────────────────────────────────────────

variable "ai_cluster_kubeconfig" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "kubeconfig of the AI platform cluster, as YAML. The gateway and the shared ClickHouse are installed here, and every tenant's tracing instance lands here later. A service account token and a client certificate pair are both accepted."

  # Without this the run fails inside `yamldecode` in provider.tf, with a message that names neither
  # the input nor the reason. The message carries no interpolation, because the value is sensitive.
  validation {
    condition     = var.ai_cluster_kubeconfig != ""
    error_message = "The AI platform cluster kubeconfig is empty. Set it on the building block definition; it is the credential every chart in this architecture is installed with."
  }
}

variable "app_cluster_kubeconfig" {
  type        = string
  nullable    = false
  sensitive   = true
  default     = ""
  description = "kubeconfig of the cluster the application teams' namespaces live on, as YAML. Only the Secret carrying a tenant's model credential is written there, so the credential needs no more than `get`, `create`, `update`, `patch` and `delete` on secrets. Leave it empty to use `ai_cluster_kubeconfig`, which is correct when the applications run on the same cluster — at the cost of writing that Secret with a cluster-wide credential."
}

variable "app_platform_identifier" {
  type        = string
  nullable    = false
  description = "Full identifier of the meshStack platform the application cluster is registered as, in the `<platform>.<location>` form. Every tenant's model credential is delivered into the namespace of the sibling tenant of that platform in the same meshProject."
}

variable "apps_domain" {
  type        = string
  nullable    = false
  description = "Domain the cluster's application hostnames live under, for example `ai.likvid.stackit.run`. It is the `apps_domain` output of the Kubernetes architecture below this one: every name under it already resolves to the ingress load balancer and is already covered by the wildcard certificate, so this architecture creates no DNS record and requests no certificate."
}

variable "ingress_class_name" {
  type        = string
  nullable    = false
  default     = "haproxy"
  description = "Name of the IngressClass that serves the gateway and the tenants' tracing instances. The default matches the controller `modules/kubernetes/ingress` installs."
}

# ── The gateway ────────────────────────────────────────────────────────────────

variable "litellm_namespace" {
  type        = string
  nullable    = false
  default     = "litellm"
  description = "Namespace the gateway runs in. The module creates it."
}

variable "litellm_hostname_label" {
  type        = string
  nullable    = false
  default     = "litellm"
  description = "Label the gateway is published under inside `apps_domain`, so it answers on `<label>.<apps_domain>`. The wildcard certificate covers it, because the label adds exactly one level."

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.litellm_hostname_label))
    error_message = "litellm_hostname_label must be a single DNS label: lowercase letters, digits and hyphens, starting and ending with a letter or a digit."
  }
}

variable "litellm_replica_count" {
  type        = number
  nullable    = false
  default     = 1
  description = "Number of gateway pods. Anything above 1 needs a Redis-compatible instance for cross-pod rate limits and spend tracking, so set `litellm_redis_enabled` as well."
}

variable "litellm_redis_enabled" {
  type     = bool
  nullable = false
  default  = false
  # Off by default even though a Valkey is already in the picture for the tracing instances: LiteLLM
  # takes no database index, so it would share the keyspace the tenants' instances are separated in.
  description = "Point the gateway at the shared Valkey instance for cross-pod coordination. Turn it on together with a `litellm_replica_count` above 1, and know that the gateway takes no database index, so it shares the keyspace the tracing instances are separated in by index and prefix."
}

variable "litellm_database_name" {
  type        = string
  nullable    = false
  default     = "litellm"
  description = "Name of the gateway's own database on the shared PostgreSQL Flex instance, and of the user owning it. Virtual keys, teams, budgets and spend records live in it."

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_]*$", var.litellm_database_name))
    error_message = "litellm_database_name may contain lowercase letters, digits and underscores, and must not start with a digit."
  }
}

variable "litellm_model_backends" {
  type = map(object({
    model    = string
    api_base = string
  }))
  nullable    = false
  description = <<-EOT
  Models the gateway offers, keyed by the alias a caller puts in the `model` field of a request.
  `model` is the name at the upstream provider and `api_base` its OpenAI-compatible base URL,
  including the `/v1` suffix.

  This is where the shape of the backends stops being visible: an Azure OpenAI deployment, a STACKIT
  AI Model Serving deployment and a self-hosted vLLM are three entries of the same shape, and a
  tenant sees only the alias. Pass the credential of each alias in `litellm_model_backend_api_keys`
  under the same key.
  EOT
}

variable "litellm_model_backend_api_keys" {
  type        = map(string)
  nullable    = false
  sensitive   = true
  description = "API key per model alias, keyed exactly like `litellm_model_backends`. Several aliases that share one upstream endpoint repeat the same value. These are the platform team's credentials and no tenant ever sees one — that is the point of putting a gateway in front of them."
}

variable "litellm_console_sso_enabled" {
  type     = bool
  nullable = false
  default  = true
  # The five-seat limit is a property of the free open-source proxy and is accepted here. See the
  # free user limit section of modules/ai/litellm/buildingblock/README.md.
  description = "Let the platform team log in to the gateway's admin console through the identity provider. **The console holds at most five users**, because native SSO is free in the open-source proxy up to that number and the sixth login locks out everyone. Turn it off to leave the console without a login path."
}

# ── The shared ClickHouse cluster ──────────────────────────────────────────────

variable "clickhouse_namespace" {
  type        = string
  nullable    = false
  default     = "clickhouse"
  description = "Namespace the shared ClickHouse cluster runs in. Every tenant's tracing instance connects to the Service in it across namespaces, and every tenant's DDL Job runs in it."
}

variable "clickhouse_version" {
  type     = string
  nullable = false
  default  = "26.4"
  # It also becomes the tag of the client image each tenant's DDL Job runs, so the cluster and the
  # Jobs pull one image instead of two.
  description = "Tag of the clickhouse/clickhouse-server image. Langfuse v4 needs 25.12 or newer, so do not lower this below that floor."
}

variable "clickhouse_replicas" {
  type        = number
  nullable    = false
  default     = 1
  description = "Number of ClickHouse replicas. The default of 1 is sized for a demonstration cluster and gives no redundancy. Production wants 3."
}

variable "clickhouse_storage" {
  type        = string
  nullable    = false
  default     = "20Gi"
  description = "Size of the data volume of each ClickHouse replica. The default is sized for a demonstration cluster. Production wants 100Gi or more, because a later resize depends on CSI volume expansion."
}

variable "clickhouse_keeper_replicas" {
  type        = number
  nullable    = false
  default     = 1
  description = "Number of ClickHouse Keeper replicas. Keeper runs Raft, so the value must be odd. The default of 1 is a quorum of one: correct, but it stops the cluster whenever that pod restarts. Production wants 3."
}

# ── The shared Valkey instance ─────────────────────────────────────────────────
#
# Valkey is the one of the four shared tracing backends this architecture does not create. There is
# no Valkey module in the hub yet, so the platform team runs the instance and passes it in here.

variable "valkey_host" {
  type        = string
  nullable    = false
  description = "Hostname of the shared Valkey instance the tracing instances use as their queue backend, cache and rate limit store. Every tenant is separated inside it by a database index and a key prefix that `ai/model-access` derives."
}

variable "valkey_password" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "Password of the Valkey instance. Use only characters that are safe in a URL, because the Langfuse chart substitutes the value into the connection URL without encoding it."
}

variable "valkey_port" {
  type        = number
  nullable    = false
  default     = 6379
  description = "Port of the Valkey instance."
}

variable "valkey_database_count" {
  type        = number
  nullable    = false
  default     = 16
  description = "Number of Valkey database indices the instance serves. A stock Valkey serves 16, numbered 0 to 15. Each tenant's index is derived from a hash of the tenant modulo this number."
}

# ── STACKIT, where the shared and the per-tenant backends live ─────────────────

variable "stackit_project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project the shared PostgreSQL Flex instance and the tenants' buckets live in."
}

variable "stackit_service_account_key" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "Service account key of the STACKIT service account, as the JSON STACKIT returns when the key is created. It needs permission to create databases and users on the PostgreSQL Flex instance and to create Object Storage credentials groups in the project."
}

variable "stackit_postgres_instance_id" {
  type        = string
  nullable    = false
  description = "UUID of the shared PostgreSQL Flex instance. This architecture creates the gateway's own database inside it and never creates the instance, which is what keeps tenant churn from re-planning the shared server. Take it from the `instance_id` output of `modules/stackit/postgresflex`."
}

variable "stackit_s3_admin_access_key" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "Access key of the administrative Object Storage credential the tenants' buckets are created with. It has to belong to the credentials group named by `stackit_s3_admin_credentials_group_urn`."
}

variable "stackit_s3_admin_secret_access_key" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "Secret access key of the administrative Object Storage credential."
}

variable "stackit_s3_admin_credentials_group_urn" {
  type        = string
  nullable    = false
  description = "URN of the administrative Object Storage credentials group. Every tenant's bucket policy keeps access for this group, so the platform team can still reach a bucket."
}

# ── The identity provider ──────────────────────────────────────────────────────
#
# One provider for every service in the architecture, trusted natively, with no oauth2-proxy in
# front of anything. It is an input and never an assumption.

variable "oidc" {
  type = object({
    issuer_url    = string
    client_id     = string
    client_secret = string

    scopes                = optional(string, "openid email profile")
    display_name          = optional(string, "Single Sign-On")
    allow_account_linking = optional(bool, true)

    # Only the gateway's admin console reads these.
    proxy_admin_id        = optional(string)
    allowed_email_domains = optional(list(string))
    auto_redirect_to_sso  = optional(bool, false)
    logout_url            = optional(string)

    # Set all three when the identity provider is unreachable from the meshStack Terraform runner,
    # and the gateway module then makes no discovery request at all.
    authorization_endpoint = optional(string)
    token_endpoint         = optional(string)
    userinfo_endpoint      = optional(string)
  })

  nullable  = false
  sensitive = true

  description = <<-EOT
  The OIDC provider every service in this architecture trusts. `issuer_url` is the discovery base
  URL, for example `https://idp.example.com/realms/ai`; the services read
  `<issuer_url>/.well-known/openid-configuration`.

  It is required, because no service here creates a password user.

  The gateway's admin console reads `proxy_admin_id`, `allowed_email_domains`,
  `auto_redirect_to_sso` and `logout_url`; the tenants' tracing instances read `display_name`,
  `scopes` and `allow_account_linking`. Each tenant's tracing instance has a callback URL of its
  own, so the client needs each of them as an allowed redirect URI, or a wildcard where the provider
  supports one.
  EOT

  # The message carries no interpolation, because var.oidc is sensitive and Terraform refuses to
  # print a sensitive value in an error message.
  validation {
    condition     = startswith(var.oidc.issuer_url, "https://")
    error_message = "oidc.issuer_url must be an https URL. It is the discovery base URL, not the authorization endpoint."
  }
}

# ── What a tenant receives ─────────────────────────────────────────────────────

variable "model_access_secret_name" {
  type        = string
  nullable    = false
  default     = "ai-model-access"
  description = "Name of the Kubernetes Secret each tenant's model credential is delivered in, in the namespace of the application team. It carries `OPENAI_API_KEY` and `OPENAI_BASE_URL`, so a workload mounts it with `envFrom` and needs no code that knows about a gateway."
}

variable "langfuse_default_org_role" {
  type        = string
  nullable    = false
  default     = "MEMBER"
  description = "Role every user who logs in through the identity provider receives in a tenant's tracing organisation. Set `NONE` when one OIDC client is shared across tenants and auto-join is not wanted."
}

# ── meshStack registration ─────────────────────────────────────────────────────

variable "owning_workspace_identifier" {
  type        = string
  nullable    = false
  description = "Identifier of the meshStack workspace that owns the gateway platform, the AI landing zones and the model access building block definitions."
}

variable "location_identifier" {
  type        = string
  nullable    = false
  default     = "global"
  description = "Identifier of the meshStack location the gateway platform is registered in."
}

variable "platform_name" {
  type        = string
  nullable    = false
  default     = "ai"
  description = "Name of the meshStack platform the gateway is registered as. Together with the location it forms the platform identifier `<name>.<location>`, and it prefixes the name of every landing zone."

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.platform_name))
    error_message = "platform_name may contain lowercase letters, digits and hyphens, and must start and end with a letter or a digit."
  }
}

variable "platform_type_name" {
  type        = string
  nullable    = false
  default     = "AI-MODEL"
  description = "Name of the meshStack platform type the gateway platform belongs to. It is named for the capability rather than for LiteLLM, the product that delivers it. The type is created by `meshstack_integration.tf`, not by this run, because it is one catalog-wide object rather than something an order owns. meshStack restricts the name to uppercase letters, digits and dashes."
}

variable "landing_zones" {
  type = map(object({
    display_name    = string
    description     = string
    models          = optional(list(string), [])
    max_budget      = optional(number, 100)
    budget_duration = optional(string, "30d")
    tags            = optional(map(list(string)), {})
  }))
  nullable = false

  description = <<-EOT
  The AI landing zones, keyed by a short name that is appended to `platform_name`. Each one gets a
  model access building block definition of its own and lists it in
  `spec.mandatory_building_block_refs`, so meshStack provisions model access when a tenant of that
  landing zone is created and the application team fills in nothing.

  `models` is the allow-list the gateway enforces; an empty list sends no allow-list and lets the
  tenant call every model the gateway offers. `max_budget` and `budget_duration` are the spending
  limit of one tenant and the length of one budget period.

  Several landing zones is the normal case, not the exception: because the gateway hides the shape
  of the backends, `models` is what makes one landing zone resolve to a sovereign backend and
  another to a load-balanced pool across several.
  EOT

  validation {
    condition     = length(var.landing_zones) > 0
    error_message = "Define at least one landing zone. Without one there is no way to order model access."
  }

  validation {
    condition = alltrue([
      for name in keys(var.landing_zones) : can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", name))
    ])
    error_message = "Every landing zone key may contain lowercase letters, digits and hyphens, and must start and end with a letter or a digit, because it becomes part of the landing zone name."
  }
}

variable "building_block_tags" {
  type        = map(list(string))
  nullable    = false
  default     = {}
  description = "Tags applied to the model access building block definitions this architecture registers."
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const   = true
  default = { git_ref = "main", bbd_draft = true }

  description = <<-EOT
  `git_ref`: meshstack-hub reference used to source the gateway, the ClickHouse cluster, the Postgres database and the model access integration. `const` so it can be interpolated into the module source at init time.
  `bbd_draft`: Forwarded as-is to the model access integration, so the draft state of the building block definitions it registers tracks this building block's own release state.
  EOT
}
