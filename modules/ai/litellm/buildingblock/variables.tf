variable "cluster_endpoint" {
  type        = string
  description = "IP address or hostname of the cluster control plane, without the https:// scheme."
}

variable "cluster_ca_certificate" {
  type        = string
  description = "Cluster CA certificate, base64 encoded."
}

# The cluster credential is either a service account token or a client certificate pair. A
# composition that installs the gateway on a cluster it just created usually holds the certificate
# pair, because that is what a managed cluster's credential API returns — STACKIT SKE among them.
# `modules/ai/model-access` accepts both for the same reason.
variable "token" {
  type        = string
  sensitive   = true
  default     = null
  description = "Token of the service account this module runs as. It needs permission to create a namespace, secrets and the workloads of the Helm release. Leave it null and set `client_certificate` and `client_key` instead when the cluster hands out a certificate pair."

  # The message carries no interpolation, because both values are sensitive and Terraform refuses
  # to print a sensitive value in an error message.
  validation {
    condition     = (var.token != null) != (var.client_certificate != null)
    error_message = "Set either token or client_certificate, not both and not neither. Without a credential every call to the API server is anonymous and the install fails on the first namespace."
  }
}

variable "client_certificate" {
  type        = string
  sensitive   = true
  default     = null
  description = "PEM-encoded client certificate this module authenticates with, as an alternative to `token`. Pass the decoded certificate, not the base64 blob a kubeconfig carries."
}

variable "client_key" {
  type        = string
  sensitive   = true
  default     = null
  description = "PEM-encoded private key belonging to `client_certificate`. Pass the decoded key, not the base64 blob a kubeconfig carries."

  validation {
    condition     = (var.client_certificate == null) == (var.client_key == null)
    error_message = "client_certificate and client_key belong together. Set both or neither."
  }
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

# --- Admin console ----------------------------------------------------------------------------

variable "public_url" {
  type    = string
  default = null
  # The proxy reads it as PROXY_BASE_URL and builds the SSO callback from it. Its fallback is the
  # base URL of the incoming request, which behind a TLS-terminating Ingress is the internal
  # http://<pod> address, so the redirect URI never matches what the provider has registered.
  description = <<-EOT
  Canonical URL the gateway is reached at from outside the cluster, for example
  `https://litellm.example.com`, without a trailing slash. The module writes it as
  `PROXY_BASE_URL`, and the proxy builds the SSO callback as `<public_url>/sso/callback`.

  Required when `var.oidc` is set. The proxy falls back to the base URL of the incoming request,
  which behind a TLS-terminating Ingress is the internal `http://` address of the pod, and the
  provider then rejects the redirect URI. The module creates no Ingress, so this is the URL of
  whatever Ingress or load balancer stands in front of the Service.
  EOT

  validation {
    condition     = var.public_url == null || startswith(coalesce(var.public_url, ""), "https://")
    error_message = "public_url must be an https URL, because the identity provider redirects the browser back to it."
  }

  validation {
    condition     = var.public_url == null || !endswith(coalesce(var.public_url, ""), "/")
    error_message = "public_url must not end with a slash. The proxy appends '/sso/callback' to it."
  }
}

variable "oidc" {
  description = <<-EOT
  OIDC identity provider the platform engineers log in to the admin console through. Null leaves
  the console without a login path, which is the correct setting for a gateway nobody administers
  through the browser.

  Native SSO is free in the open-source proxy for up to five users, and it needs no Enterprise
  licence below that.

  - `issuer_url`: discovery base URL of the provider, for example
    `https://idp.example.com/realms/ai`. The module reads
    `<issuer_url>/.well-known/openid-configuration` and takes the three endpoints from it, because
    the proxy wants them spelled out and does no discovery of its own.
  - `client_id` and `client_secret`: credentials of the OIDC client.
  - `scopes`: space-separated scope list.
  - `authorization_endpoint`, `token_endpoint`, `userinfo_endpoint`: override one endpoint each and
    skip discovery for it. Set all three when the provider is unreachable from the Terraform
    runner, and the module then creates no discovery request at all.
  - `user_id_attribute`: claim the proxy stores as the user id. It defaults to `sub` here, not to
    the proxy's own default of `preferred_username`, because `preferred_username` is reassignable
    at most providers and a reassignment produces a second row in the user table for the same
    person. Every row counts against the limit of five.
  - `user_email_attribute`, `user_display_name_attribute`, `user_role_attribute`: the rest of the
    claim mapping. Null leaves the proxy on its own defaults, which are `email`, `sub` and `role`.
  - `allowed_email_domains`: only users whose email address carries one of these domains may log
    in. The proxy compares the part after the `@` exactly, so there is no wildcard and no
    subdomain match. Null lets every user the provider authenticates log in.
  - `proxy_admin_id`: user id that is set to the `proxy_admin` role on every login. It is compared
    against the value of the `user_id_attribute` claim, so it is that claim's value and not an
    email address unless the claim carries one.
  - `logout_url`: URL the console sends the browser to after a logout.
  - `auto_redirect_to_sso`: send the login page straight to the provider instead of showing a
    button.

  Register the callback URL `<public_url>/sso/callback` at the provider. The module sets no
  `SERVER_ROOT_PATH`, which is the only setting that would move the callback to another path.

  **The console holds at most five users.** Read the free user limit section of the module README
  before you hand the console to a sixth person: the sixth login locks out everyone.
  EOT

  type = object({
    issuer_url    = string
    client_id     = string
    client_secret = string
    scopes        = optional(string, "openid email profile")

    authorization_endpoint = optional(string)
    token_endpoint         = optional(string)
    userinfo_endpoint      = optional(string)

    user_id_attribute           = optional(string, "sub")
    user_email_attribute        = optional(string)
    user_display_name_attribute = optional(string)
    user_role_attribute         = optional(string)

    allowed_email_domains = optional(list(string))
    proxy_admin_id        = optional(string)
    logout_url            = optional(string)
    auto_redirect_to_sso  = optional(bool, false)
  })

  default   = null
  sensitive = true

  # The messages carry no interpolation, because var.oidc is sensitive and Terraform refuses to
  # print a sensitive value in an error message.
  validation {
    condition     = var.oidc == null || startswith(var.oidc.issuer_url, "https://")
    error_message = "oidc.issuer_url must be an https URL. It is the discovery base URL, not the authorization endpoint."
  }

  validation {
    condition     = var.oidc == null || var.public_url != null
    error_message = "Set var.public_url together with var.oidc. The proxy builds the SSO callback URL from PROXY_BASE_URL, and login fails without it."
  }
}

variable "disable_auto_add_proxy_admin_to_teams" {
  type    = bool
  default = true
  # This is the switch that keeps LiteLLM_UserTable empty, which is what keeps the console inside
  # the free limit of five users. See the free user limit section of the module README.
  description = <<-EOT
  Write `general_settings.disable_auto_add_proxy_admin_to_teams: true` into the proxy config, so
  the proxy adds no admin member to a team it creates.

  Leave it at `true`. With it `false`, the first call to `/team/new` writes one row to
  `LiteLLM_UserTable` and that row consumes one of the five console seats the free open-source
  proxy allows. The row is written once and not once per team, because every caller that
  authenticates with the master key is identified as the same constant user id, but it still costs
  one of the five seats.
  EOT
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
