locals {
  # The chart names its resources '<release>-langfuse-…', or '<release>-…' when the release name
  # already contains the chart's name, which is 'langfuse'.
  fullname         = strcontains(var.release_name, "langfuse") ? var.release_name : "${var.release_name}-langfuse"
  web_service_name = "${local.fullname}-web"

  # Pinned here rather than left to the chart default, so the outputs cannot drift away from the
  # port the Service actually listens on.
  web_service_port = 3000

  web_service_host = "${local.web_service_name}.${var.namespace}.svc.cluster.local"
  base_url         = "http://${local.web_service_host}:${local.web_service_port}"

  public_url = coalesce(var.public_url, "https://${var.hostname}")

  # Langfuse never reads DATABASE_PORT. Both entrypoints build the connection URL as
  # postgresql://<user>:<password>@$DATABASE_HOST/<database>, so a port that is not folded into the
  # host is simply lost and the connection goes to 5432.
  postgres_host_with_port = "${var.postgres_host}:${var.postgres_port}"

  secret_name = "${var.release_name}-langfuse"

  secret_keys = {
    salt                    = "salt"
    encryption_key          = "encryption-key"
    nextauth_secret         = "nextauth-secret"
    postgres_password       = "postgres-password"
    clickhouse_password     = "clickhouse-password"
    valkey_password         = "valkey-password"
    s3_access_key_id        = "s3-access-key-id"
    s3_secret_access_key    = "s3-secret-access-key"
    postgres_direct_url     = "postgres-direct-url"
    init_project_secret_key = "init-project-secret-key"
    init_user_password      = "init-user-password"
    oidc_client_secret      = "oidc-client-secret"
  }

  # var.oidc is sensitive as a whole, so every expression derived from it carries the sensitivity
  # mark, and a values map that carries the mark hides the whole Helm release from every plan.
  # Unmark the plain facts — is SSO on, which issuer, which client — while the client secret keeps
  # its mark and reaches the pods through a secretKeyRef. nonsensitive() rejects an argument that
  # carries no mark, so try() falls back to the bare value.
  oidc_enabled = try(nonsensitive(var.oidc != null), var.oidc != null)
  oidc = local.oidc_enabled ? {
    issuer_url            = try(nonsensitive(var.oidc.issuer_url), var.oidc.issuer_url)
    client_id             = try(nonsensitive(var.oidc.client_id), var.oidc.client_id)
    display_name          = try(nonsensitive(var.oidc.display_name), var.oidc.display_name)
    scopes                = try(nonsensitive(var.oidc.scopes), var.oidc.scopes)
    allow_account_linking = try(nonsensitive(var.oidc.allow_account_linking), var.oidc.allow_account_linking)
  } : null

  disable_username_password = coalesce(var.disable_username_password, local.oidc_enabled)

  init_user_enabled = var.init_user_email != null

  # Whether a direct URL was given is a plain fact, while the URL itself is a secret. The fact has
  # to stay unmarked, because everything derived from a marked value carries the mark and the
  # whole chart values map would then be hidden from every plan.
  postgres_direct_url_set = try(nonsensitive(var.postgres_direct_url != null), var.postgres_direct_url != null)

  # Helm renders these values into the pod spec as YAML, and the API server rejects a resource
  # quantity that is null, so drop every field the caller left unset.
  resources = {
    for name, spec in {
      web    = var.web_resources
      worker = var.worker_resources
      } : name => {
      requests = { for key, value in spec.requests : key => value if value != null }
      limits   = { for key, value in spec.limits : key => value if value != null }
    }
  }

  # Node sizes its old space from the host's memory, not from the cgroup limit, so without this
  # flag the heap grows past the container limit and the kernel kills the pod instead of the
  # garbage collector running. 75% of the limit leaves room for the rest of the process.
  node_heap_mib = {
    for name, limit in {
      web    = var.web_resources.limits.memory
      worker = var.worker_resources.limits.memory
      } : name => (
      limit == null ? null :
      can(regex("^[0-9]+Gi$", limit)) ? floor(tonumber(trimsuffix(limit, "Gi")) * 1024 * 0.75) :
      can(regex("^[0-9]+Mi$", limit)) ? floor(tonumber(trimsuffix(limit, "Mi")) * 0.75) :
      null
    )
  }

  node_options_env = {
    for name, heap in local.node_heap_mib :
    name => heap == null ? [] : [{ name = "NODE_OPTIONS", value = "--max-old-space-size=${heap}" }]
  }

  # REDIS_KEY_PREFIX is not exposed by the chart — it appears nowhere in _helpers.tpl — so it has
  # to travel through additionalEnv. Without it every tenant's worker reads the same BullMQ queue
  # names, because those names are hardcoded in the application.
  valkey_env = [
    { name = "REDIS_KEY_PREFIX", value = var.valkey_key_prefix }
  ]

  # The chart writes postgresql.directUrl into the pod spec as a plain value, and a connection URL
  # carries the password. Every other credential in this module travels through a secretKeyRef, so
  # this one does too: the chart value stays unset and the environment variable comes from the
  # tenant secret instead.
  postgres_direct_url_env = local.postgres_direct_url_set ? [
    {
      name = "DIRECT_URL"
      valueFrom = {
        secretKeyRef = {
          name = local.secret_name
          key  = local.secret_keys.postgres_direct_url
        }
      }
    },
  ] : []

  # LANGFUSE_INIT_* is not gated behind an entitlement. Langfuse upserts the organisation, the
  # project, the API keypair and, optionally, a user with OWNER membership, and it accepts a
  # predefined keypair, so Terraform generates the keys instead of a human reading them out of a
  # UI. LANGFUSE_INIT_ORG_ID is the trigger: with it unset the rest is silently ignored.
  #
  # Each conditional below carries exactly one element, because a conditional whose branches are
  # tuples of different length cannot be type-checked unless both sides unify to the same list
  # type — and an entry with `value` and an entry with `valueFrom` are different object types.
  init_env = concat(
    [
      { name = "LANGFUSE_INIT_ORG_ID", value = var.init_org_id },
      { name = "LANGFUSE_INIT_ORG_NAME", value = var.init_org_name },
      { name = "LANGFUSE_INIT_PROJECT_ID", value = var.init_project_id },
      { name = "LANGFUSE_INIT_PROJECT_NAME", value = var.init_project_name },
      { name = "LANGFUSE_INIT_PROJECT_PUBLIC_KEY", value = var.init_project_public_key },
      {
        name = "LANGFUSE_INIT_PROJECT_SECRET_KEY"
        valueFrom = {
          secretKeyRef = {
            name = local.secret_name
            key  = local.secret_keys.init_project_secret_key
          }
        }
      },
    ],
    local.init_user_enabled ? [
      { name = "LANGFUSE_INIT_USER_EMAIL", value = var.init_user_email },
    ] : [],
    local.init_user_enabled ? [
      {
        name = "LANGFUSE_INIT_USER_PASSWORD"
        valueFrom = {
          secretKeyRef = {
            name = local.secret_name
            key  = local.secret_keys.init_user_password
          }
        }
      },
    ] : [],
    local.init_user_enabled && var.init_user_name != null ? [
      { name = "LANGFUSE_INIT_USER_NAME", value = var.init_user_name },
    ] : []
  )

  # Langfuse upserts an organisation membership for every user who logs in, with this role, and
  # the upsert never overwrites a role the user already has. There is no entitlement check on that
  # path, so this replaces member synchronisation entirely: no group mapping, no SCIM.
  default_org_env = [
    { name = "LANGFUSE_DEFAULT_ORG_ID", value = var.init_org_id },
    { name = "LANGFUSE_DEFAULT_ORG_ROLE", value = var.default_org_role },
  ]

  chart_values = {
    langfuse = {
      # The chart's appVersion is still a v3 release, so the tag override is what selects v4.
      image = {
        tag = var.image_tag
      }

      replicas = var.web_replicas

      features = {
        telemetryEnabled = var.telemetry_enabled

        # This stays false on purpose. AUTH_DISABLE_SIGNUP is checked inside the NextAuth
        # adapter's createUser, and an SSO login of a user who is not in the database yet goes
        # through exactly that path. Turning sign-up off therefore blocks the first login of every
        # SSO user on a freshly provisioned instance, which is all of them.
        #
        # Who may log in is decided at the identity provider, by assigning only this tenant's
        # members to this tenant's OIDC client. The control inside Langfuse is
        # auth.disableUsernamePassword below, not this flag. Do not "harden" it back to true.
        signUpDisabled = false

        experimentalFeaturesEnabled = false
      }

      auth = merge(
        {
          disableUsernamePassword = local.disable_username_password
        },
        # The chart turns every key under a provider into AUTH_<PROVIDER>_<KEY>, and 'custom' is
        # the generic OIDC provider Langfuse builds from AUTH_CUSTOM_ISSUER by discovery. Its
        # callback path is /api/auth/callback/custom.
        local.oidc_enabled ? {
          providers = {
            custom = {
              issuer   = local.oidc.issuer_url
              clientId = local.oidc.client_id
              clientSecret = {
                secretKeyRef = {
                  name = local.secret_name
                  key  = local.secret_keys.oidc_client_secret
                }
              }
              name                = local.oidc.display_name
              scope               = local.oidc.scopes
              allowAccountLinking = local.oidc.allow_account_linking
            }
          }
        } : {}
      )

      salt = {
        secretKeyRef = {
          name = local.secret_name
          key  = local.secret_keys.salt
        }
      }

      encryptionKey = {
        secretKeyRef = {
          name = local.secret_name
          key  = local.secret_keys.encryption_key
        }
      }

      nextauth = {
        # The chart default is http://localhost:3000, which every OAuth callback and every link in
        # an invitation mail would then point at.
        url = local.public_url
        secret = {
          secretKeyRef = {
            name = local.secret_name
            key  = local.secret_keys.nextauth_secret
          }
        }
      }

      ingress = {
        enabled     = var.ingress_enabled
        className   = var.ingress_class_name
        annotations = var.ingress_annotations
        hosts = [
          {
            host  = var.hostname
            paths = [{ path = "/", pathType = "Prefix" }]
          }
        ]
        tls = {
          # Without a secret of its own the Ingress carries no tls block, and the ingress
          # controller serves its default wildcard certificate for this host.
          enabled    = var.ingress_tls_secret_name != null
          secretName = var.ingress_tls_secret_name
        }
      }

      additionalEnv = concat(
        local.valkey_env,
        local.postgres_direct_url_env,
        local.init_env,
        local.default_org_env
      )

      web = {
        replicas  = var.web_replicas
        resources = local.resources.web
        pod = {
          additionalEnv = local.node_options_env.web
        }
      }

      worker = {
        replicas  = var.worker_replicas
        resources = local.resources.worker
        pod = {
          additionalEnv = local.node_options_env.worker
        }
      }
    }

    # Every 'deploy' flag below is a placement switch, not a feature switch. Turning one off does
    # not make Langfuse run without that backend — it only says the backend lives outside the
    # chart. All four are mandatory.
    postgresql = {
      deploy = false

      # The port is part of the host, see the comment on local.postgres_host_with_port.
      host = local.postgres_host_with_port
      args = var.postgres_args

      auth = {
        username       = var.postgres_username
        database       = var.postgres_database
        existingSecret = local.secret_name
        secretKeys = {
          userPasswordKey  = local.secret_keys.postgres_password
          adminPasswordKey = local.secret_keys.postgres_password
        }
      }

      # directUrl stays unset here — the module injects DIRECT_URL through additionalEnv with a
      # secretKeyRef instead, see local.postgres_direct_url_env.

      migration = {
        autoMigrate = var.postgres_auto_migrate
      }
    }

    redis = {
      deploy = false

      host = var.valkey_host
      port = var.valkey_port

      auth = {
        username = var.valkey_username
        # The DB index becomes the path of the connection URL. It is a hard namespace: a
        # connection that selected index n cannot reach a key in another index at all.
        database                  = var.valkey_database
        existingSecret            = local.secret_name
        existingSecretPasswordKey = local.secret_keys.valkey_password
      }
    }

    clickhouse = {
      deploy = false

      host       = var.clickhouse_host
      httpPort   = var.clickhouse_http_port
      nativePort = var.clickhouse_native_port
      database   = var.clickhouse_database

      auth = {
        username          = var.clickhouse_username
        existingSecret    = local.secret_name
        existingSecretKey = local.secret_keys.clickhouse_password
      }

      # The operator-managed cluster is a real cluster named 'default' even with one replica, so
      # the ON CLUSTER statements of the migrations work.
      clusterEnabled = var.clickhouse_cluster_enabled

      migration = {
        autoMigrate = var.clickhouse_auto_migrate
      }
    }

    s3 = {
      deploy = false

      storageProvider = "s3"

      bucket         = var.s3_bucket
      region         = var.s3_region
      endpoint       = var.s3_endpoint
      forcePathStyle = var.s3_force_path_style

      accessKeyId = {
        secretKeyRef = {
          name = local.secret_name
          key  = local.secret_keys.s3_access_key_id
        }
      }
      secretAccessKey = {
        secretKeyRef = {
          name = local.secret_name
          key  = local.secret_keys.s3_secret_access_key
        }
      }

      # The three upload kinds share the tenant's bucket and separate by prefix. Each one is set
      # out in full rather than left to the shared values above, so a caller can move a single
      # kind to another bucket without rewriting the module.
      eventUpload = local.s3_use.eventUpload
      batchExport = merge({ enabled = true }, local.s3_use.batchExport)
      mediaUpload = merge({ enabled = true }, local.s3_use.mediaUpload)
    }
  }

  s3_credentials = {
    accessKeyId = {
      secretKeyRef = {
        name = local.secret_name
        key  = local.secret_keys.s3_access_key_id
      }
    }
    secretAccessKey = {
      secretKeyRef = {
        name = local.secret_name
        key  = local.secret_keys.s3_secret_access_key
      }
    }
  }

  s3_use = {
    for name, prefix in {
      eventUpload = var.s3_event_upload_prefix
      batchExport = var.s3_batch_export_prefix
      mediaUpload = var.s3_media_upload_prefix
      } : name => merge(
      {
        bucket         = var.s3_bucket
        prefix         = prefix
        region         = var.s3_region
        endpoint       = var.s3_endpoint
        forcePathStyle = var.s3_force_path_style
      },
      local.s3_credentials
    )
  }
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
  }
}

