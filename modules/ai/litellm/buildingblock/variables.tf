variable "cluster_endpoint" {
  type        = string
  description = "IP address or hostname of the cluster control plane, without the https:// scheme."
}

variable "cluster_ca_certificate" {
  type        = string
  description = "Cluster CA certificate, base64 encoded."
}

variable "token" {
  type        = string
  sensitive   = true
  description = "Token of the service account this module runs as. It needs permission to create a namespace, secrets and the workloads of the Helm release."
}

variable "namespace" {
  type        = string
  default     = "litellm"
  description = "Namespace the gateway runs in. The module creates it."
}

variable "release_name" {
  type    = string
  default = "litellm"
  # The chart derives the Service name from the release name: '<release>-litellm', or just
  # '<release>' when the release name already contains 'litellm'.
  description = "Helm release name of the gateway."
}

variable "chart_version" {
  type    = string
  default = "1.96.2"
  # The chart is published to GHCR as an OCI artifact only, so the tag on the registry is the
  # single source of truth. Chart.yaml on the repository's main branch reads a different, much
  # lower version, because the release pipeline overwrites it while publishing.
  description = "Version of the litellm-helm chart. See https://github.com/BerriAI/litellm/pkgs/container/litellm-helm."
}

variable "replica_count" {
  type    = number
  default = 1
  # Anything above 1 needs Redis, otherwise each pod counts rate limits and spend on its own.
  description = "Number of gateway pods. Set redis_host as well when this is greater than 1."
}

variable "helm_timeout" {
  type        = number
  default     = 600
  description = "Seconds to wait for the Helm release to become ready. The Prisma migration Job runs first and takes part of this budget."
}

variable "master_key" {
  type      = string
  sensitive = true
  # The proxy reads it as PROXY_MASTER_KEY and treats it as the root credential of the gateway:
  # it authenticates every call to the /key and /team endpoints and works as a virtual key itself.
  description = "Master key of the gateway. It must start with 'sk-', because LiteLLM rejects a key without that prefix."

  validation {
    condition     = startswith(var.master_key, "sk-")
    error_message = "The master key must start with 'sk-'."
  }
}

variable "model_backends" {
  type = map(object({
    model    = string
    api_base = string
  }))
  description = <<-EOT
  Models the gateway exposes, keyed by the alias callers ask for in the `model` field of a request.

  - `model`: name of the model at the upstream provider. The module prefixes it with `openai/`,
    which is what selects the OpenAI-compatible driver.
  - `api_base`: base URL of the upstream OpenAI-compatible endpoint, including the `/v1` suffix.

  Pass the credential for each alias in `model_backend_api_keys` under the same key.
  EOT

  validation {
    condition     = length(var.model_backends) > 0
    error_message = "Register at least one model backend. The gateway refuses to start with an empty model list."
  }

  validation {
    condition     = alltrue([for backend in var.model_backends : endswith(backend.api_base, "/v1")])
    error_message = "Every api_base must end with '/v1'. LiteLLM appends the route to this URL, so an endpoint without the suffix answers 'Not Found'."
  }

  validation {
    # Each alias becomes an environment variable name, and everything outside [A-Za-z0-9] collapses
    # into an underscore on the way. Two aliases that collapse to the same name would share one
    # credential, so reject that pair here instead of routing a request with the wrong key.
    condition = length(distinct([
      for alias in keys(var.model_backends) : upper(replace(alias, "/[^a-zA-Z0-9]/", "_"))
    ])) == length(var.model_backends)
    error_message = "Two aliases differ only in characters outside [A-Za-z0-9] and would map to the same environment variable name. Rename one of them."
  }
}

