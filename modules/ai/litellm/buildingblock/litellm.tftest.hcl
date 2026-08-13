variables {
  cluster_endpoint       = "api.cluster.example.com"
  cluster_ca_certificate = "dGVzdC1jYQ=="
  token                  = "test-token"

  master_key = "sk-test-master-key"

  postgres_host     = "shared.postgresflex.eu01.onstackit.cloud"
  postgres_username = "litellm"
  postgres_password = "litellm-password"

  model_backends = {
    "chat-large" = {
      model    = "neuralmagic/Mistral-Small-3.1-24B-Instruct-2503-FP8-dynamic"
      api_base = "https://api.openai-compat.model-serving.eu01.onstackit.cloud/v1"
    }
  }

  model_backend_api_keys = {
    "chat-large" = "upstream-token"
  }
}

mock_provider "kubernetes" {}
mock_provider "helm" {}

run "pins_the_prisma_pool_on_the_connection_url" {
  command = plan

  assert {
    condition = yamldecode(helm_release.litellm.values[0]).db.url == "postgresql://$(DATABASE_USERNAME):$(DATABASE_PASSWORD)@$(DATABASE_HOST):5432/$(DATABASE_NAME)?sslmode=require&connection_limit=10"
    # The whole URL is asserted rather than only the parameter, because the credentials have to
    # stay '$(…)' references and the port has to stay in the host.
    error_message = "the rendered db.url must carry the credential references, the port, sslmode and the pinned connection_limit"
  }

  assert {
    condition     = yamldecode(helm_release.litellm.values[0]).proxy_config.general_settings.database_connection_pool_limit == 10
    error_message = "the proxy config must pin the same pool size, because the proxy rewrites connection_limit on the URL from this setting"
  }
}

run "a_lowered_limit_reaches_both_places" {
  command = plan

  variables {
    postgres_connection_limit = 3
  }

  assert {
    condition     = strcontains(yamldecode(helm_release.litellm.values[0]).db.url, "?sslmode=require&connection_limit=3")
    error_message = "postgres_connection_limit must reach the connection URL"
  }

  assert {
    condition     = yamldecode(helm_release.litellm.values[0]).proxy_config.general_settings.database_connection_pool_limit == 3
    error_message = "postgres_connection_limit must reach general_settings.database_connection_pool_limit"
  }
}

run "the_ssl_mode_stays_the_first_parameter" {
  command = plan

  variables {
    postgres_ssl_mode = "disable"
    postgres_port     = 15432
  }

  assert {
    condition     = strcontains(yamldecode(helm_release.litellm.values[0]).db.url, ":15432/$(DATABASE_NAME)?sslmode=disable&connection_limit=10")
    error_message = "the port, the sslmode and the connection limit must all reach the URL in that order"
  }
}

run "rejects_a_connection_limit_below_one" {
  command = plan

  variables {
    postgres_connection_limit = 0
  }

  expect_failures = [var.postgres_connection_limit]
}
