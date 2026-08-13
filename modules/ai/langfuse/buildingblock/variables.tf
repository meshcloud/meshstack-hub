variable "namespace" {
  type    = string
  default = "langfuse"
  # One tenant per namespace. The caller derives the name, because this module is instantiated
  # once per tenant and two tenants in one namespace would share Service names and Secrets.
  description = "Namespace this tenant's Langfuse instance runs in. The module creates it. Give every tenant a namespace of its own."
}

variable "release_name" {
  type    = string
  default = "langfuse"
  # The chart derives the Service name from the release name: '<release>-langfuse-web', or just
  # '<release>-web' when the release name already contains 'langfuse'.
  description = "Helm release name of this tenant's Langfuse instance."
}

variable "chart_version" {
  type        = string
  default     = "1.5.41"
  description = "Version of the langfuse chart from https://langfuse.github.io/langfuse-k8s. This is a classic Helm repository, not an OCI registry."
}

variable "image_tag" {
  type    = string
  default = "4.10.0"
  # The chart's appVersion is 3.224.1, so the chart alone installs Langfuse v3. Overriding the tag
  # is what selects v4, exactly as examples/v4-installation in langfuse-k8s does.
  description = <<-EOT
  Tag of the langfuse/langfuse and langfuse/langfuse-worker images. It has to name a concrete v4
  release, because the chart's own appVersion still points at v3.

  Do not use the floating `"4"` tag. It moves whenever Langfuse publishes a v4 release, so two
  pods of the same Deployment can end up on two different builds, a `helm upgrade` that changes
  nothing still rolls the Deployment, and a regression cannot be rolled back by reverting the
  Terraform change. Pin a full version and raise it deliberately.
  EOT

  validation {
    condition     = can(regex("^4\\.[0-9]+\\.[0-9]+$", var.image_tag))
    error_message = "image_tag must be a concrete Langfuse v4 release such as '4.10.0'. The floating tags '4' and '4.10' move under the running Deployment."
  }
}

variable "hostname" {
  type = string
  # NEXTAUTH_URL is baked into every OAuth callback and every link in an invitation mail. The
  # chart's default is http://localhost:3000, which breaks both.
  description = "Canonical hostname of this tenant's Langfuse instance, without a scheme. The module derives NEXTAUTH_URL and the Ingress rule from it."

  validation {
    condition     = !strcontains(var.hostname, "://")
    error_message = "hostname must be a bare hostname without a scheme, for example 'langfuse-team-a.example.com'."
  }
}

variable "public_url" {
  type    = string
  default = null
  # Only needed when the instance is not reached over HTTPS on var.hostname, for example behind a
  # proxy that terminates on a different name.
  description = "Full canonical URL of this tenant's Langfuse instance, used as NEXTAUTH_URL. Null derives 'https://<hostname>'."
}

variable "helm_timeout" {
  type        = number
  default     = 900
  description = "Seconds to wait for the Helm release to become ready. Every web pod runs the Postgres and the ClickHouse migrations before it answers its readiness probe, so the first install takes part of this budget."
}

# --- Secrets that must differ per tenant -------------------------------------------------------

variable "salt" {
  type      = string
  sensitive = true
  # SALT hashes the API keys of this tenant. Langfuse also mixes it into the fast hash of every
  # key, so changing it invalidates every key the tenant holds.
  description = "Salt Langfuse hashes API keys with. It must be unique per tenant, because two tenants sharing a salt share the hash space of their API keys. Changing it later invalidates every API key of the tenant."

  validation {
    condition     = length(var.salt) >= 32
    error_message = "The salt must be at least 32 characters long. Generate one with `openssl rand -base64 32`."
  }
}

variable "encryption_key" {
  type      = string
  sensitive = true
  # ENCRYPTION_KEY encrypts secrets at rest in this tenant's Postgres — LLM API keys, integration
  # credentials and the like.
  description = "Key Langfuse encrypts secrets at rest with, in this tenant's Postgres database. Must be 256 bits, which is 64 hex characters. Generate one with `openssl rand -hex 32`. It must be unique per tenant, because it is the only thing separating one tenant's stored credentials from another's."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{64}$", var.encryption_key))
    error_message = "The encryption key must be exactly 64 hexadecimal characters, which is 256 bits."
  }
}

