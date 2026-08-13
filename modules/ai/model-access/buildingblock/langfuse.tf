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

  namespace = local.langfuse_namespace
  hostname  = local.langfuse_hostname

  ingress_class_name = var.langfuse_ingress_class_name

  # The chart version and the Langfuse image tag are not inputs. They come from the version of
  # `modules/ai/langfuse` that `var.hub.git_ref` selects, so an upgrade is a hub reference bump and a
  # new building block definition version, not a value somebody edits on a live definition.

  salt            = random_password.langfuse_salt.result
  encryption_key  = random_bytes.langfuse_encryption_key.hex
  nextauth_secret = random_password.langfuse_nextauth_secret.result

  postgres_host     = var.langfuse_postgres_host
  postgres_database = local.langfuse_postgres_database
  postgres_username = var.langfuse_postgres_username
  postgres_password = var.langfuse_postgres_password

  clickhouse_host     = var.langfuse_clickhouse_host
  clickhouse_database = local.langfuse_clickhouse_database
  clickhouse_username = var.langfuse_clickhouse_username
  clickhouse_password = var.langfuse_clickhouse_password

  valkey_host       = var.langfuse_valkey_host
  valkey_password   = var.langfuse_valkey_password
  valkey_database   = local.langfuse_valkey_database
  valkey_key_prefix = local.langfuse_valkey_key_prefix

  s3_bucket            = local.langfuse_bucket
  s3_endpoint          = var.langfuse_s3_endpoint
  s3_access_key_id     = var.langfuse_s3_access_key_id
  s3_secret_access_key = var.langfuse_s3_secret_access_key

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
