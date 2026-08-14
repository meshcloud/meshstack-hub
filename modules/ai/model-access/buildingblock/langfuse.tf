# The tenant's own Langfuse instance. `modules/ai/langfuse` declares no providers of its own, so it
# is configured with the AI platform cluster's provider aliases from here.

# Three secrets have to differ per tenant, or the isolation between the instances is defeated: the
# salt hashes the tenant's API keys, the encryption key encrypts its stored credentials at rest, and
# the NextAuth secret signs its session tokens. They are generated here rather than taken as inputs,
# because a STATIC input is the same value for every tenant.
resource "random_password" "langfuse_salt" {
  length = 32
  # The value travels into a Kubernetes Secret and into an environment variable, so it is kept to
  # letters and digits.
  special = false
}

resource "random_password" "langfuse_nextauth_secret" {
  length  = 32
  special = false
}

# random_bytes rather than random_id: both produce hex, but only random_bytes marks it sensitive, so
# the key stays out of the plan. Langfuse wants 256 bits, which is 32 bytes and 64 hex characters.
resource "random_bytes" "langfuse_encryption_key" {
  length = 32
}

# Langfuse accepts a predefined API keypair at bootstrap, so the keys are generated here instead of
# a human reading them out of a UI.
resource "random_uuid" "langfuse_project_public_key" {}

# The secret half comes from random_bytes for the same reason as the encryption key: random_uuid is
# not marked sensitive.
resource "random_bytes" "langfuse_project_secret_key" {
  length = 16
}

locals {
  langfuse_project_public_key = "pk-lf-${random_uuid.langfuse_project_public_key.result}"

  # Langfuse's own generator produces 'sk-lf-<uuid>', and the 16 random bytes are formatted into that
  # shape so nothing downstream has to accept a second one.
  langfuse_secret_key_hex = random_bytes.langfuse_project_secret_key.hex
  langfuse_project_secret_key = format("sk-lf-%s-%s-%s-%s-%s",
    substr(local.langfuse_secret_key_hex, 0, 8),
    substr(local.langfuse_secret_key_hex, 8, 4),
    substr(local.langfuse_secret_key_hex, 12, 4),
    substr(local.langfuse_secret_key_hex, 16, 4),
    substr(local.langfuse_secret_key_hex, 20, 12),
  )
}

module "langfuse" {
  source = "github.com/meshcloud/meshstack-hub//modules/ai/langfuse/buildingblock?ref=${var.hub.git_ref}"

  providers = {
    kubernetes = kubernetes.ai_platform
    helm       = helm.ai_platform
  }

  # Langfuse creates tables inside its databases and objects inside its bucket, never the databases or
  # the bucket themselves, and every web pod runs both sets of migrations before it answers its
  # readiness probe. The release is installed with `wait`, so an instance that starts before its
  # backends exist does not merely warn: it crash-loops through its migrations and fails the apply.
  #
  # The Postgres and the bucket dependency are already carried by the values below. The ClickHouse
  # dependency is not: the tenant's ClickHouse credentials are generated in this run rather than read
  # out of the DDL release, so the ordering has to be stated.
  depends_on = [helm_release.clickhouse_ddl]

  namespace = local.langfuse_namespace
  hostname  = local.langfuse_hostname

  ingress_class_name = var.langfuse_ingress_class_name

  # The chart version and the Langfuse image tag are not inputs. They come from the version of
  # `modules/ai/langfuse` that `var.hub.git_ref` selects, so an upgrade is a hub reference bump and a
  # new building block definition version, not a value somebody edits on a live definition.

  salt            = random_password.langfuse_salt.result
  encryption_key  = random_bytes.langfuse_encryption_key.hex
  nextauth_secret = random_password.langfuse_nextauth_secret.result

  # The database, the owner user and its password come out of the module that created them, so the name
  # Langfuse connects to cannot drift away from the name that exists. The host and the port come from
  # the same place, because the submodule reads them off the shared instance.
  postgres_host     = module.postgres.host
  postgres_port     = module.postgres.port
  postgres_database = module.postgres.database_name
  postgres_username = module.postgres.username
  postgres_password = module.postgres.password

  # DIRECT_URL, the connection the Prisma migrations run over. `postgres_connection_limit` and
  # `postgres_direct_url_connection_limit` are deliberately left at the defaults of
  # `modules/ai/langfuse`, which pin the pool of a pod to 5 connections and the pool of a migration to
  # 2: the shared instance has a fixed `max_connections` and every pod of every tenant draws from it.
  # The value below carries no `connection_limit` of its own — the submodule puts `sslmode=require` on
  # it and nothing else — and `modules/ai/langfuse` rejects one that does, because two occurrences in
  # one query string leave the effective pool size to the parser.
  postgres_direct_url = module.postgres.direct_connection_string

  clickhouse_host        = var.langfuse_clickhouse_host
  clickhouse_native_port = var.langfuse_clickhouse_native_port
  clickhouse_database    = local.langfuse_clickhouse_database
  clickhouse_username    = local.langfuse_clickhouse_username
  clickhouse_password    = random_password.langfuse_clickhouse.result

  valkey_host       = var.langfuse_valkey_host
  valkey_password   = var.langfuse_valkey_password
  valkey_database   = local.langfuse_valkey_database
  valkey_key_prefix = local.langfuse_valkey_key_prefix

  # The bucket, its endpoint and a credential the bucket policy scopes to this bucket alone, all from
  # the module that created them.
  s3_bucket            = module.bucket.bucket_name
  s3_region            = module.bucket.region
  s3_endpoint          = module.bucket.endpoint
  s3_access_key_id     = module.bucket.s3_access_key
  s3_secret_access_key = module.bucket.s3_secret_access_key

  init_org_id             = local.langfuse_org_id
  init_org_name           = local.langfuse_org_name
  init_project_id         = local.langfuse_project_id
  init_project_name       = local.langfuse_project_name
  init_project_public_key = local.langfuse_project_public_key
  init_project_secret_key = local.langfuse_project_secret_key

  # No initial password user: var.oidc is required, and a user with a password nobody can read would
  # be of no use anyway, because a building block output cannot carry a password.
  oidc             = var.oidc
  default_org_role = var.langfuse_default_org_role
}