variable "nextauth_secret" {
  type        = string
  sensitive   = true
  description = "Secret NextAuth signs its JWTs and hashes email verification tokens with. It must be unique per tenant, otherwise a session token minted for one tenant is accepted by another. Generate one with `openssl rand -base64 32`."

  validation {
    condition     = length(var.nextauth_secret) >= 32
    error_message = "The NextAuth secret must be at least 32 characters long."
  }
}

# --- Postgres ---------------------------------------------------------------------------------

variable "postgres_host" {
  type        = string
  description = "Hostname of the shared Postgres server. Langfuse keeps its relational data — organisations, projects, users, prompts and encrypted secrets — here."
}

variable "postgres_port" {
  type    = number
  default = 5432
  # Langfuse never reads DATABASE_PORT. Its entrypoint builds DATABASE_URL from DATABASE_HOST
  # alone, so the module folds the port into the host it hands the chart.
  description = "Port of the Postgres server. The module appends it to the host, because Langfuse builds its connection URL from the host only and ignores the port variable the chart sets."
}

variable "postgres_database" {
  type = string
  # Per-tenant separation in Postgres is a database plus an owner user. The caller creates both;
  # this module only connects.
  description = "Name of this tenant's Postgres database. It has to exist before the first apply, together with its owner user — Prisma creates the tables inside it, not the database itself."
}

variable "postgres_username" {
  type        = string
  description = "User Langfuse connects as. It has to own this tenant's database, because `prisma migrate deploy` creates and alters tables under it on every web pod start."
}

variable "postgres_password" {
  type      = string
  sensitive = true
  # The entrypoint substitutes the value into postgresql://<user>:<password>@<host>/<db> verbatim
  # and does not percent-encode it. Prisma then answers P1013 on a password with a reserved
  # character in it.
  description = "Password of the Postgres user. Use only characters that are safe in a URL: Langfuse builds its connection URL by string substitution and does not percent-encode the value."

  validation {
    condition     = !can(regex("[:@/?#%]", var.postgres_password))
    error_message = "The Postgres password must not contain ':', '@', '/', '?', '#' or '%'. Langfuse substitutes it into the connection URL without percent-encoding, and Prisma then fails with P1013."
  }
}

variable "postgres_args" {
  type    = string
  default = "sslmode=require"
  # Appended to the connection URL after a '?', so no leading question mark here.
  description = "Query string appended to the Postgres connection URL, without the leading '?'. Managed Postgres offerings terminate TLS, so requiring it is the safe default. A server without TLS needs 'sslmode=prefer' or 'sslmode=disable'. The module appends `connection_limit` from postgres_connection_limit, and `pool_timeout` belongs here when the default of 10 seconds is too short for the pinned pool."

  validation {
    condition     = !can(regex("connection_limit", var.postgres_args))
    error_message = "postgres_args must not carry connection_limit. Set postgres_connection_limit instead: the module appends the parameter itself, and two occurrences in one query string leave the effective pool size to the parser."
  }
}

variable "postgres_connection_limit" {
  type    = number
  default = 5
  # See the connection budget section in the module README for the arithmetic.
  description = <<-EOT
  Maximum number of Postgres connections one Langfuse pod opens. The module appends it to the
  connection URL as `connection_limit`, next to `postgres_args`.

  Without the parameter Prisma sizes the pool as `physical cores × 2 + 1` read from the node, not
  from the pod's CPU limit, so a pod takes 33 connections on a 16-core node and a different number
  after it is rescheduled onto a node with more cores.

  This module runs once per tenant against a shared instance, so the platform's budget is
  `tenants × pods per tenant × connection_limit + 15 ≤ max_connections`. STACKIT PostgreSQL Flex
  fixes `max_connections` per flavour and reserves 15 of them, so the default of 5 is what keeps a
  4 vCPU / 32 GiB instance at roughly 34 tenants with four pods each.
  EOT

  validation {
    condition     = var.postgres_connection_limit >= 1
    error_message = "postgres_connection_limit must be at least 1."
  }
}

variable "postgres_direct_url" {
  type      = string
  sensitive = true
  default   = null
  # DIRECT_URL is what the migrations run against. Without it the entrypoint reuses DATABASE_URL.
  description = "Full connection URL the schema migrations run against, used when the normal connection goes through a pooler or when migrations need a user with longer timeouts. The module appends `connection_limit` from postgres_direct_url_connection_limit to it. Null makes the migrations reuse the normal connection, which already carries the pinned pool."

  validation {
    condition     = var.postgres_direct_url == null ? true : !can(regex("connection_limit", var.postgres_direct_url))
    error_message = "postgres_direct_url must not carry connection_limit. Set postgres_direct_url_connection_limit instead: the module appends the parameter itself."
  }
}

