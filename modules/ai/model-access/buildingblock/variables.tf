# --- meshStack tenant context -------------------------------------------------------------------
#
# Every variable in this section is filled by meshStack from the tenant the run belongs to, through
# an assignment type. None of them is a USER_INPUT, and none of them may become one: together with
# the STATIC values below they decide which namespace in which cluster receives the model
# credential. See the residual risk section of the module README.

variable "workspace_identifier" {
  type        = string
  description = "Identifier of the meshStack workspace the tenant belongs to. It becomes part of the LiteLLM team alias, part of every per-tenant name this module derives, and the identifier of the Langfuse organisation."
}

variable "project_identifier" {
  type        = string
  description = "Identifier of the meshStack project the tenant belongs to. It becomes part of the LiteLLM team alias, part of every per-tenant name this module derives, and the identifier of the Langfuse project."
}

variable "meshstack_tenant_uuid" {
  type        = string
  default     = ""
  description = "UUID of the meshStack tenant. It is written to the LiteLLM team metadata so an operator can trace a team back to its tenant."
}

# --- The shared LiteLLM gateway -----------------------------------------------------------------

variable "litellm_api_base" {
  type        = string
  description = "Base URL of the LiteLLM gateway, for example 'https://litellm.example.com'. The provider talks to the admin API under this URL."
}

variable "litellm_api_key" {
  type        = string
  sensitive   = true
  description = "LiteLLM admin key the provider authenticates with. It needs permission to create teams and keys."
}

variable "models" {
  type        = list(string)
  default     = []
  description = "Names of the models on the LiteLLM gateway that the team may call. An empty list sends no allow-list to LiteLLM."
}

variable "max_budget" {
  type        = number
  default     = 100
  description = "Spending limit of the team for one budget period, in the currency the gateway reports spend in. LiteLLM blocks the team once the limit is reached."
}

variable "budget_duration" {
  type        = string
  default     = "30d"
  description = "Length of one budget period, after which LiteLLM resets the spend counter. Written as a LiteLLM duration such as '30d', '7d' or '1h'."
}

# --- The two clusters ---------------------------------------------------------------------------

variable "ai_platform_cluster_kubeconfig" {
  type        = string
  sensitive   = true
  description = "kubeconfig of the AI platform cluster, as YAML. The tenant's Langfuse instance is deployed here. The credential needs permission to create a namespace, a secret and a Helm release."
}

variable "demo_app_cluster_kubeconfig" {
  type        = string
  sensitive   = true
  description = "kubeconfig of the demo application cluster, as YAML. Only the Secret with the model credential is written here, so the credential needs no more than `get`, `create`, `update` and `patch` on secrets."
}

variable "demo_app_platform_identifier" {
  type        = string
  description = "Full identifier of the meshStack platform the demo application cluster is registered as, in the form '<platform>.<location>'. The module looks up the sibling tenant of this platform in the same meshProject to learn the namespace it writes the Secret into. This is the platform identifier, never the platform type: two clusters of the same type would both match a type filter."

  validation {
    condition     = length(split(".", var.demo_app_platform_identifier)) >= 2
    error_message = "demo_app_platform_identifier must be the full platform identifier '<platform>.<location>', for example 'kubernetes.eu01'."
  }
}

variable "secret_name" {
  type        = string
  default     = "ai-model-access"
  description = "Name of the Kubernetes Secret this module writes into the namespace of the application team. The workload reads the model credential and the endpoint from it."
}

# --- The tenant's Langfuse instance -------------------------------------------------------------

variable "langfuse_domain" {
  type        = string
  description = "Domain the tenant's Langfuse instance is published under. The module prepends the derived per-tenant label, so the instance answers on '<derived label>.<langfuse_domain>'. Give a bare domain without a scheme and without a leading dot."

  validation {
    condition     = !strcontains(var.langfuse_domain, "://") && !startswith(var.langfuse_domain, ".")
    error_message = "langfuse_domain must be a bare domain without a scheme and without a leading dot, for example 'ai.example.com'."
  }
}

variable "langfuse_ingress_class_name" {
  type        = string
  default     = "haproxy"
  description = "Name of the IngressClass that serves the tenants' Langfuse instances in the AI platform cluster. The default matches the controller `modules/kubernetes/ingress` installs. The Ingress carries no tls block, because that controller serves a wildcard certificate as its default."
}

