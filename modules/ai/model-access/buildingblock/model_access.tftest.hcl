variables {
  workspace_identifier = "acme"
  project_identifier   = "payments"

  litellm_api_base = "https://litellm.example.com/"
  litellm_api_key  = "sk-admin-mock"

  ai_platform_cluster_kubeconfig = <<-EOT
    current-context: ai-platform
    clusters:
      - name: ai-platform
        cluster:
          server: https://ai-platform.example.invalid
          certificate-authority-data: ""
    users:
      - name: ai-platform
        user:
          token: mock-ai-platform-token
    contexts:
      - name: ai-platform
        context:
          cluster: ai-platform
          user: ai-platform
    EOT

  demo_app_cluster_kubeconfig = <<-EOT
    current-context: demo-app
    clusters:
      - name: demo-app
        cluster:
          server: https://demo-app.example.invalid
          certificate-authority-data: ""
    users:
      - name: demo-app
        user:
          token: mock-demo-app-token
    contexts:
      - name: demo-app
        context:
          cluster: demo-app
          user: demo-app
    EOT

  demo_app_platform_identifier = "kubernetes.eu01"

  langfuse_domain = "ai.example.com"

  # STACKIT, where the module creates the tenant's Postgres database, its owner user and its bucket.
  stackit_project_id                     = "6e8c1f30-6c4d-4b1f-9f7a-2c9d8e5f1a2b"
  stackit_service_account_key            = "{\"id\":\"mock-key\"}"
  stackit_s3_admin_access_key            = "AKIAMOCKADMINKEY"
  stackit_s3_admin_secret_access_key     = "mock-admin-secret-access-key"
  stackit_s3_admin_credentials_group_urn = "urn:sgws:identity::12345678901234567890:group/mock-admin-group"

  langfuse_postgres_instance_id = "3f2504e0-4f89-11d3-9a0c-0305e82c3301"

  langfuse_clickhouse_host = "clickhouse-clickhouse-headless.clickhouse.svc.cluster.local"

  langfuse_valkey_host     = "valkey.valkey.svc.cluster.local"
  langfuse_valkey_password = "valkey-password"

  oidc = {
    issuer_url    = "https://idp.example.com/realms/ai"
    client_id     = "langfuse"
    client_secret = "mock-client-secret"
  }
}

# A distinctive value, so the assertions that check no output carries the credential cannot pass by
# accident.
mock_provider "litellm" {
  mock_resource "litellm_key" {
    defaults = {
      key = "sk-mock-virtual-key-must-never-leave-the-run"
      id  = "mock-key-hash"
    }
  }
}

# The generated Langfuse secrets are validated for their length and their alphabet by the module they
# are passed into, so the mocked values have to be shaped like the real ones. random_bytes is mocked
# once for two resources of different length, which is why the value is 32 bytes of hex: the shorter
# use only reads the first 32 characters of it.
mock_provider "random" {
  mock_resource "random_password" {
    defaults = {
      result = "mockmockmockmockmockmockmockmock"
    }
  }

  mock_resource "random_bytes" {
    defaults = {
      hex    = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
      base64 = "ASNFZ4mrze8BI0VniavN7wEjRWeJq83vASNFZ4mrze8="
    }
  }

  mock_resource "random_uuid" {
    defaults = {
      result = "44444444-4444-4444-4444-444444444444"
    }
  }
}

mock_provider "helm" { alias = "ai_platform" }
mock_provider "kubernetes" { alias = "ai_platform" }
mock_provider "kubernetes" { alias = "demo_app" }

# The two STACKIT submodules read the shared instance and generate credentials, and both feed values
# into `modules/ai/langfuse`, which validates several of them. Every value a generated mock would leave
# null or shape wrongly is therefore set here: the connection info the submodule reads the host and the
# port off, the ACL its summary joins into a string, and the two passwords Langfuse checks the alphabet
# of.
mock_provider "stackit" {
  mock_data "stackit_postgresflex_instance" {
    defaults = {
      name    = "shared-langfuse"
      version = "17"

      connection_info = {
        write = {
          host = "shared.postgresflex.eu01.onstackit.cloud"
          port = 5432
        }
      }

      network = {
        acl              = ["45.129.40.0/21"]
        access_scope     = "PUBLIC"
        instance_address = "10.0.0.10"
        router_address   = "10.0.0.1"
      }
    }
  }

  mock_resource "stackit_postgresflex_user" {
    defaults = {
      password = "mockPostgresPassword"
    }
  }

  mock_resource "stackit_objectstorage_credentials_group" {
    defaults = {
      credentials_group_id = "44444444-4444-4444-4444-444444444444"
      urn                  = "urn:sgws:identity::12345678901234567890:group/mock-tenant-group"
    }
  }

  mock_resource "stackit_objectstorage_credential" {
    defaults = {
      access_key        = "AKIAMOCKTENANTKEY"
      secret_access_key = "mock-tenant-secret-access-key"
    }
  }
}