variable "postgres_direct_url_connection_limit" {
  type    = number
  default = 2
  # A migration is not a pool. The web entrypoint runs `prisma db execute` and then
  # `prisma migrate deploy`, one after the other, and each opens a single connection.
  description = "Maximum number of Postgres connections the migration connection opens, appended to postgres_direct_url as `connection_limit`. Two covers the `prisma db execute` and the `prisma migrate deploy` the web entrypoint runs one after the other, each of which opens a single connection. Only used when postgres_direct_url is set."

  validation {
    condition     = var.postgres_direct_url_connection_limit >= 1
    error_message = "postgres_direct_url_connection_limit must be at least 1."
  }
}

variable "postgres_auto_migrate" {
  type    = bool
  default = true
  # See the ClickHouse counterpart: every web pod runs the migrations on every start.
  description = "Run `prisma migrate deploy` on every web pod start. Turn it off above a handful of tenants and run the migrations once out of band, because every pod of every tenant runs them on every restart."
}

# --- ClickHouse -------------------------------------------------------------------------------

variable "clickhouse_host" {
  type        = string
  description = "Fully qualified hostname of the shared ClickHouse cluster, without a scheme. Take it from the `host` output of modules/ai/clickhouse."
}

variable "clickhouse_http_port" {
  type        = number
  default     = 8123
  description = "HTTP port of ClickHouse. Langfuse reads and writes trace data over it."
}

variable "clickhouse_native_port" {
  type        = number
  default     = 9000
  description = "Native protocol port of ClickHouse. The golang-migrate schema migrations use it."
}

variable "clickhouse_database" {
  type = string
  # Per-tenant separation in ClickHouse is a database plus a user scoped to '<database>.*'. The
  # caller creates both.
  description = "Name of this tenant's ClickHouse database. It has to exist before the first apply: golang-migrate creates the tables inside it and never creates a database."
}

variable "clickhouse_username" {
  type        = string
  description = "ClickHouse user Langfuse connects as. It needs SELECT, INSERT, CREATE, DROP TABLE, ALTER UPDATE, ALTER DELETE and ALTER DROP INDEX on its own database, and nothing beyond it."
}

variable "clickhouse_password" {
  type      = string
  sensitive = true
  # The migration script interpolates the password into a query string, so a reserved character
  # in it breaks the migration URL rather than the connection.
  description = "Password of the ClickHouse user. Avoid '&', '=', '#', '?', '%', '+', '@' and spaces: the migration script puts the value into a query string without encoding it."

  validation {
    condition     = !can(regex("[&=#?%+@ ]", var.clickhouse_password))
    error_message = "The ClickHouse password must not contain '&', '=', '#', '?', '%', '+', '@' or a space. The Langfuse migration script interpolates it into a query string without encoding."
  }
}

variable "clickhouse_cluster_enabled" {
  type    = bool
  default = true
  # The operator names its ClickHouse cluster 'default', which is what Langfuse writes its
  # ON CLUSTER statements against.
  description = "Run the ClickHouse DDL with ON CLUSTER. Keep it on for the operator-managed cluster, which is a real cluster named 'default' even with a single replica. Turn it off only for a standalone ClickHouse with no Keeper."
}

variable "clickhouse_auto_migrate" {
  type        = bool
  default     = true
  description = "Run the ClickHouse `migrate up` on every web pod start. Turn it off above a handful of tenants and run the migrations once out of band: the statements are ON CLUSTER DDL, and several tenants upgrading at once contend for one distributed DDL queue."
}

# --- Valkey -----------------------------------------------------------------------------------

variable "valkey_host" {
  type        = string
  description = "Hostname of the shared Valkey or Redis instance. Langfuse uses it as the BullMQ queue backend, the cache and the rate limit store."
}

variable "valkey_port" {
  type        = number
  default     = 6379
  description = "Port of the Valkey instance."
}

variable "valkey_username" {
  type        = string
  default     = "default"
  description = "Username for Valkey authentication. Null omits the username from the connection string, which is what a Valkey without ACLs expects."
}

