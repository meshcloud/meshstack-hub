variables {
  namespace    = "langfuse-acme"
  release_name = "langfuse-acme"
  hostname     = "langfuse-acme.example.com"

  salt            = "0123456789abcdef0123456789abcdef"
  encryption_key  = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  nextauth_secret = "0123456789abcdef0123456789abcdef"

  postgres_host     = "shared.postgresflex.eu01.onstackit.cloud"
  postgres_database = "langfuse_acme"
  postgres_username = "langfuse_acme"
  postgres_password = "langfuse-password"

  clickhouse_host     = "clickhouse-headless.clickhouse.svc.cluster.local"
  clickhouse_database = "langfuse_acme"
  clickhouse_username = "langfuse_acme"
  clickhouse_password = "clickhouse-password"

  valkey_host       = "valkey.valkey.svc.cluster.local"
  valkey_password   = "valkey-password"
  valkey_database   = 3
  valkey_key_prefix = "acme:"

  s3_bucket            = "langfuse-acme"
  s3_endpoint          = "https://object.storage.eu01.onstackit.cloud"
  s3_access_key_id     = "AKIAMOCKACCESSKEY"
  s3_secret_access_key = "mock-secret-access-key"

  init_org_id             = "acme"
  init_org_name           = "ACME"
  init_project_id         = "acme-default"
  init_project_name       = "Default"
  init_project_public_key = "pk-lf-11111111-2222-3333-4444-555555555555"
  init_project_secret_key = "sk-lf-66666666-7777-8888-9999-000000000000"
  init_user_email         = "owner@example.com"
  init_user_password      = "owner-password"
}

mock_provider "kubernetes" {}
mock_provider "helm" {}

run "pins_the_prisma_pool_in_the_connection_arguments" {
  command = plan

  assert {
    # The chart turns postgresql.args into DATABASE_ARGS and the entrypoint appends it to the
    # connection URL after a '?', so the whole string is asserted rather than only the parameter.
    condition     = yamldecode(helm_release.langfuse.values[0]).postgresql.args == "sslmode=require&connection_limit=5"
    error_message = "the rendered postgresql.args must carry sslmode and the pinned connection_limit"
  }

  assert {
    condition     = yamldecode(helm_release.langfuse.values[0]).postgresql.host == "shared.postgresflex.eu01.onstackit.cloud:5432"
    error_message = "the port must stay folded into the host, because Langfuse never reads DATABASE_PORT"
  }
}

run "a_lowered_limit_reaches_the_connection_arguments" {
  command = plan

  variables {
    postgres_connection_limit = 3
    postgres_args             = "sslmode=verify-full&pool_timeout=20"
  }

  assert {
    condition     = yamldecode(helm_release.langfuse.values[0]).postgresql.args == "sslmode=verify-full&pool_timeout=20&connection_limit=3"
    error_message = "the module must append its connection_limit behind the arguments the caller set"
  }
}

run "an_empty_argument_string_leaves_no_stray_separator" {
  command = plan

  variables {
    postgres_args = ""
  }

  assert {
    condition     = yamldecode(helm_release.langfuse.values[0]).postgresql.args == "connection_limit=5"
    error_message = "an empty postgres_args must not produce a query string that starts with '&'"
  }
}

run "the_migration_connection_gets_a_limit_of_its_own" {
  command = plan

  variables {
    postgres_direct_url = "postgresql://langfuse_acme:pa%2Fss@shared.postgresflex.eu01.onstackit.cloud:5432/langfuse_acme?sslmode=require"
  }

  assert {
    # nonsensitive() because the secret carries the password. The URL is asserted in full: the
    # parameter has to land behind the existing query string with '&', and nothing about the
    # percent-encoded password may change.
    condition     = nonsensitive(kubernetes_secret_v1.this.data["postgres-direct-url"]) == "postgresql://langfuse_acme:pa%2Fss@shared.postgresflex.eu01.onstackit.cloud:5432/langfuse_acme?sslmode=require&connection_limit=2"
    error_message = "DIRECT_URL must keep its query string and gain the smaller migration limit"
  }

  assert {
    # The URL stays in the secret and reaches the pods through a secretKeyRef, never through
    # postgresql.directUrl, which the chart would render into the pod spec in plain text.
    condition = anytrue([
      for env in yamldecode(helm_release.langfuse.values[0]).langfuse.additionalEnv :
      env.name == "DIRECT_URL" && try(env.valueFrom.secretKeyRef.key, null) == "postgres-direct-url"
    ])
    error_message = "DIRECT_URL must reach the pods through a secretKeyRef"
  }

  assert {
    condition     = !can(yamldecode(helm_release.langfuse.values[0]).postgresql.directUrl)
    error_message = "postgresql.directUrl must stay unset, otherwise the password lands in the pod spec"
  }
}

run "a_migration_url_without_a_query_string_gets_a_question_mark" {
  command = plan

  variables {
    postgres_direct_url                  = "postgresql://langfuse_acme:secret@shared.postgresflex.eu01.onstackit.cloud:5432/langfuse_acme"
    postgres_direct_url_connection_limit = 1
  }

  assert {
    condition     = nonsensitive(kubernetes_secret_v1.this.data["postgres-direct-url"]) == "postgresql://langfuse_acme:secret@shared.postgresflex.eu01.onstackit.cloud:5432/langfuse_acme?connection_limit=1"
    error_message = "a migration URL without a query string must gain one with '?', not with '&'"
  }
}

run "no_migration_url_leaves_the_secret_key_out" {
  command = plan

  assert {
    condition     = !contains(keys(nonsensitive(kubernetes_secret_v1.this.data)), "postgres-direct-url")
    error_message = "without postgres_direct_url the secret must carry no migration URL, so the migrations reuse DATABASE_URL and its pinned pool"
  }
}

run "rejects_a_connection_limit_in_the_argument_string" {
  command = plan

  variables {
    postgres_args = "sslmode=require&connection_limit=20"
  }

  expect_failures = [var.postgres_args]
}

run "rejects_a_connection_limit_on_the_migration_url" {
  command = plan

  variables {
    postgres_direct_url = "postgresql://langfuse_acme:secret@shared.postgresflex.eu01.onstackit.cloud:5432/langfuse_acme?connection_limit=20"
  }

  expect_failures = [var.postgres_direct_url]
}

run "rejects_a_connection_limit_below_one" {
  command = plan

  variables {
    postgres_connection_limit = 0
  }

  expect_failures = [var.postgres_connection_limit]
}
