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

run "keeps_the_user_table_empty_by_default" {
  command = plan

  assert {
    # This is the switch that holds the console inside the free limit of five users. Without it the
    # first /team/new call writes one row to LiteLLM_UserTable and takes one of the five seats.
    condition     = yamldecode(helm_release.litellm.values[0]).proxy_config.general_settings.disable_auto_add_proxy_admin_to_teams == true
    error_message = "the proxy config must carry general_settings.disable_auto_add_proxy_admin_to_teams: true"
  }
}

run "the_user_table_switch_can_be_turned_off" {
  command = plan

  variables {
    disable_auto_add_proxy_admin_to_teams = false
  }

  assert {
    condition     = yamldecode(helm_release.litellm.values[0]).proxy_config.general_settings.disable_auto_add_proxy_admin_to_teams == false
    error_message = "the variable must reach general_settings.disable_auto_add_proxy_admin_to_teams unchanged"
  }
}

run "renders_no_sso_environment_without_an_identity_provider" {
  command = plan

  assert {
    condition     = yamldecode(helm_release.litellm.values[0]).envVars == {}
    error_message = "a gateway without var.oidc must carry no SSO environment variables at all"
  }

  assert {
    # The client secret secret is the only one added for SSO, so its absence is what proves the
    # module created nothing for a caller who has no identity provider.
    condition     = length(yamldecode(helm_release.litellm.values[0]).environmentSecrets) == 1
    error_message = "without var.oidc the only environment secret must be the model credentials one"
  }
}

run "renders_the_sso_environment_from_explicit_endpoints" {
  command = plan

  variables {
    public_url = "https://litellm.example.com"

    oidc = {
      issuer_url    = "https://idp.example.com/realms/ai"
      client_id     = "litellm-console"
      client_secret = "oidc-client-secret"

      authorization_endpoint = "https://idp.example.com/realms/ai/protocol/openid-connect/auth"
      token_endpoint         = "https://idp.example.com/realms/ai/protocol/openid-connect/token"
      userinfo_endpoint      = "https://idp.example.com/realms/ai/protocol/openid-connect/userinfo"

      user_display_name_attribute = "name"
      user_role_attribute         = "litellm_role"
      allowed_email_domains       = ["example.com", "example.org"]
      proxy_admin_id              = "platform-team-lead"
      logout_url                  = "https://litellm.example.com/ui"
      auto_redirect_to_sso        = true
    }
  }

  assert {
    # All three endpoints given, so the module must create no discovery request.
    condition     = length(data.http.oidc_discovery) == 0
    error_message = "three explicit endpoints must skip OIDC discovery entirely"
  }

  assert {
    condition = yamldecode(helm_release.litellm.values[0]).envVars == {
      GENERIC_CLIENT_ID              = "litellm-console"
      GENERIC_AUTHORIZATION_ENDPOINT = "https://idp.example.com/realms/ai/protocol/openid-connect/auth"
      GENERIC_TOKEN_ENDPOINT         = "https://idp.example.com/realms/ai/protocol/openid-connect/token"
      GENERIC_USERINFO_ENDPOINT      = "https://idp.example.com/realms/ai/protocol/openid-connect/userinfo"
      GENERIC_SCOPE                  = "openid email profile"

      GENERIC_USER_ID_ATTRIBUTE           = "sub"
      GENERIC_USER_DISPLAY_NAME_ATTRIBUTE = "name"
      GENERIC_USER_ROLE_ATTRIBUTE         = "litellm_role"

      PROXY_BASE_URL                = "https://litellm.example.com"
      PROXY_LOGOUT_URL              = "https://litellm.example.com/ui"
      PROXY_ADMIN_ID                = "platform-team-lead"
      ALLOWED_EMAIL_DOMAINS         = "example.com,example.org"
      AUTO_REDIRECT_UI_LOGIN_TO_SSO = "true"
    }
    # The whole map is asserted rather than single keys, so a variable the module renders by
    # accident — the client secret above all — fails the test.
    error_message = "the rendered envVars must carry exactly the SSO environment variables the caller configured"
  }

  assert {
    condition     = contains(yamldecode(helm_release.litellm.values[0]).environmentSecrets, "litellm-oidc")
    error_message = "the client secret must reach the pods through an environmentSecrets entry"
  }
}

