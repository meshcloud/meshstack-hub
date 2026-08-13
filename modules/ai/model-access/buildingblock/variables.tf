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
  type      = string
  sensitive = true
  # `delete` is in the list because `version_spec.deletion_mode` is `DELETE`: destroying the building
  # block destroys the Secret, and without the verb that destroy fails with a 403. See the residual
  # risk section of the module README.
  description = "kubeconfig of the demo application cluster, as YAML. Only the Secret with the model credential is written here, so the credential needs no more than `get`, `create`, `update`, `patch` and `delete` on secrets."
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

# --- STACKIT, where the per-tenant backends are created -----------------------------------------
#
# The module creates the tenant's Postgres database, its owner user and its bucket, so it is bound to
# STACKIT. That is deliberate: `modules/ai/` groups a capability rather than promising
# cloud-agnosticism, and `modules/ai/azure-openai` sits in the same directory. An Azure twin of this
# module would repeat the shape with Azure submodules.

variable "stackit_project_id" {
  type        = string
  description = "STACKIT project the shared PostgreSQL Flex instance and the tenants' buckets live in. The module creates one database and one bucket per tenant inside it."
}

variable "stackit_service_account_key" {
  type      = string
  sensitive = true
  # The hub convention for modules under modules/stackit/ is workload identity federation, which
  # needs a backplane that registers a federated identity provider for this definition. This module
  # has no backplane, so it takes the key. See the STACKIT credential section of the module README.
  description = "Service account key of the STACKIT service account, as the JSON STACKIT returns when the key is created, including the private key. The account needs permission to create databases and users on the PostgreSQL Flex instance and to create Object Storage credentials groups in the project."
}

variable "stackit_s3_admin_access_key" {
  type      = string
  sensitive = true
  # The bucket itself is created with the `aws` provider used as a generic S3 client, because the
  # stackit provider has no permission to create one. modules/stackit/storage-bucket does the same.
  description = "Access key of the administrative Object Storage credential the bucket is created with. It has to belong to the credentials group named by `stackit_s3_admin_credentials_group_urn`, otherwise the bucket policy locks the run out of the bucket it just created."
}

variable "stackit_s3_admin_secret_access_key" {
  type        = string
  sensitive   = true
  description = "Secret access key of the administrative Object Storage credential."
}

variable "stackit_s3_admin_credentials_group_urn" {
  type        = string
  description = "URN of the administrative Object Storage credentials group, in the form 'urn:sgws:identity::<account_id>:group/<group_id>'. The bucket policy keeps access for this group, so the platform team can still reach a tenant's bucket."
}

# --- The backends the Langfuse instances share --------------------------------------------------
#
# Each of the four backends is shared across tenants and separated by name: a database, a bucket, a
# key prefix. This module derives those names from the tenant context. It creates the Postgres
# database, the ClickHouse database and the bucket; the shared servers themselves, and the credentials
# it creates those resources with, arrive as STATIC inputs.

variable "langfuse_postgres_instance_id" {
  type        = string
  description = "UUID of the shared STACKIT PostgreSQL Flex instance. The module creates the tenant's database and its owner user inside it and never creates or changes the instance itself."
}

variable "langfuse_clickhouse_host" {
  type        = string
  description = "Fully qualified hostname of the shared ClickHouse cluster, without a scheme. Take it from the `host` output of modules/ai/clickhouse."
}

variable "langfuse_clickhouse_native_port" {
  type    = number
  default = 9000
  # The `native_port` output of modules/ai/clickhouse. Langfuse's golang-migrate migrations and the
  # clickhouse-client in the DDL Job both speak the native protocol.
  description = "Native protocol port of the shared ClickHouse cluster. The DDL Job and the Langfuse migrations both connect over it."
}

variable "langfuse_clickhouse_namespace" {
  type    = string
  default = "clickhouse"
  # The `namespace` output of modules/ai/clickhouse. The DDL Job runs here rather than in the tenant's
  # own namespace, because it has to run before the tenant's Langfuse namespace exists.
  description = "Namespace of the shared ClickHouse cluster in the AI platform cluster. The DDL Job of this tenant runs in it and mounts the administrative password from the Secret in it."
}

variable "langfuse_clickhouse_ddl_cluster_name" {
  type    = string
  default = "default"
  # The `ddl_cluster_name` output of modules/ai/clickhouse. Every ON CLUSTER statement names it, the
  # Langfuse migrations included.
  description = "Name of the ClickHouse cluster as the server knows it. The DDL of this module runs ON CLUSTER with this name, which is required as soon as the cluster has more than one replica and harmless with one."
}

variable "langfuse_clickhouse_admin_username" {
  type    = string
  default = "default"
  # The `admin_username` output of modules/ai/clickhouse. The operator only manages the 'default'
  # user, so this is the name in practice.
  description = "Name of the administrative ClickHouse user the DDL Job authenticates as. It creates the tenant's database and user, so it must never be handed to a tenant."
}

variable "langfuse_clickhouse_admin_secret_name" {
  type    = string
  default = "clickhouse-admin"
  # The `admin_secret` output of modules/ai/clickhouse names it. Mounting the Secret keeps the
  # administrative password out of the building block definition entirely.
  description = "Name of the Kubernetes Secret in the ClickHouse namespace that holds the administrative password. The DDL Job reads the password from it instead of taking it as an input."
}

variable "langfuse_clickhouse_admin_secret_key" {
  type        = string
  default     = "password"
  description = "Key inside the administrative Secret that holds the password."
}

variable "langfuse_clickhouse_client_image" {
  type    = string
  default = "clickhouse/clickhouse-server:26.4"
  # The same image the servers run, so the node has it in its cache and no second image is pulled.
  # Keep the tag on the `clickhouse_version` of modules/ai/clickhouse.
  description = "Image the DDL Job runs `clickhouse-client` from. Keep it on the same tag the shared cluster runs, so no second image has to be pulled."
}

variable "langfuse_clickhouse_ddl_timeout" {
  type    = number
  default = 600
  # Bounds both Jobs. Without a deadline a ClickHouse that never answers turns into a Terraform
  # timeout with no log instead of a failed Job with one.
  description = "Seconds each ClickHouse DDL Job may run before Kubernetes fails it. It covers waiting for the cluster to answer a query and running the statements."

  validation {
    condition     = var.langfuse_clickhouse_ddl_timeout >= 30
    error_message = "langfuse_clickhouse_ddl_timeout must be at least 30 seconds."
  }
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

# The endpoint of the object storage and the credential scoped to the tenant's bucket are not inputs.
# The bucket submodule creates a credentials group and a credential per bucket and reports both, so
# the tenant's Langfuse instance gets a credential that its own bucket policy scopes to its own
# bucket.

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