# The bucket itself is created with the `aws` provider used as a generic S3 client, so the mock covers
# the bucket and its policy.
mock_provider "aws" {}

mock_provider "meshstack" {
  mock_data "meshstack_tenants" {
    defaults = {
      tenants = [
        {
          metadata = { owned_by_project = "payments", owned_by_workspace = "acme", uuid = "11111111-1111-1111-1111-111111111111" }
          ref      = { kind = "meshTenant", uuid = "11111111-1111-1111-1111-111111111111" }
          spec = {
            landing_zone_ref   = { kind = "meshLandingZone", name = "namespace" }
            platform_ref       = { kind = "meshPlatform", uuid = "22222222-2222-2222-2222-222222222222" }
            platform_tenant_id = "acme-payments"
            quotas             = []
            requested_quotas   = null
          }
          status = {
            applied_quotas           = null
            platform_type_identifier = "Kubernetes"
            platform_workspace_id    = "acme"
            tags                     = {}
            tenant_name              = "acme.payments"
          }
        },
      ]
    }
  }
}

run "derives_every_per_tenant_name_from_the_tenant_context" {
  command = plan

  assert {
    # 8 hexadecimal characters of sha256("acme.payments"), appended to every derived name so that
    # two long identifier pairs sharing a prefix stay apart after truncation.
    condition     = output.langfuse_namespace == "langfuse-acme-payments-${substr(sha256("acme.payments"), 0, 8)}"
    error_message = "the Langfuse namespace must be derived from the workspace and the project, with the hash of the pair appended"
  }

  assert {
    condition     = output.langfuse_url == "https://langfuse-acme-payments-${substr(sha256("acme.payments"), 0, 8)}.ai.example.com"
    error_message = "the Langfuse URL must put the derived label in front of the domain the platform team configured"
  }

  assert {
    condition     = output.langfuse_backend_names.postgres_database == "langfuse_acme_payments_${substr(sha256("acme.payments"), 0, 8)}"
    error_message = "the Postgres database name must use underscores, because a Postgres identifier may not carry a dash without quoting"
  }

  assert {
    condition     = output.langfuse_backend_names.clickhouse_database == "langfuse_acme_payments_${substr(sha256("acme.payments"), 0, 8)}"
    error_message = "the ClickHouse database name must be derived the same way as the Postgres one"
  }

  assert {
    condition     = output.langfuse_backend_names.bucket == "langfuse-acme-payments-${substr(sha256("acme.payments"), 0, 8)}"
    error_message = "the bucket name must use dashes, because a bucket name may not carry an underscore"
  }

  assert {
    condition     = output.langfuse_backend_names.valkey_key_prefix == "acme-payments-${substr(sha256("acme.payments"), 0, 8)}:"
    error_message = "the Valkey key prefix must be unique per tenant and end in a colon"
  }

  assert {
    # The index is the hash read as a hexadecimal number, modulo the number of indices the instance
    # serves. It repeats across tenants, which is why the prefix above carries the separation.
    condition     = output.langfuse_backend_names.valkey_database == parseint(substr(sha256("acme.payments"), 0, 8), 16) % 16
    error_message = "the Valkey database index must be derived from the tenant hash, modulo the number of indices"
  }

  assert {
    condition     = output.api_base == "https://litellm.example.com/v1"
    error_message = "the endpoint must carry the '/v1' suffix exactly once, whether or not the configured base URL ends in a slash"
  }
}