# One secret per tenant holds every credential the chart references. Nothing sensitive reaches the
# Helm values, so the rendered release stays readable in a plan.
resource "kubernetes_secret_v1" "this" {
  metadata {
    name      = local.secret_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  data = merge(
    {
      (local.secret_keys.salt)                    = var.salt
      (local.secret_keys.encryption_key)          = var.encryption_key
      (local.secret_keys.nextauth_secret)         = var.nextauth_secret
      (local.secret_keys.postgres_password)       = var.postgres_password
      (local.secret_keys.clickhouse_password)     = var.clickhouse_password
      (local.secret_keys.valkey_password)         = var.valkey_password
      (local.secret_keys.s3_access_key_id)        = var.s3_access_key_id
      (local.secret_keys.s3_secret_access_key)    = var.s3_secret_access_key
      (local.secret_keys.init_project_secret_key) = var.init_project_secret_key
    },
    local.postgres_direct_url_set ? {
      (local.secret_keys.postgres_direct_url) = var.postgres_direct_url
    } : {},
    local.init_user_enabled ? {
      (local.secret_keys.init_user_password) = var.init_user_password
    } : {},
    local.oidc_enabled ? {
      (local.secret_keys.oidc_client_secret) = var.oidc.client_secret
    } : {}
  )
}

# The chart is published to a classic Helm repository, not to an OCI registry, so the repository
# URL and the chart name are given separately.
resource "helm_release" "langfuse" {
  name       = var.release_name
  namespace  = kubernetes_namespace_v1.this.metadata[0].name
  repository = "https://langfuse.github.io/langfuse-k8s"
  chart      = "langfuse"
  version    = var.chart_version

  create_namespace = false
  atomic           = true
  wait             = true
  timeout          = var.helm_timeout

  values = [yamlencode(local.chart_values)]
}