variable "valkey_password" {
  type      = string
  sensitive = true
  # The chart puts the value into the connection URL as $(REDIS_PASSWORD), which Kubernetes
  # substitutes verbatim.
  description = "Password of the Valkey instance. Use only characters that are safe in a URL, because the chart substitutes the value into the connection URL without encoding it."
}

variable "valkey_database" {
  type = number
  # The DB index is a hard namespace: SELECT n puts the connection in a keyspace no command can
  # reach out of, so no application bug can cross it.
  description = "Valkey database index of this tenant. It is a hard namespace that no application bug can cross, so give every tenant an index of its own. A stock Valkey serves indices 0 to 15."

  validation {
    condition     = var.valkey_database >= 0
    error_message = "valkey_database must be zero or greater."
  }
}

variable "valkey_key_prefix" {
  type = string
  # REDIS_KEY_PREFIX is not exposed by the chart, so the module injects it through
  # langfuse.additionalEnv. It survives a later move to Redis Cluster, where DB indices vanish.
  description = <<-EOT
  Prefix Langfuse puts in front of every Valkey key and every BullMQ queue name for this tenant,
  for example `tenant-a:`. Give every tenant a prefix of its own.

  Set it together with `valkey_database`, not instead of it. The index is a hard namespace that no
  application bug can cross; the prefix survives a later move to Redis Cluster, where indices
  vanish because a cluster only has database 0.

  Langfuse needs at least app version 3.157.0 for this to work. The variable existed before, but
  BullMQ ignored it until langfuse/langfuse#11898 merged on 2026-03-06.
  EOT

  validation {
    condition     = length(var.valkey_key_prefix) > 0
    error_message = "valkey_key_prefix must not be empty. Sharing one Valkey database without a key prefix lets one tenant's worker consume another tenant's ingestion jobs."
  }
}

# --- S3 ---------------------------------------------------------------------------------------

variable "s3_bucket" {
  type = string
  # One bucket per tenant. Prefixes inside it only separate the three kinds of upload.
  description = "Bucket this tenant's event uploads, batch exports and media uploads go to. Give every tenant a bucket of its own."
}

variable "s3_region" {
  type        = string
  default     = "auto"
  description = "Region of the bucket. 'auto' works for S3-compatible object storage that has no region concept."
}

variable "s3_endpoint" {
  type        = string
  description = "Endpoint URL of the object storage, including the scheme."
}

variable "s3_force_path_style" {
  type    = bool
  default = true
  # Virtual-hosted style needs a wildcard DNS record per bucket, which S3-compatible storage
  # outside AWS rarely provides.
  description = "Address the bucket as a path on the endpoint instead of as a subdomain. Required for MinIO and for most S3-compatible object storage."
}

variable "s3_access_key_id" {
  type        = string
  sensitive   = true
  description = "Access key id of the credential scoped to this tenant's bucket."
}

variable "s3_secret_access_key" {
  type        = string
  sensitive   = true
  description = "Secret access key of the credential scoped to this tenant's bucket."
}

variable "s3_event_upload_prefix" {
  type        = string
  default     = "events/"
  description = "Prefix inside the bucket for raw ingestion events. Keep the trailing slash."
}

variable "s3_batch_export_prefix" {
  type        = string
  default     = "exports/"
  description = "Prefix inside the bucket for batch exports. Keep the trailing slash."
}

variable "s3_media_upload_prefix" {
  type        = string
  default     = "media/"
  description = "Prefix inside the bucket for media uploads. Keep the trailing slash."
}

# --- Bootstrap --------------------------------------------------------------------------------

variable "init_org_id" {
  type = string
  # LANGFUSE_INIT_ORG_ID is the trigger of the whole bootstrap. Without it Langfuse logs a warning
  # and silently ignores every other LANGFUSE_INIT_* variable.
  description = "Identifier of the organisation Langfuse creates on startup. It is the trigger of the whole bootstrap: with it unset, every other init value is silently ignored."

  validation {
    condition     = length(var.init_org_id) > 0
    error_message = "init_org_id must not be empty."
  }
}

variable "init_org_name" {
  type        = string
  description = "Display name of the organisation."
}

variable "init_project_id" {
  type        = string
  description = "Identifier of the project Langfuse creates inside the organisation. Traces belong to a project, and the API keypair below is scoped to it."
}

variable "init_project_name" {
  type        = string
  description = "Display name of the project."
}