run "two_projects_of_the_same_name_in_two_workspaces_get_different_names" {
  command = plan

  variables {
    workspace_identifier = "other"
    project_identifier   = "payments"
  }

  assert {
    condition     = output.langfuse_namespace == "langfuse-other-payments-${substr(sha256("other.payments"), 0, 8)}"
    error_message = "a project identifier alone can repeat across workspaces, so the workspace has to be part of every derived name"
  }

  assert {
    condition     = output.langfuse_backend_names.postgres_database != "langfuse_acme_payments_${substr(sha256("acme.payments"), 0, 8)}"
    error_message = "two projects of the same name in two workspaces must not share a Postgres database"
  }
}

run "long_identifiers_stay_inside_the_63_character_limit" {
  command = plan

  variables {
    # 40 characters each. The pair is 81 characters with the separator, so every derived name has to
    # be truncated, and the two pairs below differ only after the truncation point.
    workspace_identifier = "a-very-long-workspace-identifier-indeed1"
    project_identifier   = "a-very-long-project-identifier-for-tests"
  }

  assert {
    condition     = length(output.langfuse_namespace) <= 63
    error_message = "the namespace has to stay inside the 63 character limit of a DNS label"
  }

  assert {
    condition     = length(output.langfuse_backend_names.postgres_database) <= 63
    error_message = "the Postgres database name has to stay inside the 63 character limit of an identifier"
  }

  assert {
    condition     = length(output.langfuse_backend_names.bucket) <= 63
    error_message = "the bucket name has to stay inside the 63 character limit"
  }

  assert {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", output.langfuse_namespace))
    error_message = "the namespace has to be a valid DNS label after truncation, so it may not end in a dash"
  }

  assert {
    # Truncation cuts the slug at the same place for both pairs, so only the hash keeps the two
    # apart. Without it, two long identifier pairs would share one database.
    condition     = endswith(output.langfuse_backend_names.postgres_database, substr(sha256("a-very-long-workspace-identifier-indeed1.a-very-long-project-identifier-for-tests"), 0, 8))
    error_message = "a truncated name has to end in the hash of the untruncated identifier pair"
  }
}

run "identifiers_with_unexpected_characters_are_folded_into_valid_names" {
  command = plan

  variables {
    workspace_identifier = "ACME_Corp"
    project_identifier   = "Payments.EU"
  }

  assert {
    condition     = output.langfuse_namespace == "langfuse-acme-corp-payments-eu-${substr(sha256("ACME_Corp.Payments.EU"), 0, 8)}"
    error_message = "every run of characters that a DNS label does not allow has to collapse into a single dash, and the name has to be lowercased"
  }

  assert {
    condition     = output.langfuse_backend_names.postgres_database == "langfuse_acme_corp_payments_eu_${substr(sha256("ACME_Corp.Payments.EU"), 0, 8)}"
    error_message = "the SQL form has to use underscores for the same runs of characters"
  }
}

# --- The per-tenant backend resources -----------------------------------------------------------

run "the_backend_resources_carry_the_names_naming_tf_derives" {
  command = plan

  assert {
    # Read off the created database rather than off the local it came from: the module now owns the
    # name, so a rename would replace the database and take the data in it with it.
    condition     = output.langfuse_backend_names.postgres_database == "langfuse_acme_payments_${substr(sha256("acme.payments"), 0, 8)}"
    error_message = "the database created on the shared Postgres instance has to carry the name naming.tf derives"
  }

  assert {
    # A Postgres role is an object of the whole server, so the owner has to be per-tenant as well.
    condition     = output.langfuse_backend_names.postgres_username == "langfuse_acme_payments_${substr(sha256("acme.payments"), 0, 8)}"
    error_message = "the owner of the tenant's Postgres database has to carry the name of the database it owns"
  }

  assert {
    condition     = output.langfuse_backend_names.bucket == "langfuse-acme-payments-${substr(sha256("acme.payments"), 0, 8)}"
    error_message = "the created bucket has to carry the name naming.tf derives"
  }

  assert {
    # The DDL Job receives the two ClickHouse names as Helm values, so this is where they are checked.
    condition     = yamldecode(helm_release.clickhouse_ddl.values[0]).tenant.database == "langfuse_acme_payments_${substr(sha256("acme.payments"), 0, 8)}"
    error_message = "the DDL Job has to create the ClickHouse database under the name naming.tf derives"
  }

  assert {
    condition     = yamldecode(helm_release.clickhouse_ddl.values[0]).tenant.username == "langfuse_acme_payments_${substr(sha256("acme.payments"), 0, 8)}"
    error_message = "the ClickHouse user has to carry the name of the database it is scoped to"
  }

  assert {
    # The DDL runs in the namespace of the shared cluster, because the administrative password is a
    # Secret in it and the tenant's own namespace does not exist yet at that point.
    condition     = helm_release.clickhouse_ddl.namespace == "clickhouse" && kubernetes_secret_v1.langfuse_clickhouse_user.metadata[0].namespace == "clickhouse"
    error_message = "the DDL release and the Secret holding the tenant's ClickHouse password have to live in the namespace of the shared cluster"
  }
}

