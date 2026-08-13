locals {
  # The chart names the Service after the release: '<release>-litellm', or just '<release>' when
  # the release name already contains the chart's nameOverride, which is 'litellm'.
  service_name = strcontains(var.release_name, "litellm") ? var.release_name : "${var.release_name}-litellm"

  # Pinned here rather than left to the chart default, so the api_base output cannot drift away
  # from the port the Service actually listens on.
  service_port = 4000

  # Every credential reaches the pods as an environment variable, and the proxy config refers to it
  # as os.environ/<NAME>. Characters an environment variable name cannot carry collapse into an
  # underscore; variables.tf rejects two aliases that would collapse to the same name.
  api_key_env_names = {
    for alias in keys(var.model_backends) :
    alias => "LITELLM_API_KEY_${upper(replace(alias, "/[^a-zA-Z0-9]/", "_"))}"
  }

  # Prisma sizes its connection pool as `num_physical_cpus * 2 + 1` when the connection URL carries
  # no connection_limit, and it counts the physical cores of the node instead of the pod's CPU
  # limit. prisma-engines#4341 records that as an oversight and was closed without a fix, so a pod
  # with a 100m limit takes 33 connections on a 16-core node and a different number after it is
  # rescheduled. A managed Postgres caps max_connections by its flavour, so the pool is pinned here.
  postgres_url_query = join("&", [
    "sslmode=${var.postgres_ssl_mode}",
    "connection_limit=${var.postgres_connection_limit}",
  ])

  redis_enabled = var.redis_host != null

  # Whether a Redis password was given is a plain fact, while the password itself is a secret. The
  # fact has to stay unmarked, because everything derived from a marked value carries the mark, and
  # the chart values would then be hidden in full from every plan. nonsensitive() rejects an
  # argument that carries no mark, so try() falls back to the bare comparison.
  redis_password_set = local.redis_enabled ? try(nonsensitive(var.redis_password != null), var.redis_password != null) : false

  redis_env = local.redis_enabled ? merge(
    {
      REDIS_HOST = var.redis_host
      REDIS_PORT = tostring(var.redis_port)
    },
    local.redis_password_set ? { REDIS_PASSWORD = var.redis_password } : {}
  ) : {}

  # The proxy reads its coordination store from general_settings.coordination_redis. The chart only
  # renders that block for its own bundled Redis, so an external Redis is written out here. A block
  # supplied in proxy_config always wins over the chart's own.
  coordination_redis = local.redis_enabled ? {
    coordination_redis = merge(
      {
        host = "os.environ/REDIS_HOST"
        port = "os.environ/REDIS_PORT"
      },
      local.redis_password_set ? { password = "os.environ/REDIS_PASSWORD" } : {}
    )
  } : {}

  chart_values = {
    replicaCount = var.replica_count

    service = {
      type = "ClusterIP"
      port = local.service_port
    }

    # Without this the chart generates a master key of its own on every install, which no caller
    # knows and which changes whenever the secret is recreated.
    masterkeySecretName = kubernetes_secret_v1.master_key.metadata[0].name
    masterkeySecretKey  = "masterkey"

    # Exports the secret into the pods as environment variables, which is what the
    # os.environ/<NAME> references in proxy_config resolve against.
    environmentSecrets = [kubernetes_secret_v1.model_credentials.metadata[0].name]

    db = {
      # The chart bundles a Bitnami postgresql subchart and turns it on by default. Those images
      # no longer receive updates and the subchart pins bitnamilegacy/postgresql, so the database
      # comes from outside the chart.
      deployStandalone = false
      useExisting      = true

      endpoint = var.postgres_host
      database = var.postgres_database

      # Kubernetes substitutes $(VAR) from the environment variables declared before this one in
      # the same container, so the credentials stay in the secret and never appear in the pod spec.
      # The chart's default URL carries no port, hence the override.
      url = "postgresql://$(DATABASE_USERNAME):$(DATABASE_PASSWORD)@$(DATABASE_HOST):${var.postgres_port}/$(DATABASE_NAME)?${local.postgres_url_query}"

      secret = {
        name        = kubernetes_secret_v1.postgres.metadata[0].name
        usernameKey = "username"
        passwordKey = "password"
      }
    }

    # The bundled Redis subchart carries the same retired Bitnami images as the Postgres one, so it
    # stays off. An external Redis arrives through REDIS_HOST, REDIS_PORT and REDIS_PASSWORD.
    redis = {
      enabled = false
    }

    migrationJob = {
      enabled = true
      hooks = {
        # As a Helm pre-install and pre-upgrade hook the Job runs to completion before the
        # Deployment is created, so the pods never start against a database without the schema.
        # The chart's default instead annotates the Job for ArgoCD, which means nothing here.
        helm   = { enabled = true }
        argocd = { enabled = false }
      }
    }

    proxy_config = {
      model_list = [
        for alias, backend in var.model_backends : {
          model_name = alias
          litellm_params = {
            # The 'openai/' prefix selects the OpenAI-compatible driver.
            model = "openai/${backend.model}"
            # api_base carries the '/v1' suffix; variables.tf rejects an endpoint without it.
            api_base = backend.api_base
            api_key  = "os.environ/${local.api_key_env_names[alias]}"
          }
        }
      ]

      general_settings = merge(
        {
          master_key = "os.environ/PROXY_MASTER_KEY"

          # The proxy rewrites DATABASE_URL on startup and replaces connection_limit with this
          # setting, so the parameter on db.url alone does not bind the running pods. Both carry
          # the same number, and the pool is then the same on whichever path sets it.
          database_connection_pool_limit = var.postgres_connection_limit
        },
        local.coordination_redis
      )
    }
  }
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret_v1" "master_key" {
  metadata {
    name      = "${var.release_name}-master-key"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  data = {
    masterkey = var.master_key
  }
}

resource "kubernetes_secret_v1" "postgres" {
  metadata {
    name      = "${var.release_name}-postgres"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  data = {
    username = var.postgres_username
    password = var.postgres_password
  }
}

resource "kubernetes_secret_v1" "model_credentials" {
  metadata {
    name      = "${var.release_name}-model-credentials"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  data = merge(
    {
      for alias, env_name in local.api_key_env_names :
      env_name => var.model_backend_api_keys[alias]
    },
    local.redis_env
  )
}

# The chart is published to GHCR as an OCI artifact and has no classic Helm repository. The helm
# provider takes the registry and the path prefix as the repository, and the chart name on its own
# as the chart, so the reference resolves to oci://ghcr.io/berriai/litellm-helm.
resource "helm_release" "litellm" {
  name       = var.release_name
  namespace  = kubernetes_namespace_v1.this.metadata[0].name
  repository = "oci://ghcr.io/berriai"
  chart      = "litellm-helm"
  version    = var.chart_version

  create_namespace = false
  atomic           = true
  wait             = true
  timeout          = var.helm_timeout

  values = [yamlencode(local.chart_values)]
}
