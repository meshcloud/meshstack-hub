# The tenant's ClickHouse database and the user scoped to it.
#
# ClickHouse has no Terraform resource for this, and it cannot have one here: the shared cluster
# answers on an in-cluster hostname such as
# 'clickhouse-clickhouse-headless.clickhouse.svc.cluster.local', which the meshStack Terraform runner
# cannot resolve, let alone reach. Any provider that spoke the ClickHouse protocol would need a route
# from the runner into the cluster network. The DDL therefore runs inside the cluster, as a Job, with
# the `kubernetes` and `helm` providers this module already configures for the AI platform cluster.
# See the ClickHouse section of the module README for the alternatives that were weighed.
#
# The Job runs in the ClickHouse namespace and not in the tenant's own namespace, for two reasons: the
# administrative password is a Secret in that namespace, and the tenant's namespace does not exist
# yet, because `modules/ai/langfuse` creates it and has to run after this.

locals {
  # Exactly the rights Langfuse uses on its own database, and nothing beyond them. `CREATE DATABASE`
  # is deliberately absent: Langfuse runs its ClickHouse migrations with golang-migrate, which creates
  # tables inside a database that already exists and never creates one, so the grant would only let a
  # tenant create databases outside its own scope.
  langfuse_clickhouse_grants = [
    "SELECT",
    "INSERT",
    "CREATE",
    "DROP TABLE",
    "ALTER UPDATE",
    "ALTER DELETE",
    "ALTER DROP INDEX",
  ]

  clickhouse_ddl_secret_key = "password"
}

# The password of the tenant's ClickHouse user is generated here rather than taken as an input, for
# the same reason the three Langfuse secrets are: a STATIC input is the same value for every tenant,
# and a shared password would let one tenant connect as another.
#
# No special characters. The Langfuse migration script puts the value into a query string without
# encoding it, and the DDL below puts it into a quoted SQL literal.
resource "random_password" "langfuse_clickhouse" {
  length  = 32
  special = false
}

# The DDL Job reads the password from this Secret. It does not travel through the Helm values, because
# the values of a release are stored as they are given and a sensitive value in them would also hide
# the whole rendered release from every plan.
resource "kubernetes_secret_v1" "langfuse_clickhouse_user" {
  provider = kubernetes.ai_platform

  metadata {
    name      = "${local.clickhouse_ddl_name}-user"
    namespace = var.langfuse_clickhouse_namespace

    labels = {
      "app.kubernetes.io/managed-by" = "meshstack"
      "app.kubernetes.io/part-of"    = "ai-model-access"
    }
  }

  type = "Opaque"

  data = {
    (local.clickhouse_ddl_secret_key) = random_password.langfuse_clickhouse.result
  }
}

# Two Jobs in one Helm release, and the release is what makes deletion work. A Helm chart can carry a
# `pre-delete` hook, and `helm uninstall` runs it and waits for it before it removes anything else, so
# the tenant's database and user are dropped when the building block is deleted. Terraform on its own
# cannot do that: it destroys resources, and it has no way to run a Job on the way out.
#
# The chart lives in a directory of this module. `modules/ai/clickhouse` and `modules/kubernetes/ingress`
# use the same pattern for manifests Terraform cannot express.
resource "helm_release" "clickhouse_ddl" {
  provider = helm.ai_platform

  name      = local.clickhouse_ddl_name
  namespace = var.langfuse_clickhouse_namespace
  chart     = "${path.module}/clickhouse-ddl"

  create_namespace = false

  # Helm waits for a hook Job to finish and fails the release when the Job fails, so a failed
  # statement fails the apply instead of passing silently.
  wait = true

  # An install that fails is removed again, so the next apply installs cleanly instead of stopping on
  # a release name that is already taken. It also means a failed first install leaves no half-created
  # database behind: the removal runs the same `pre-delete` hook the deletion does. A failed upgrade
  # rolls back and runs no hook at all.
  atomic = true

  # Above the deadline of the Jobs, so a ClickHouse that never answers produces a failed Job with a
  # log rather than a Helm timeout without one.
  timeout = var.langfuse_clickhouse_ddl_timeout + 120

  # `disable_webhooks` is Helm's `--no-hooks`. It has to stay off: both Jobs of this release are
  # hooks, and with hooks disabled the release would create nothing and delete nothing.
  disable_webhooks = false

  values = [yamlencode({
    clickhouse = {
      host       = var.langfuse_clickhouse_host
      nativePort = var.langfuse_clickhouse_native_port
      ddlCluster = var.langfuse_clickhouse_ddl_cluster_name
      image      = var.langfuse_clickhouse_client_image
    }

    admin = {
      username   = var.langfuse_clickhouse_admin_username
      secretName = var.langfuse_clickhouse_admin_secret_name
      secretKey  = var.langfuse_clickhouse_admin_secret_key
    }

    tenant = {
      database   = local.langfuse_clickhouse_database
      username   = local.langfuse_clickhouse_username
      grants     = local.langfuse_clickhouse_grants
      secretName = kubernetes_secret_v1.langfuse_clickhouse_user.metadata[0].name
      secretKey  = local.clickhouse_ddl_secret_key
    }

    job = {
      timeoutSeconds = var.langfuse_clickhouse_ddl_timeout
    }
  })]
}