run "the_clickhouse_user_is_granted_only_what_langfuse_uses" {
  command = plan

  assert {
    # The full list, in order, so adding or removing a right is a deliberate change this test has to be
    # updated for.
    condition = yamldecode(helm_release.clickhouse_ddl.values[0]).tenant.grants == [
      "SELECT",
      "INSERT",
      "CREATE",
      "DROP TABLE",
      "ALTER UPDATE",
      "ALTER DELETE",
      "ALTER DROP INDEX",
    ]
    error_message = "the grant list of the tenant's ClickHouse user changed; it has to be exactly what Langfuse uses on its own database"
  }

  assert {
    # golang-migrate creates tables inside a database that already exists and never creates one, so
    # this right would only let a tenant create databases outside its own scope.
    condition     = !contains(yamldecode(helm_release.clickhouse_ddl.values[0]).tenant.grants, "CREATE DATABASE")
    error_message = "the tenant's ClickHouse user must not be granted CREATE DATABASE"
  }

  assert {
    # Required as soon as the cluster has more than one replica, and harmless with one.
    condition     = yamldecode(helm_release.clickhouse_ddl.values[0]).clickhouse.ddlCluster == "default"
    error_message = "the DDL has to name the cluster the shared ClickHouse answers as, because every statement runs ON CLUSTER"
  }
}

run "long_identifiers_keep_the_ddl_release_name_inside_the_helm_limit" {
  command = plan

  variables {
    workspace_identifier = "a-very-long-workspace-identifier-indeed1"
    project_identifier   = "a-very-long-project-identifier-for-tests"
  }

  assert {
    # Helm stops a release name at 53 characters. Every object of the release derives its name from the
    # release name, so this limit is the tightest of the family and the one the budget is cut for.
    condition     = length(helm_release.clickhouse_ddl.name) <= 53
    error_message = "the name of the DDL release has to stay inside the 53 characters Helm allows"
  }

  assert {
    # The Job names are '<release>-create' and '<release>-drop', and a Job name ends up in a label
    # value, which stops at 63 characters.
    condition     = length("${helm_release.clickhouse_ddl.name}-create") <= 63
    error_message = "the Job names derived from the release name have to stay inside the 63 characters a label value allows"
  }

  assert {
    condition     = endswith(helm_release.clickhouse_ddl.name, substr(sha256("a-very-long-workspace-identifier-indeed1.a-very-long-project-identifier-for-tests"), 0, 8))
    error_message = "the truncated release name has to end in the hash of the untruncated identifier pair, or two long identifier pairs collide on one release"
  }
}

# --- The sibling tenant of the same meshProject -------------------------------------------------

run "the_namespace_of_the_secret_comes_from_the_platform_tenant_id" {
  command = plan

  assert {
    condition     = kubernetes_secret_v1.model_access.metadata[0].namespace == "acme-payments"
    error_message = "the Secret has to go into the namespace the sibling tenant reports as its platform tenant id"
  }

  assert {
    condition     = output.secret_namespace == "acme-payments"
    error_message = "the reported namespace has to be the one the Secret was written into"
  }

  assert {
    condition     = kubernetes_secret_v1.model_access.metadata[0].name == "ai-model-access"
    error_message = "the Secret has to carry the name the platform team configured"
  }
}

run "no_sibling_tenant_stops_the_run" {
  command = plan

  override_data {
    target = data.meshstack_tenants.sibling
    values = {
      tenants = []
    }
  }

  expect_failures = [resource.kubernetes_secret_v1.model_access]
}