variable "init_project_public_key" {
  type = string
  # Langfuse accepts a predefined keypair, so Terraform generates the keys instead of reading them
  # back out of a UI. Nothing about this is gated behind an Enterprise entitlement.
  description = "Public key of the API keypair Langfuse creates for the project. Langfuse's own generator produces 'pk-lf-<uuid>', and clients expect that shape."

  validation {
    condition     = startswith(var.init_project_public_key, "pk-lf-")
    error_message = "init_project_public_key must start with 'pk-lf-'."
  }
}

variable "init_project_secret_key" {
  type        = string
  sensitive   = true
  description = "Secret key of the API keypair Langfuse creates for the project. Langfuse's own generator produces 'sk-lf-<uuid>', and clients expect that shape."

  validation {
    condition     = startswith(var.init_project_secret_key, "sk-lf-")
    error_message = "init_project_secret_key must start with 'sk-lf-'."
  }
}

variable "init_user_email" {
  type    = string
  default = null
  # This creates a password user. It contradicts disable_username_password, so leave it unset
  # whenever an identity provider is configured and let the owner arrive through SSO instead.
  description = "Email address of a first user with a password, given OWNER membership in the organisation. Leave it null when var.oidc is set: a password user cannot log in once username and password login is off."
}

variable "init_user_name" {
  type        = string
  default     = null
  description = "Display name of the first user. Null lets Langfuse name it 'Provisioned User'. Only used when init_user_email and init_user_password are both set."
}

variable "init_user_password" {
  type      = string
  sensitive = true
  default   = null
  # Langfuse sets it while creating the user and never again, so a later change to this value
  # does not reset the password.
  description = "Password of the first user. Langfuse only sets it while creating the user, so changing this value later does not reset the password. Both init_user_email and init_user_password have to be set, or neither."

  validation {
    condition     = var.init_user_password == null || length(coalesce(var.init_user_password, "")) >= 12
    error_message = "The initial user password must be at least 12 characters long."
  }

  validation {
    condition     = (var.init_user_email == null) == (var.init_user_password == null)
    error_message = "Set both init_user_email and init_user_password, or neither. Langfuse logs a warning and creates no user when only one of them is present."
  }
}

# --- Authentication ---------------------------------------------------------------------------

variable "oidc" {
  description = <<-EOT
  OIDC identity provider this tenant's users log in through. Null leaves the instance on username
  and password login, which then needs `init_user_email` and `init_user_password`.

  Self-hosted SSO is free in Langfuse. It carries no entitlement, so it works without an
  Enterprise licence.

  - `issuer_url`: discovery base URL of the provider, for example
    `https://idp.example.com/realms/ai`. Langfuse reads `<issuer_url>/.well-known/openid-configuration`.
  - `client_id` and `client_secret`: credentials of the OIDC client.
  - `display_name`: label on the login button. The provider is not registered without it.
  - `scopes`: space-separated scope list. The default covers what Langfuse needs.
  - `allow_account_linking`: link an OIDC login to an existing user with the same email address.
    Turn it on when a user already exists from a password login or from another provider.

  Register the callback URL `<public_url>/api/auth/callback/custom` at the provider.

  Give every tenant an OIDC client of its own and assign only that tenant's members to it. See the
  access control note in the module README: with auto-join on, everyone the provider authenticates
  becomes a member of this tenant's organisation.
  EOT

  type = object({
    issuer_url            = string
    client_id             = string
    client_secret         = string
    display_name          = optional(string, "Single Sign-On")
    scopes                = optional(string, "openid email profile")
    allow_account_linking = optional(bool, true)
  })

  default   = null
  sensitive = true

  validation {
    condition     = var.oidc != null || var.init_user_email != null
    error_message = "Set var.oidc, or set init_user_email and init_user_password. Without one of the two, nobody can log in to the instance."
  }

  # The message carries no interpolation, because var.oidc is sensitive and Terraform refuses to
  # print a sensitive value in an error message.
  validation {
    condition     = var.oidc == null || startswith(var.oidc.issuer_url, "https://")
    error_message = "oidc.issuer_url must be an https URL. It is the discovery base URL, not the authorization endpoint."
  }
}

variable "disable_username_password" {
  type    = bool
  default = null
  # Null derives it from var.oidc: with an identity provider configured, username and password
  # login is the thing to turn off, not sign-up.
  description = "Turn off username and password login, so only the OIDC provider remains. Null turns it on whenever var.oidc is set. Never set it to true without an identity provider: nobody could log in."

  validation {
    condition     = var.disable_username_password != true || var.oidc != null
    error_message = "disable_username_password cannot be true without var.oidc, because that would leave no way to log in."
  }
}

