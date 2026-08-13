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

  # var.oidc is sensitive as a whole, so every expression derived from it carries the sensitivity
  # mark, and a values map that carries the mark hides the whole Helm release from every plan.
  # Unmark the plain facts — is SSO on, which issuer, which client, which endpoints — while the
  # client secret keeps its mark and reaches the pods through a secret. nonsensitive() rejects an
  # argument that carries no mark, so try() falls back to the bare value.
  oidc_enabled = try(nonsensitive(var.oidc != null), var.oidc != null)
  oidc = local.oidc_enabled ? {
    issuer_url                  = try(nonsensitive(var.oidc.issuer_url), var.oidc.issuer_url)
    client_id                   = try(nonsensitive(var.oidc.client_id), var.oidc.client_id)
    scopes                      = try(nonsensitive(var.oidc.scopes), var.oidc.scopes)
    authorization_endpoint      = try(nonsensitive(var.oidc.authorization_endpoint), var.oidc.authorization_endpoint)
    token_endpoint              = try(nonsensitive(var.oidc.token_endpoint), var.oidc.token_endpoint)
    userinfo_endpoint           = try(nonsensitive(var.oidc.userinfo_endpoint), var.oidc.userinfo_endpoint)
    user_id_attribute           = try(nonsensitive(var.oidc.user_id_attribute), var.oidc.user_id_attribute)
    user_email_attribute        = try(nonsensitive(var.oidc.user_email_attribute), var.oidc.user_email_attribute)
    user_display_name_attribute = try(nonsensitive(var.oidc.user_display_name_attribute), var.oidc.user_display_name_attribute)
    user_role_attribute         = try(nonsensitive(var.oidc.user_role_attribute), var.oidc.user_role_attribute)
    allowed_email_domains       = try(nonsensitive(var.oidc.allowed_email_domains), var.oidc.allowed_email_domains)
    proxy_admin_id              = try(nonsensitive(var.oidc.proxy_admin_id), var.oidc.proxy_admin_id)
    logout_url                  = try(nonsensitive(var.oidc.logout_url), var.oidc.logout_url)
    auto_redirect_to_sso        = try(nonsensitive(var.oidc.auto_redirect_to_sso), var.oidc.auto_redirect_to_sso)
  } : null

  # The proxy reads the three endpoints as separate environment variables and performs no discovery
  # of its own, while the caller supplies an issuer. The gap is closed here, with the discovery
  # document read at plan time. A caller who overrides all three endpoints skips the request
  # entirely, which is the way out when the provider is unreachable from the Terraform runner.
  oidc_endpoint_overrides = local.oidc_enabled ? {
    authorization_endpoint = local.oidc.authorization_endpoint
    token_endpoint         = local.oidc.token_endpoint
    userinfo_endpoint      = local.oidc.userinfo_endpoint
  } : {}

  oidc_discovery_needed = local.oidc_enabled && anytrue([
    for endpoint in values(local.oidc_endpoint_overrides) : endpoint == null
  ])

  oidc_discovery = local.oidc_discovery_needed ? jsondecode(data.http.oidc_discovery[0].response_body) : {}

  oidc_endpoints = {
    for name, override in local.oidc_endpoint_overrides :
    name => coalesce(override, try(local.oidc_discovery[name], null))
  }

  # Every value here is a plain string in the pod spec, so the client secret is not among them.
  # A null entry is dropped, which leaves the proxy on its own default for that setting.
  oidc_env = local.oidc_enabled ? {
    for name, value in {
      GENERIC_CLIENT_ID              = local.oidc.client_id
      GENERIC_AUTHORIZATION_ENDPOINT = local.oidc_endpoints.authorization_endpoint
      GENERIC_TOKEN_ENDPOINT         = local.oidc_endpoints.token_endpoint
      GENERIC_USERINFO_ENDPOINT      = local.oidc_endpoints.userinfo_endpoint
      GENERIC_SCOPE                  = local.oidc.scopes

      GENERIC_USER_ID_ATTRIBUTE           = local.oidc.user_id_attribute
      GENERIC_USER_EMAIL_ATTRIBUTE        = local.oidc.user_email_attribute
      GENERIC_USER_DISPLAY_NAME_ATTRIBUTE = local.oidc.user_display_name_attribute
      GENERIC_USER_ROLE_ATTRIBUTE         = local.oidc.user_role_attribute

      PROXY_BASE_URL                = var.public_url
      PROXY_LOGOUT_URL              = local.oidc.logout_url
      PROXY_ADMIN_ID                = local.oidc.proxy_admin_id
      ALLOWED_EMAIL_DOMAINS         = local.oidc.allowed_email_domains == null ? null : join(",", local.oidc.allowed_email_domains)
      AUTO_REDIRECT_UI_LOGIN_TO_SSO = local.oidc.auto_redirect_to_sso ? "true" : null
    } : name => value if value != null
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

    # Exports the secrets into the pods as environment variables, which is what the
    # os.environ/<NAME> references in proxy_config resolve against.
    environmentSecrets = concat(
      [kubernetes_secret_v1.model_credentials.metadata[0].name],
      [for secret in kubernetes_secret_v1.oidc : secret.metadata[0].name],
    )

    # The chart renders these as plain `env` entries on the container. The proxy reads its SSO
    # settings from the environment and not from the proxy config, so they belong here rather than
    # under proxy_config.
    envVars = local.oidc_env

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

          # Keeps LiteLLM_UserTable empty, and the console therefore inside the free limit of five
          # users. Without it the first /team/new call writes one row and takes one of the five.
          disable_auto_add_proxy_admin_to_teams = var.disable_auto_add_proxy_admin_to_teams
        },
        local.coordination_redis
      )
    }
  }
}

# The identity provider publishes its authorization, token and userinfo endpoints in this document,
# and the proxy wants all three named individually. Reading it here keeps var.oidc down to an
# issuer and holds the interface identical to modules/ai/langfuse, which discovers the same
# document itself. The request runs on every plan, so the provider has to answer the Terraform
# runner; the three endpoint overrides in var.oidc are the way around that.
data "http" "oidc_discovery" {
  count = local.oidc_discovery_needed ? 1 : 0

  url = "${trimsuffix(local.oidc.issuer_url, "/")}/.well-known/openid-configuration"

  request_headers = {
    Accept = "application/json"
  }

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "The OIDC discovery document did not answer with 200. Check oidc.issuer_url, or set authorization_endpoint, token_endpoint and userinfo_endpoint in var.oidc to skip discovery."
    }

    postcondition {
      condition = alltrue([
        for field in ["authorization_endpoint", "token_endpoint", "userinfo_endpoint"] :
        try(jsondecode(self.response_body)[field], null) != null
      ])
      error_message = "The OIDC discovery document names no authorization_endpoint, token_endpoint or userinfo_endpoint. Set the missing ones in var.oidc."
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

# The client secret is the only sensitive part of the SSO configuration, so it travels the same way
# as the model credentials: a secret listed under environmentSecrets, which the chart exports into
# the pods with envFrom. Everything else about the provider stays a plain value in the pod spec.
resource "kubernetes_secret_v1" "oidc" {
  count = local.oidc_enabled ? 1 : 0

  metadata {
    name      = "${var.release_name}-oidc"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  data = {
    GENERIC_CLIENT_SECRET = var.oidc.client_secret
  }
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