run "two_sibling_tenants_stop_the_run" {
  command = plan

  override_data {
    target = data.meshstack_tenants.sibling
    values = {
      tenants = [
        {
          metadata = { owned_by_project = "payments", owned_by_workspace = "acme", uuid = "11111111-1111-1111-1111-111111111111" }
          ref      = { kind = "meshTenant", uuid = "11111111-1111-1111-1111-111111111111" }
          spec = {
            landing_zone_ref   = { kind = "meshLandingZone", name = "namespace" }
            platform_ref       = { kind = "meshPlatform", uuid = "22222222-2222-2222-2222-222222222222" }
            platform_tenant_id = "acme-payments"
            quotas             = []
            requested_quotas   = null
          }
          status = {
            applied_quotas           = null
            platform_type_identifier = "Kubernetes"
            platform_workspace_id    = "acme"
            tags                     = {}
            tenant_name              = "acme.payments"
          }
        },
        {
          metadata = { owned_by_project = "payments", owned_by_workspace = "acme", uuid = "33333333-3333-3333-3333-333333333333" }
          ref      = { kind = "meshTenant", uuid = "33333333-3333-3333-3333-333333333333" }
          spec = {
            landing_zone_ref   = { kind = "meshLandingZone", name = "namespace" }
            platform_ref       = { kind = "meshPlatform", uuid = "22222222-2222-2222-2222-222222222222" }
            platform_tenant_id = "acme-payments-second"
            quotas             = []
            requested_quotas   = null
          }
          status = {
            applied_quotas           = null
            platform_type_identifier = "Kubernetes"
            platform_workspace_id    = "acme"
            tags                     = {}
            tenant_name              = "acme.payments.second"
          }
        },
      ]
    }
  }

  expect_failures = [resource.kubernetes_secret_v1.model_access]
}

run "a_sibling_tenant_without_a_platform_tenant_id_stops_the_run" {
  command = plan

  # meshStack has accepted the tenant but has not replicated it yet, so its namespace does not exist.
  # This is the dangerous case: a null namespace would make the Kubernetes provider fall back to the
  # namespace of the kubeconfig's current context.
  override_data {
    target = data.meshstack_tenants.sibling
    values = {
      tenants = [
        {
          metadata = { owned_by_project = "payments", owned_by_workspace = "acme", uuid = "11111111-1111-1111-1111-111111111111" }
          ref      = { kind = "meshTenant", uuid = "11111111-1111-1111-1111-111111111111" }
          spec = {
            landing_zone_ref   = { kind = "meshLandingZone", name = "namespace" }
            platform_ref       = { kind = "meshPlatform", uuid = "22222222-2222-2222-2222-222222222222" }
            platform_tenant_id = null
            quotas             = []
            requested_quotas   = null
          }
          status = {
            applied_quotas           = null
            platform_type_identifier = "Kubernetes"
            platform_workspace_id    = "acme"
            tags                     = {}
            tenant_name              = "acme.payments"
          }
        },
      ]
    }
  }

  expect_failures = [resource.kubernetes_secret_v1.model_access]
}

# --- The credential never leaves the run --------------------------------------------------------

run "no_output_and_no_summary_carries_the_credential" {
  command = apply

  assert {
    # The Secret is the one place the credential is written to, so the test would be meaningless if
    # it were not there.
    condition     = nonsensitive(kubernetes_secret_v1.model_access.data["OPENAI_API_KEY"]) == nonsensitive(litellm_key.this.key)
    error_message = "the Secret has to carry the credential, otherwise the workload has no way to reach the endpoint"
  }

  assert {
    condition     = nonsensitive(kubernetes_secret_v1.model_access.data["OPENAI_BASE_URL"]) == "https://litellm.example.com/v1"
    error_message = "the Secret has to carry the endpoint next to the credential"
  }

  assert {
    condition     = !strcontains(output.summary, nonsensitive(litellm_key.this.key))
    error_message = "the summary is published in meshPanel, so it must not contain the credential"
  }

  assert {
    condition = alltrue([
      for value in [
        output.team_id,
        output.team_alias,
        output.key_id,
        output.api_base,
        output.secret_name,
        output.secret_namespace,
        output.langfuse_url,
        output.langfuse_namespace,
        output.langfuse_oidc_callback_url,
        output.summary,
      ] : !strcontains(value, nonsensitive(litellm_key.this.key))
    ])
    error_message = "no output of this module may contain the credential, because a building block output cannot be sensitive"
  }

  assert {
    condition     = strcontains(output.summary, "ai-model-access") && strcontains(output.summary, "acme-payments")
    error_message = "the summary has to tell the application team where the credential is: the Secret by name, in its namespace"
  }
}