variable "langfuse_default_org_role" {
  type    = string
  default = "MEMBER"
  # Langfuse upserts an organisation membership with this role for every user who logs in, which is
  # what removes member synchronisation from the picture. It also means that with one OIDC client
  # shared across tenants, every user the identity provider authenticates reaches every tenant's
  # instance with this role. See the access control section of the module README.
  description = "Role every user who logs in through the identity provider receives in the tenant's Langfuse organisation. Set 'NONE' to hand out a membership that grants nothing, which is how to turn auto-join off when one OIDC client is shared across tenants."

  validation {
    condition     = contains(["OWNER", "ADMIN", "MEMBER", "VIEWER", "NONE"], var.langfuse_default_org_role)
    error_message = "langfuse_default_org_role must be one of OWNER, ADMIN, MEMBER, VIEWER or NONE."
  }
}

variable "oidc" {
  description = <<-EOT
  OIDC identity provider the tenant's Langfuse instance trusts. It is required: this building block
  creates no password user, because a password nobody can read is of no use, and a building block
  output cannot carry one.

  Register the callback URL `https://<derived label>.<langfuse_domain>/api/auth/callback/custom` at
  the provider. The `langfuse_oidc_callback_url` output reports the exact URL of this tenant.
  EOT

  type = object({
    issuer_url            = string
    client_id             = string
    client_secret         = string
    display_name          = optional(string, "Single Sign-On")
    scopes                = optional(string, "openid email profile")
    allow_account_linking = optional(bool, true)
  })

  sensitive = true
}

# --- The backends the Langfuse instances share --------------------------------------------------
#
# Each of the four backends is shared across tenants and separated by name: a database, a bucket, a
# key prefix. This module derives those names from the tenant context; the endpoints and the
# credentials arrive as STATIC inputs.

variable "langfuse_postgres_host" {
  type        = string
  description = "Hostname of the shared Postgres server. Langfuse keeps its relational data there, in a database of its own per tenant."
}

variable "langfuse_postgres_username" {
  type        = string
  description = "Postgres user Langfuse connects as. It has to own the tenant's database, because `prisma migrate deploy` creates and alters tables under it on every web pod start."
}

variable "langfuse_postgres_password" {
  type        = string
  sensitive   = true
  description = "Password of the Postgres user. Use only characters that are safe in a URL: Langfuse builds its connection URL by string substitution and does not percent-encode the value."
}

variable "langfuse_clickhouse_host" {
  type        = string
  description = "Fully qualified hostname of the shared ClickHouse cluster, without a scheme. Take it from the `host` output of modules/ai/clickhouse."
}

variable "langfuse_clickhouse_username" {
  type        = string
  description = "ClickHouse user Langfuse connects as. It needs the table rights Langfuse's migrations use on the tenant's database, and nothing beyond it."
}

variable "langfuse_clickhouse_password" {
  type        = string
  sensitive   = true
  description = "Password of the ClickHouse user. Avoid '&', '=', '#', '?', '%', '+', '@' and spaces: the Langfuse migration script puts the value into a query string without encoding it."
}

variable "langfuse_valkey_host" {
  type        = string
  description = "Hostname of the shared Valkey instance. Langfuse uses it as the queue backend, the cache and the rate limit store."
}

variable "langfuse_valkey_password" {
  type        = string
  sensitive   = true
  description = "Password of the Valkey instance. Use only characters that are safe in a URL, because the chart substitutes the value into the connection URL without encoding it."
}

variable "langfuse_valkey_database_count" {
  type    = number
  default = 16
  # The index is derived from a hash of the tenant, so it repeats once there are more tenants than
  # indices. The key prefix is what keeps two tenants apart in that case, see naming.tf.
  description = "Number of Valkey database indices the instance serves. The module derives the tenant's index from a hash of the tenant, modulo this number. A stock Valkey serves 16 indices, numbered 0 to 15."

  validation {
    condition     = var.langfuse_valkey_database_count >= 1
    error_message = "langfuse_valkey_database_count must be at least 1."
  }
}

variable "langfuse_s3_endpoint" {
  type        = string
  description = "Endpoint URL of the object storage the tenant's bucket lives in, including the scheme."
}

variable "langfuse_s3_access_key_id" {
  type        = string
  sensitive   = true
  description = "Access key id of the object storage credential."
}

variable "langfuse_s3_secret_access_key" {
  type        = string
  sensitive   = true
  description = "Secret access key of the object storage credential."
}

# --- Hub reference ------------------------------------------------------------------------------

variable "hub" {
  type = object({
    git_ref = optional(string, "main")
  })
  const   = true
  default = { git_ref = "main" }

  description = <<-EOT
  `git_ref`: meshstack-hub reference this module sources `modules/ai/langfuse/buildingblock` from.
  `const` so it can be interpolated into the module source at init time. The building block
  definition passes the same reference it checks this module out at, so the tenant's Langfuse comes
  from the release this building block was published from.
  EOT
}
