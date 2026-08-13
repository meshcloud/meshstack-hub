# Every per-tenant name the tenant's Langfuse instance needs is derived here, from the tenant
# context alone. `modules/ai/langfuse` takes each of them as an explicit input, because it is
# instantiated once per tenant against shared backends and two tenants that collide on a name share
# their data.

locals {
  # A project identifier alone can repeat across workspaces, so every derived name starts from the
  # pair. The pair is unique in meshStack.
  tenant_key = "${var.workspace_identifier}.${var.project_identifier}"

  # Truncation is unavoidable: Postgres and ClickHouse identifiers, DNS labels, Kubernetes
  # namespaces and bucket names all stop at 63 characters, while the two meshStack identifiers
  # together can be longer. A hash of the untruncated pair is appended to every name, so two long
  # identifier pairs that share a prefix stay apart after truncation.
  tenant_hash = substr(sha256(local.tenant_key), 0, 8)

  # DNS labels and bucket names allow lowercase letters, digits and dashes. Every run of other
  # characters collapses into a single dash, and leading and trailing dashes are dropped.
  tenant_slug_dns = replace(replace(lower(local.tenant_key), "/[^a-z0-9]+/", "-"), "/^-+|-+$/", "")

  # Postgres and ClickHouse identifiers are case-folded and may not start with a digit, so the SQL
  # form uses underscores and every name built from it carries a fixed prefix.
  tenant_slug_sql = replace(replace(lower(local.tenant_key), "/[^a-z0-9]+/", "_"), "/^_+|_+$/", "")

  # 63 characters, minus the longest prefix any derived name carries ('langfuse' plus a separator),
  # minus the separator and the hash at the end.
  slug_budget = 63 - length("langfuse") - 1 - 1 - length(local.tenant_hash)

  # substr fails when the requested length runs past the end of the string, so the length is capped
  # first. Truncation can leave a trailing separator, which is dropped so the hash never follows a
  # doubled separator.
  tenant_slug_dns_short = replace(substr(local.tenant_slug_dns, 0, min(length(local.tenant_slug_dns), local.slug_budget)), "/-+$/", "")
  tenant_slug_sql_short = replace(substr(local.tenant_slug_sql, 0, min(length(local.tenant_slug_sql), local.slug_budget)), "/_+$/", "")

  # One label, used both as the Kubernetes namespace in the AI platform cluster and as the first
  # label of the hostname. Keeping them identical means an operator who has the hostname knows the
  # namespace.
  langfuse_label     = "langfuse-${local.tenant_slug_dns_short}-${local.tenant_hash}"
  langfuse_namespace = local.langfuse_label
  langfuse_hostname  = "${local.langfuse_label}.${var.langfuse_domain}"
  langfuse_url       = "https://${local.langfuse_hostname}"

  # Separation in Postgres and in ClickHouse is a database per tenant. Both carry the same name, so
  # an operator reads one name in two places.
  langfuse_postgres_database   = "langfuse_${local.tenant_slug_sql_short}_${local.tenant_hash}"
  langfuse_clickhouse_database = "langfuse_${local.tenant_slug_sql_short}_${local.tenant_hash}"

  # One bucket per tenant. The three kinds of upload separate by prefix inside it.
  langfuse_bucket = "langfuse-${local.tenant_slug_dns_short}-${local.tenant_hash}"

  # Valkey needs both a key prefix and a database index, and the two carry different guarantees.
  #
  # The prefix is unique per tenant, because it is built from the same slug and hash as every other
  # name here. It is what actually keeps two tenants apart: BullMQ queue names are hardcoded in
  # Langfuse, so two tenants sharing a keyspace without a prefix would have one tenant's worker
  # consume the other tenant's ingestion jobs.
  #
  # The index is a hard namespace that no application bug can cross, but there are only as many
  # indices as the instance serves, so it is derived by hash and repeats once there are more tenants
  # than indices. It is defence in depth behind the prefix, never the separation itself.
  langfuse_valkey_key_prefix = "${local.tenant_slug_dns_short}-${local.tenant_hash}:"
  langfuse_valkey_database   = parseint(local.tenant_hash, 16) % var.langfuse_valkey_database_count

  # The instance holds exactly one organisation and one project, so the identifiers can be the plain
  # meshStack identifiers: the workspace is the organisation, the project is the project. They are
  # not truncated, because Langfuse puts no length limit on either.
  langfuse_org_id       = var.workspace_identifier
  langfuse_org_name     = var.workspace_identifier
  langfuse_project_id   = var.project_identifier
  langfuse_project_name = var.project_identifier
}