variable "model_backend_api_keys" {
  type      = map(string)
  sensitive = true
  # Kept out of var.model_backends so the backend map stays readable in plan output and in the
  # meshStack UI, and so only the credentials carry the sensitivity mark.
  description = "API key per model alias, keyed exactly like model_backends. Several aliases that share one upstream endpoint repeat the same value."

  validation {
    condition = alltrue([
      for alias in keys(var.model_backends) :
      contains(try(nonsensitive(keys(var.model_backend_api_keys)), keys(var.model_backend_api_keys)), alias)
    ])
    error_message = "Every key in model_backends needs an entry with the same key in model_backend_api_keys."
  }
}

variable "postgres_host" {
  type = string
  # Virtual keys, teams, budgets and spend tracking all live in Postgres. Without a database the
  # gateway is a stateless proxy and none of those endpoints work, so the database is required.
  description = "Hostname of the Postgres server that holds virtual keys, teams, budgets and spend records."
}

variable "postgres_port" {
  type        = number
  default     = 5432
  description = "Port of the Postgres server."
}

variable "postgres_database" {
  type        = string
  default     = "litellm"
  description = "Name of the database on the Postgres server. It has to exist before the first apply; the Prisma migration Job creates the tables inside it, not the database itself."
}

variable "postgres_username" {
  type        = string
  description = "User the gateway connects as. It needs rights to create and alter tables, because the Prisma migration Job runs the schema migrations under this user."
}

variable "postgres_password" {
  type      = string
  sensitive = true
  # The chart builds the connection URL from $(DATABASE_USERNAME) and $(DATABASE_PASSWORD), which
  # Kubernetes substitutes verbatim and does not URL-encode. A password containing ':', '@', '/'
  # or '?' therefore breaks the URL.
  description = "Password of the Postgres user. Use only characters that are safe in a URL, because the chart substitutes the value into the connection URL without encoding it."
}

variable "postgres_ssl_mode" {
  type    = string
  default = "require"
  # Managed Postgres offerings terminate TLS, so requiring it is the safe default. A server
  # without TLS needs 'prefer' or 'disable'.
  description = "Value of the sslmode parameter on the Postgres connection URL. One of 'disable', 'prefer', 'require', 'verify-ca' or 'verify-full'."

  validation {
    condition     = contains(["disable", "prefer", "require", "verify-ca", "verify-full"], var.postgres_ssl_mode)
    error_message = "postgres_ssl_mode must be one of 'disable', 'prefer', 'require', 'verify-ca' or 'verify-full'."
  }
}

variable "postgres_connection_limit" {
  type    = number
  default = 10
  # Both the gateway and its migration Job talk to Postgres through Prisma, which sizes its pool
  # from the node's physical cores when the connection URL names no limit. See the connection
  # budget section in the module README.
  description = <<-EOT
  Maximum number of Postgres connections one gateway pod opens. The module writes it as
  `connection_limit` on the connection URL and as `general_settings.database_connection_pool_limit`
  in the proxy config, because the proxy rewrites the URL on startup from that setting.

  Without the parameter Prisma sizes the pool as `physical cores × 2 + 1` read from the node, not
  from the pod's CPU limit, so a pod takes 33 connections on a 16-core node and a different number
  after it is rescheduled. The gateway is deployed once for the platform, so it costs
  `replica_count × postgres_connection_limit` connections in total.

  The default of 10 is LiteLLM's own default, so pinning the value changes nothing at runtime and
  only bounds what the URL asks for.
  EOT

  validation {
    condition     = var.postgres_connection_limit >= 1
    error_message = "postgres_connection_limit must be at least 1."
  }
}

variable "redis_host" {
  type    = string
  default = null
  # Redis is the coordination store of the gateway: cross-pod rate limits, spend tracking and the
  # pod lock manager. One pod needs none of that, several pods do.
  description = "Hostname of an existing Redis instance the gateway coordinates through. Leave it null to run without Redis, which is only correct with a single replica."
}

variable "redis_port" {
  type        = number
  default     = 6379
  description = "Port of the Redis instance. Only used when redis_host is set."
}

variable "redis_password" {
  type        = string
  sensitive   = true
  default     = null
  description = "Password of the Redis instance. Leave it null for a Redis without authentication. Only used when redis_host is set."
}