run "pins_the_user_id_claim_and_leaves_the_rest_to_the_proxy" {
  command = plan

  variables {
    public_url = "https://litellm.example.com"

    oidc = {
      issuer_url    = "https://idp.example.com/realms/ai"
      client_id     = "litellm-console"
      client_secret = "oidc-client-secret"

      authorization_endpoint = "https://idp.example.com/realms/ai/protocol/openid-connect/auth"
      token_endpoint         = "https://idp.example.com/realms/ai/protocol/openid-connect/token"
      userinfo_endpoint      = "https://idp.example.com/realms/ai/protocol/openid-connect/userinfo"
    }
  }

  assert {
    # The proxy's own default is 'preferred_username', which is reassignable and would produce a
    # second user row for the same person. The module pins 'sub' instead.
    condition     = yamldecode(helm_release.litellm.values[0]).envVars.GENERIC_USER_ID_ATTRIBUTE == "sub"
    error_message = "the module must pin GENERIC_USER_ID_ATTRIBUTE to 'sub' rather than leave the proxy on 'preferred_username'"
  }

  assert {
    # The proxy defaults the email claim to 'email', so an unset attribute has to stay out of the
    # pod spec instead of arriving as an empty string.
    condition = length(setintersection(keys(yamldecode(helm_release.litellm.values[0]).envVars), [
      "GENERIC_USER_EMAIL_ATTRIBUTE",
      "GENERIC_USER_DISPLAY_NAME_ATTRIBUTE",
      "GENERIC_USER_ROLE_ATTRIBUTE",
      "PROXY_LOGOUT_URL",
      "PROXY_ADMIN_ID",
      "ALLOWED_EMAIL_DOMAINS",
      "AUTO_REDIRECT_UI_LOGIN_TO_SSO",
    ])) == 0
    error_message = "an unset optional SSO setting must not be rendered at all"
  }
}

run "derives_the_endpoints_from_the_discovery_document" {
  command = plan

  variables {
    public_url = "https://litellm.example.com"

    oidc = {
      issuer_url    = "https://idp.example.com/realms/ai"
      client_id     = "litellm-console"
      client_secret = "oidc-client-secret"
    }
  }

  # The values have to be literals, so the discovery document is written out as JSON text.
  override_data {
    target = data.http.oidc_discovery
    values = {
      status_code   = 200
      response_body = <<-EOT
        {
          "issuer": "https://idp.example.com/realms/ai",
          "authorization_endpoint": "https://idp.example.com/realms/ai/protocol/openid-connect/auth",
          "token_endpoint": "https://idp.example.com/realms/ai/protocol/openid-connect/token",
          "userinfo_endpoint": "https://idp.example.com/realms/ai/protocol/openid-connect/userinfo"
        }
      EOT
    }
  }

  assert {
    condition     = data.http.oidc_discovery[0].url == "https://idp.example.com/realms/ai/.well-known/openid-configuration"
    error_message = "the module must read the discovery document at '<issuer_url>/.well-known/openid-configuration'"
  }

  assert {
    condition = alltrue([
      yamldecode(helm_release.litellm.values[0]).envVars.GENERIC_AUTHORIZATION_ENDPOINT == "https://idp.example.com/realms/ai/protocol/openid-connect/auth",
      yamldecode(helm_release.litellm.values[0]).envVars.GENERIC_TOKEN_ENDPOINT == "https://idp.example.com/realms/ai/protocol/openid-connect/token",
      yamldecode(helm_release.litellm.values[0]).envVars.GENERIC_USERINFO_ENDPOINT == "https://idp.example.com/realms/ai/protocol/openid-connect/userinfo",
    ])
    error_message = "the three endpoints must come out of the discovery document"
  }
}

run "an_endpoint_override_wins_over_the_discovery_document" {
  command = plan

  variables {
    public_url = "https://litellm.example.com"

    oidc = {
      issuer_url    = "https://idp.example.com/realms/ai"
      client_id     = "litellm-console"
      client_secret = "oidc-client-secret"

      token_endpoint = "https://token.example.com/oauth2/token"
    }
  }

  override_data {
    target = data.http.oidc_discovery
    values = {
      status_code   = 200
      response_body = <<-EOT
        {
          "authorization_endpoint": "https://idp.example.com/realms/ai/protocol/openid-connect/auth",
          "token_endpoint": "https://idp.example.com/realms/ai/protocol/openid-connect/token",
          "userinfo_endpoint": "https://idp.example.com/realms/ai/protocol/openid-connect/userinfo"
        }
      EOT
    }
  }

  assert {
    condition     = yamldecode(helm_release.litellm.values[0]).envVars.GENERIC_TOKEN_ENDPOINT == "https://token.example.com/oauth2/token"
    error_message = "an endpoint set in var.oidc must win over the one in the discovery document"
  }

  assert {
    condition     = yamldecode(helm_release.litellm.values[0]).envVars.GENERIC_AUTHORIZATION_ENDPOINT == "https://idp.example.com/realms/ai/protocol/openid-connect/auth"
    error_message = "the endpoints the caller left unset must still come out of the discovery document"
  }
}

run "rejects_an_identity_provider_without_a_public_url" {
  command = plan

  variables {
    oidc = {
      issuer_url    = "https://idp.example.com/realms/ai"
      client_id     = "litellm-console"
      client_secret = "oidc-client-secret"
    }
  }

  expect_failures = [var.oidc]
}

run "rejects_an_issuer_that_is_not_an_https_url" {
  command = plan

  variables {
    public_url = "https://litellm.example.com"

    oidc = {
      issuer_url    = "idp.example.com/realms/ai"
      client_id     = "litellm-console"
      client_secret = "oidc-client-secret"
    }
  }

  expect_failures = [var.oidc]
}

run "rejects_a_public_url_with_a_trailing_slash" {
  command = plan

  variables {
    public_url = "https://litellm.example.com/"
  }

  expect_failures = [var.public_url]
}