variable "default_org_role" {
  type    = string
  default = "MEMBER"
  # Langfuse upserts an organisation membership with this role for every user who logs in, and
  # there is no entitlement check on that path. With one organisation and one project per tenant,
  # the organisation role is the whole access grant.
  description = <<-EOT
  Role every user who logs in receives in this tenant's organisation. Langfuse upserts the
  membership on first login and on every later login, and the upsert never overwrites a role a
  user already has.

  This removes member synchronisation from the picture: no group mapping and no SCIM. Set `NONE`
  to hand out a membership that grants nothing, which is the way to turn auto-join off while
  keeping the instance usable for users who were added by hand.
  EOT

  validation {
    condition     = contains(["OWNER", "ADMIN", "MEMBER", "VIEWER", "NONE"], var.default_org_role)
    error_message = "default_org_role must be one of OWNER, ADMIN, MEMBER, VIEWER or NONE."
  }
}

# --- Ingress ----------------------------------------------------------------------------------

variable "ingress_enabled" {
  type        = bool
  default     = true
  description = "Create an Ingress for var.hostname. Turn it off when the instance is reached in-cluster only, and set var.public_url accordingly."
}

variable "ingress_class_name" {
  type        = string
  default     = "haproxy"
  description = "Name of the IngressClass that serves this instance. It has to match the controller modules/kubernetes/ingress installs."
}

variable "ingress_annotations" {
  type        = map(string)
  default     = {}
  description = "Annotations on the Ingress. Set `cert-manager.io/cluster-issuer` here when the instance needs a certificate of its own instead of the controller's wildcard certificate."
}

variable "ingress_tls_secret_name" {
  type    = string
  default = null
  # With the wildcard certificate from modules/kubernetes/ingress the controller already serves
  # HTTPS for every host it does not have a certificate for, so the Ingress needs no tls block.
  description = "Name of the secret holding the TLS certificate for var.hostname. Null leaves the Ingress without a tls block, which is correct when the ingress controller serves a wildcard certificate as its default."
}

# --- Sizing -----------------------------------------------------------------------------------

variable "web_replicas" {
  type        = number
  default     = 1
  description = "Number of Langfuse web pods. The default of 1 is sized for a demonstration and gives no redundancy: every restart interrupts the UI and the ingestion API."
}

variable "worker_replicas" {
  type        = number
  default     = 1
  description = "Number of Langfuse worker pods. The default of 1 is sized for a demonstration. Raise it when the ingestion queue backs up."
}

variable "web_resources" {
  type = object({
    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})
    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})
  })
  nullable = false
  default = {
    requests = { cpu = "100m", memory = "512Mi" }
    limits   = { cpu = "500m", memory = "1Gi" }
  }
  description = <<-EOT
  Resource requests and limits of the Langfuse web pods. The default is sized for a demonstration
  and a production consumer has to raise it.

  The chart sets `resources: {}` for the web deployment, so the pods run unbounded without these
  values. The web pod serves the UI and the ingestion API and runs both migrations on start, which
  is the peak of its memory use. Production wants `500m` CPU and `2Gi` of memory.

  The module derives `NODE_OPTIONS=--max-old-space-size` from the memory limit at roughly 75%, so
  Node runs a garbage collection before the cgroup limit is reached instead of being OOMKilled.
  EOT
}

variable "worker_resources" {
  type = object({
    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})
    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})
  })
  nullable = false
  default = {
    requests = { cpu = "100m", memory = "384Mi" }
    limits   = { cpu = "500m", memory = "768Mi" }
  }
  description = <<-EOT
  Resource requests and limits of the Langfuse worker pods. The default is sized for a
  demonstration and a production consumer has to raise it.

  The chart sets `resources: {}` for the worker deployment as well. The worker drains the BullMQ
  queues and batches writes into ClickHouse, so its memory grows with the batch size rather than
  with the number of users. Production wants `500m` CPU and `2Gi` of memory.

  The module derives `NODE_OPTIONS=--max-old-space-size` from the memory limit at roughly 75%.
  EOT
}

variable "telemetry_enabled" {
  type        = bool
  default     = false
  description = "Report basic usage statistics to Langfuse. The chart turns this on by default; a self-hosted tenant instance usually should not phone home."
}
