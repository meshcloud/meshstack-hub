---
name: Langfuse (per tenant)
supportedPlatforms:
  - kubernetes
description: Installs one Langfuse v4 instance per tenant into its own Kubernetes namespace, against a shared Postgres, ClickHouse, Valkey and object storage, bootstrapped with an organisation, a project and an API keypair.
# Every backend connection, every credential and the identity provider arrive as inputs, so there
# is nothing to set up on the cloud side before this module runs.
requiresBackplane: false
---

# Langfuse Building Block

The platform team installs one Langfuse instance per tenant with this module. Each instance has its own namespace, its own hostname, its own secrets and its own slice of four shared backends, and it comes up with an organisation, a project and an API keypair already in place, so a tracing client can be pointed at it in the same Terraform run.

This documentation is intended as a reference for cloud foundation or platform engineers using this module.

## Sourced, not ordered

There is no `meshstack_integration.tf` and no `backplane/`. A tenant-facing building block sources `buildingblock/`, derives every per-tenant name, and passes them in. Application teams order that composition, not this module.

## Deployment cardinality

**This module is instantiated once per tenant.** Every value that identifies a tenant is an explicit input rather than something the module derives: the namespace, the release name, the hostname, the Postgres database, the ClickHouse database, the Valkey key prefix and database index, the bucket, the three secrets and the `LANGFUSE_INIT_*` values. The caller derives them from the tenant, this module consumes them.

`modules/ai/clickhouse` is the opposite: it is deployed once per Kubernetes cluster and shared by every instance this module creates.

## The chart, and why the image tag is overridden

| | |
|---|---|
| Chart | `langfuse` |
| Repository | `https://langfuse.github.io/langfuse-k8s` — a classic Helm repository, not OCI |
| Pinned chart version | `1.5.41` (`var.chart_version`) |
| Chart `appVersion` | `3.224.1` |
| Image tag | `4.10.0` (`var.image_tag`) |

The chart's `appVersion` is still a v3 release, so the chart on its own installs Langfuse v3. Overriding `langfuse.image.tag` is what selects v4, exactly as [`examples/v4-installation`](https://github.com/langfuse/langfuse-k8s/tree/main/examples/v4-installation) in `langfuse-k8s` does. One consequence: the `app.kubernetes.io/version` label on every rendered object reads `3.224.1` while the containers run v4. Read the image, not the label.

The example uses the floating tag `"4"`. **Do not.** It moves whenever Langfuse publishes a v4 release, so two pods of one Deployment can land on two different builds, a `helm upgrade` that changes nothing still rolls the Deployment, and a regression cannot be undone by reverting the Terraform change. `var.image_tag` validates that the value is a full `4.x.y` version.

## No provider blocks

This module carries no `provider` block. The caller configures the `kubernetes` and the `helm` provider and passes both down through the `providers` argument of the module call.

**A module with its own provider configuration cannot be called with `count` or `for_each`.** A composition that instantiates this module once per tenant needs exactly that, so the provider configuration has to stay outside. `modules/kubernetes/ingress` had to delete its `provider.tf` for the same reason.

## All four backends are external and mandatory

Every `*.deploy` flag in the chart is a **placement switch, not a feature switch**. Setting `clickhouse.deploy: false` does not make Langfuse run without ClickHouse — it says the ClickHouse lives outside the chart. All four backends are required, and the chart's own bundled subcharts are Bitnami images that no longer receive updates.

| Backend | Separation per tenant | Chart keys this module sets |
|---|---|---|
| Postgres | a database and an owner user | `postgresql.deploy`, `.host`, `.args`, `.auth.username`, `.auth.database`, `.auth.existingSecret`, `.auth.secretKeys`, `.migration.autoMigrate` |
| ClickHouse | a database and a user scoped to `<database>.*` | `clickhouse.deploy`, `.host`, `.httpPort`, `.nativePort`, `.database`, `.auth.username`, `.auth.existingSecret`, `.auth.existingSecretKey`, `.clusterEnabled`, `.migration.autoMigrate` |
| Valkey | a database index **and** a key prefix | `redis.deploy`, `.host`, `.port`, `.auth.username`, `.auth.database`, `.auth.existingSecret`, `.auth.existingSecretPasswordKey` |
| S3 | one bucket | `s3.deploy`, `.bucket`, `.region`, `.endpoint`, `.forcePathStyle`, `.accessKeyId`, `.secretAccessKey`, and `eventUpload`, `batchExport`, `mediaUpload` with the same keys plus `.prefix` |

The databases, users and buckets are created by the composition, not here. See the [per-tenant separation section](../../clickhouse/buildingblock/README.md#per-tenant-separation-and-who-creates-it) in the ClickHouse module for the reasoning and for the exact ClickHouse statements.

Every credential reaches the pods through a `secretKeyRef` into one Kubernetes Secret this module creates, so no secret ever appears in the Helm values or in a Terraform plan.

### Postgres: the port is folded into the host

**Langfuse never reads `DATABASE_PORT`.** Both container entrypoints build the connection URL as `postgresql://$DATABASE_USERNAME:$DATABASE_PASSWORD@$DATABASE_HOST/$DATABASE_NAME`, with `?$DATABASE_ARGS` appended. The chart does set `DATABASE_PORT` from `postgresql.port`, and nothing reads it, so a non-default port set that way is silently lost and the connection goes to 5432.

This module therefore passes `postgresql.host = "<host>:<port>"` and leaves `postgresql.port` unset. `var.postgres_host` and `var.postgres_port` stay separate inputs.

Two more consequences of that string substitution:

- **The Postgres password has to be safe in a URL.** Nothing percent-encodes it, and Prisma answers `P1013` on a password containing `:`, `@`, `/`, `?`, `#` or `%`. `var.postgres_password` rejects those characters.
- **`postgresql.directUrl` would carry the password in plain text** into the pod spec and into Helm's release Secret. The module leaves that chart key unset and injects `DIRECT_URL` through `langfuse.additionalEnv` with a `secretKeyRef` instead, so `var.postgres_direct_url` is handled like every other credential.

The ClickHouse password has the same problem in a different place: the migration script puts it into a query string, so `&`, `=`, `#`, `?`, `%`, `+`, `@` and spaces break the migration URL. `var.clickhouse_password` rejects those too.

### Postgres: the connection pool is pinned, and the budget is shared

**Prisma sizes its connection pool as `physical cores × 2 + 1` when the connection URL names no `connection_limit`**, and it counts the physical cores of the *node*, not the pod's CPU limit. [prisma-engines#4341](https://github.com/prisma/prisma-engines/issues/4341) records that as an oversight and was closed without a fix. A pod with a `100m` CPU limit therefore takes 33 connections on a 16-core node, 40 pods take 1320, and the number changes silently when a pod is rescheduled onto a node with a different core count.

STACKIT PostgreSQL Flex fixes `max_connections` by the flavour, reserves 15 of them for its own processes, and exposes no parameter group in the API, the SDK or the Terraform provider. The limit follows RAM rather than vCPUs, so 4 vCPU / 32 GiB and 16 vCPU / 32 GiB both give 785. There is no server-side lever, so every pod pins its own pool.

| Variable | Default | Applies to |
|---|---|---|
| `postgres_connection_limit` | `5` | `DATABASE_URL`, so every web and worker pod. Appended to `postgres_args`. |
| `postgres_direct_url_connection_limit` | `2` | `DIRECT_URL`, the migration connection. Appended to `postgres_direct_url`. |

This module is instantiated once per tenant against a shared instance, so the budget is a sum over tenants:

```
tenants × pods per tenant × connection_limit  +  15 reserved  ≤  max_connections
```

Four pods per tenant at `connection_limit = 5` come to 20 connections per tenant, so a 4 vCPU / 32 GiB instance carries roughly 34 tenants. Unpinned, the same instance runs out at five. Leave around 10% free for the migrations, for a `psql` session and for a rolling deploy in which the old and the new pods overlap. `modules/stackit/postgresflex` carries the [per-flavour table and the full budget](../../../stackit/postgresflex/buildingblock/README.md#how-many-connections-one-instance-carries).

**The migration connection gets a limit of its own, and a much smaller one.** `DIRECT_URL` is a full URL the caller hands in, so it never passes through `postgres_args` and would otherwise carry Prisma's node-sized default. The web entrypoint runs `prisma db execute` and then `prisma migrate deploy` one after the other, and each opens a single connection, so two is a ceiling rather than a target. Leave `postgres_direct_url` unset and the entrypoint reuses `DATABASE_URL`, which already carries the pinned pool.

Three details of how the parameters are written:

- The module appends `connection_limit` to `postgres_args`, and `var.postgres_args` rejects a `connection_limit` the caller put there, because two occurrences in one query string leave the effective pool size to the parser.
- On `postgres_direct_url` the module appends `&connection_limit=…` when the URL already carries a query string and `?connection_limit=…` when it does not. `var.postgres_direct_url` rejects a URL that already names the parameter.
- **A query parameter does not weaken the password rule.** The password sits in the userinfo part of the URL, before the `?`, so `&` and `=` in the query string cannot reach it. The characters `var.postgres_password` rejects — `:`, `@`, `/`, `?`, `#` and `%` — are rejected for the same reason as before: nothing percent-encodes the value, and Prisma answers `P1013`.

`pool_timeout` is the companion parameter: a request that finds no free connection waits that long and then fails with `P2024`. Prisma defaults to 10 seconds. Put `pool_timeout=…` into `var.postgres_args` when a pinned pool of 5 turns out to be tight under a burst, before raising the limit itself.

### Valkey: set both the index and the key prefix

`var.valkey_database` and `var.valkey_key_prefix` are both required, and they do different jobs.

- The **database index** becomes the path of `REDIS_CONNECTION_STRING`. A connection that selected index *n* cannot reach a key in another index at all, so it is a hard namespace that no application bug can cross.
- The **key prefix** survives a later move to Redis Cluster, where indices vanish because a cluster only has database 0.

**Sharing one Valkey database without a key prefix is a data-crossing bug, not a performance one.** BullMQ queue names are hardcoded in the application, so two tenants on one index with no prefix share `ingestion-queue` — and tenant A's worker consumes tenant B's ingestion jobs, writing B's traces into A's ClickHouse database. Do not simplify this away.

**`REDIS_KEY_PREFIX` is not exposed by the chart.** It appears nowhere in `_helpers.tpl`, so the module injects it through `langfuse.additionalEnv`. It also has an application floor of **v3.157.0**: the variable existed before, but BullMQ ignored it until [langfuse/langfuse#11898](https://github.com/langfuse/langfuse/pull/11898) merged on 2026-03-06, and v3.157.0 is the first release that contains the fix. Any v4 release is far above that floor.

### Three secrets that must differ per tenant

| Variable | Environment variable | What it protects |
|---|---|---|
| `salt` | `SALT` | Hashes this tenant's API keys. Langfuse also mixes it into the fast hash of every key, so changing it invalidates every key the tenant holds. |
| `encryption_key` | `ENCRYPTION_KEY` | Encrypts secrets at rest in this tenant's Postgres database. 256 bits, 64 hex characters. |
| `nextauth_secret` | `NEXTAUTH_SECRET` | Signs the NextAuth JWT. Two tenants sharing it accept each other's session tokens. |

All three are validated for length and shape and reach the pods through a `secretKeyRef`.

`langfuse.nextauth.url` defaults to `http://localhost:3000` in the chart, which breaks every OAuth callback and every link in an invitation mail. The module sets it from `var.hostname`, or from `var.public_url` when the instance is reached on another name.

## Authentication

### Sign-up stays enabled, and that is deliberate

`langfuse.features.signUpDisabled` is hardcoded to `false` in this module. It looks like the hardening switch and it is not.

`AUTH_DISABLE_SIGNUP` is checked inside the NextAuth adapter's `createUser`, and an SSO login by a user who is not in the database yet goes through exactly that path. On a freshly provisioned per-tenant instance that is every user, so turning sign-up off blocks the first login of everybody.

The control that belongs to the operator is `langfuse.auth.disableUsernamePassword`, which this module sets from `var.disable_username_password` and turns on automatically whenever `var.oidc` is set. Who may log in is decided at the identity provider.

### SSO is free, and it removes member synchronisation

Self-hosted SSO carries no entitlement in Langfuse — it is absent from the exhaustive entitlement list, and the `AUTH_*` variables are read with no entitlement check anywhere in provider construction. It works without an Enterprise licence.

`var.oidc` configures Langfuse's generic `custom` OIDC provider, which the chart turns into `AUTH_CUSTOM_ISSUER`, `AUTH_CUSTOM_CLIENT_ID`, `AUTH_CUSTOM_CLIENT_SECRET`, `AUTH_CUSTOM_NAME`, `AUTH_CUSTOM_SCOPE` and `AUTH_CUSTOM_ALLOW_ACCOUNT_LINKING`. Langfuse discovers the endpoints from `<issuer_url>/.well-known/openid-configuration`. Register the callback URL the `oidc_callback_url` output prints — `<public_url>/api/auth/callback/custom` — at the provider. Keycloak, Entra ID, Okta and Auth0 all fit this shape unchanged.

The identity provider is an input, never an assumption. STACKIT publishes OIDC discovery at `https://accounts.stackit.cloud`, but client registration is undocumented and unsupported for customer applications and its discovery document carries no `registration_endpoint`, so STACKIT is not the identity provider here.

**There is no member synchronisation to build.** Langfuse upserts an organisation membership for every user who logs in, with the role in `LANGFUSE_DEFAULT_ORG_ROLE`, and there is no entitlement check on that path. The `rbac-project-roles` check next to it guards only *project*-level memberships, and without that entitlement users inherit their organisation role for every project. With one organisation and one project per tenant, the organisation role **is** the access grant. It fires on first login through `createUser` and on every later login through `linkAccount`, the upsert never overwrites a role a user already has, and it is idempotent. The Enterprise-gated memberships API and SCIM are irrelevant here.

This module sets `LANGFUSE_DEFAULT_ORG_ID` to `var.init_org_id`, so the organisation the bootstrap creates is the one users join.

### Access control: what the operator owns

With sign-up enabled and `LANGFUSE_DEFAULT_ORG_ID` set, **everyone the identity provider will authenticate becomes a member of this tenant's organisation.** Nothing sits between "the provider said yes" and "you are in this tenant's Langfuse".

The mitigation is **one OIDC client per tenant instance, with only that tenant's members assigned to it at the provider.** That is the operator's responsibility and this module cannot enforce it. `var.default_org_role = "NONE"` hands out a membership that grants nothing, which turns auto-join off while leaving users who were added by hand able to work.

No `oauth2-proxy`. Langfuse speaks OIDC natively, so a proxy in front is redundant; the HAProxy ingress controller in `modules/kubernetes/ingress` has no forward-auth annotation at all, only `basic-auth` and mTLS; and a session cookie shared across `*.<domain>` would be presented to every tenant's instance, which defeats the isolation this module builds.

## Bootstrap without an Enterprise licence

Langfuse's project-management API is gated behind the `admin-api` entitlement, which needs self-hosted Enterprise. **`LANGFUSE_INIT_*` is not gated.** `web/src/initialize.ts` upserts an organisation, a project, an API keypair and, optionally, a user with `OWNER` membership, with no entitlement check on any of them, and it accepts a **predefined keypair** — so Terraform generates the keys and hands them to the caller instead of a human reading them out of a UI.

`LANGFUSE_INIT_ORG_ID` is the trigger. With it unset, Langfuse logs a warning naming every other init variable and ignores all of them. The whole thing is `upsert`-based and therefore idempotent: a restart changes nothing.

The module delivers the values through `langfuse.additionalEnv`, with the project secret key and the user password as `secretKeyRef` entries.

**Use the init user for seeding only, and usually not at all.** `LANGFUSE_INIT_USER_EMAIL` and `LANGFUSE_INIT_USER_PASSWORD` create a *password* user, which cannot log in once `disable_username_password` is on. With an identity provider configured, leave both unset and let the human owner arrive through SSO and `LANGFUSE_DEFAULT_ORG_ROLE`. The variables are optional, and `var.oidc` validates that at least one login path exists.

### Two v4 additions

`initialize.ts` in v4 also reads `LANGFUSE_INIT_ORG_CLOUD_PLAN` and `LANGFUSE_INIT_PROJECT_RETENTION`. The retention one is entitlement-gated behind `data-retention` and is silently dropped without it. Neither affects the four objects this module relies on, and the module sets neither.

## Migrations run on every pod start

Both entrypoints run `prisma migrate deploy` and then the ClickHouse `migrate up` before the process starts, on **every** pod start of **every** replica. The ClickHouse migrations are `ON CLUSTER` DDL, which goes through one distributed DDL queue for the whole cluster.

With a handful of tenants this is fine. Above that, several tenants restarting or upgrading at once contend for that single queue, and pods time out waiting for a distributed DDL that another tenant's pod is holding. Turn `var.clickhouse_auto_migrate` and `var.postgres_auto_migrate` off then, and run the migrations once out of band before rolling the instances.

## Sizing

The chart sets `resources: {}` for both the web and the worker deployment, so without these values the pods run unbounded.

| | Request | Limit | Production target |
|---|---|---|---|
| `langfuse.web` | `100m` / `512Mi` | `500m` / `1Gi` | `500m` / `2Gi` |
| `langfuse.worker` | `100m` / `384Mi` | `500m` / `768Mi` | `500m` / `2Gi` |

The module derives `NODE_OPTIONS=--max-old-space-size` from each memory limit at 75% — `768` for the web pod and `576` for the worker with the defaults above. Node sizes its old space from the host's memory rather than from the cgroup limit, so without that flag the heap grows past the container limit and the kernel kills the pod instead of the garbage collector running. Change a memory limit and the flag follows.

## Wiring a LiteLLM gateway to this instance

The `base_url`, `project_public_key` and `project_secret_key` outputs are everything a LiteLLM gateway needs. Set them on the gateway as:

```
LANGFUSE_OTEL_HOST   = <base_url>
LANGFUSE_PUBLIC_KEY  = <project_public_key>
LANGFUSE_SECRET_KEY  = <project_secret_key>
```

**Set `LANGFUSE_OTEL_HOST`, not only `LANGFUSE_HOST`.** LiteLLM's `langfuse_otel` callback preset resolves the host as `LANGFUSE_OTEL_HOST` first and `LANGFUSE_HOST` second, then appends `/api/public/otel`. Two things follow:

- With **neither** set, LiteLLM silently exports to `https://us.cloud.langfuse.com/api/public/otel` — the public cloud endpoint. Traces leave the cluster and no error is raised.
- The `LANGFUSE_HOST` fallback is recent. LiteLLM releases before roughly v1.85.0 read `LANGFUSE_OTEL_HOST` only, so `LANGFUSE_HOST` on its own also lands on the cloud endpoint there. `modules/ai/litellm` pins chart 1.96.2, which does have the fallback, but `LANGFUSE_OTEL_HOST` is the name that works on every version.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.38 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.langfuse](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_secret_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Version of the langfuse chart from https://langfuse.github.io/langfuse-k8s. This is a classic Helm repository, not an OCI registry. | `string` | `"1.5.41"` | no |
| <a name="input_clickhouse_auto_migrate"></a> [clickhouse\_auto\_migrate](#input\_clickhouse\_auto\_migrate) | Run the ClickHouse `migrate up` on every web pod start. Turn it off above a handful of tenants and run the migrations once out of band: the statements are ON CLUSTER DDL, and several tenants upgrading at once contend for one distributed DDL queue. | `bool` | `true` | no |
| <a name="input_clickhouse_cluster_enabled"></a> [clickhouse\_cluster\_enabled](#input\_clickhouse\_cluster\_enabled) | Run the ClickHouse DDL with ON CLUSTER. Keep it on for the operator-managed cluster, which is a real cluster named 'default' even with a single replica. Turn it off only for a standalone ClickHouse with no Keeper. | `bool` | `true` | no |
| <a name="input_clickhouse_database"></a> [clickhouse\_database](#input\_clickhouse\_database) | Name of this tenant's ClickHouse database. It has to exist before the first apply: golang-migrate creates the tables inside it and never creates a database. | `string` | n/a | yes |
| <a name="input_clickhouse_host"></a> [clickhouse\_host](#input\_clickhouse\_host) | Fully qualified hostname of the shared ClickHouse cluster, without a scheme. Take it from the `host` output of modules/ai/clickhouse. | `string` | n/a | yes |
| <a name="input_clickhouse_http_port"></a> [clickhouse\_http\_port](#input\_clickhouse\_http\_port) | HTTP port of ClickHouse. Langfuse reads and writes trace data over it. | `number` | `8123` | no |
| <a name="input_clickhouse_native_port"></a> [clickhouse\_native\_port](#input\_clickhouse\_native\_port) | Native protocol port of ClickHouse. The golang-migrate schema migrations use it. | `number` | `9000` | no |
| <a name="input_clickhouse_password"></a> [clickhouse\_password](#input\_clickhouse\_password) | Password of the ClickHouse user. Avoid '&', '=', '#', '?', '%', '+', '@' and spaces: the migration script puts the value into a query string without encoding it. | `string` | n/a | yes |
| <a name="input_clickhouse_username"></a> [clickhouse\_username](#input\_clickhouse\_username) | ClickHouse user Langfuse connects as. It needs SELECT, INSERT, CREATE, DROP TABLE, ALTER UPDATE, ALTER DELETE and ALTER DROP INDEX on its own database, and nothing beyond it. | `string` | n/a | yes |
| <a name="input_default_org_role"></a> [default\_org\_role](#input\_default\_org\_role) | Role every user who logs in receives in this tenant's organisation. Langfuse upserts the<br/>membership on first login and on every later login, and the upsert never overwrites a role a<br/>user already has.<br/><br/>This removes member synchronisation from the picture: no group mapping and no SCIM. Set `NONE`<br/>to hand out a membership that grants nothing, which is the way to turn auto-join off while<br/>keeping the instance usable for users who were added by hand. | `string` | `"MEMBER"` | no |
| <a name="input_disable_username_password"></a> [disable\_username\_password](#input\_disable\_username\_password) | Turn off username and password login, so only the OIDC provider remains. Null turns it on whenever var.oidc is set. Never set it to true without an identity provider: nobody could log in. | `bool` | `null` | no |
| <a name="input_encryption_key"></a> [encryption\_key](#input\_encryption\_key) | Key Langfuse encrypts secrets at rest with, in this tenant's Postgres database. Must be 256 bits, which is 64 hex characters. Generate one with `openssl rand -hex 32`. It must be unique per tenant, because it is the only thing separating one tenant's stored credentials from another's. | `string` | n/a | yes |
| <a name="input_helm_timeout"></a> [helm\_timeout](#input\_helm\_timeout) | Seconds to wait for the Helm release to become ready. Every web pod runs the Postgres and the ClickHouse migrations before it answers its readiness probe, so the first install takes part of this budget. | `number` | `900` | no |
| <a name="input_hostname"></a> [hostname](#input\_hostname) | Canonical hostname of this tenant's Langfuse instance, without a scheme. The module derives NEXTAUTH\_URL and the Ingress rule from it. | `string` | n/a | yes |
| <a name="input_image_tag"></a> [image\_tag](#input\_image\_tag) | Tag of the langfuse/langfuse and langfuse/langfuse-worker images. It has to name a concrete v4<br/>release, because the chart's own appVersion still points at v3.<br/><br/>Do not use the floating `"4"` tag. It moves whenever Langfuse publishes a v4 release, so two<br/>pods of the same Deployment can end up on two different builds, a `helm upgrade` that changes<br/>nothing still rolls the Deployment, and a regression cannot be rolled back by reverting the<br/>Terraform change. Pin a full version and raise it deliberately. | `string` | `"4.10.0"` | no |
| <a name="input_ingress_annotations"></a> [ingress\_annotations](#input\_ingress\_annotations) | Annotations on the Ingress. Set `cert-manager.io/cluster-issuer` here when the instance needs a certificate of its own instead of the controller's wildcard certificate. | `map(string)` | `{}` | no |
| <a name="input_ingress_class_name"></a> [ingress\_class\_name](#input\_ingress\_class\_name) | Name of the IngressClass that serves this instance. It has to match the controller modules/kubernetes/ingress installs. | `string` | `"haproxy"` | no |
| <a name="input_ingress_enabled"></a> [ingress\_enabled](#input\_ingress\_enabled) | Create an Ingress for var.hostname. Turn it off when the instance is reached in-cluster only, and set var.public\_url accordingly. | `bool` | `true` | no |
| <a name="input_ingress_tls_secret_name"></a> [ingress\_tls\_secret\_name](#input\_ingress\_tls\_secret\_name) | Name of the secret holding the TLS certificate for var.hostname. Null leaves the Ingress without a tls block, which is correct when the ingress controller serves a wildcard certificate as its default. | `string` | `null` | no |
| <a name="input_init_org_id"></a> [init\_org\_id](#input\_init\_org\_id) | Identifier of the organisation Langfuse creates on startup. It is the trigger of the whole bootstrap: with it unset, every other init value is silently ignored. | `string` | n/a | yes |
| <a name="input_init_org_name"></a> [init\_org\_name](#input\_init\_org\_name) | Display name of the organisation. | `string` | n/a | yes |
| <a name="input_init_project_id"></a> [init\_project\_id](#input\_init\_project\_id) | Identifier of the project Langfuse creates inside the organisation. Traces belong to a project, and the API keypair below is scoped to it. | `string` | n/a | yes |
| <a name="input_init_project_name"></a> [init\_project\_name](#input\_init\_project\_name) | Display name of the project. | `string` | n/a | yes |
| <a name="input_init_project_public_key"></a> [init\_project\_public\_key](#input\_init\_project\_public\_key) | Public key of the API keypair Langfuse creates for the project. Langfuse's own generator produces 'pk-lf-<uuid>', and clients expect that shape. | `string` | n/a | yes |
| <a name="input_init_project_secret_key"></a> [init\_project\_secret\_key](#input\_init\_project\_secret\_key) | Secret key of the API keypair Langfuse creates for the project. Langfuse's own generator produces 'sk-lf-<uuid>', and clients expect that shape. | `string` | n/a | yes |
| <a name="input_init_user_email"></a> [init\_user\_email](#input\_init\_user\_email) | Email address of a first user with a password, given OWNER membership in the organisation. Leave it null when var.oidc is set: a password user cannot log in once username and password login is off. | `string` | `null` | no |
| <a name="input_init_user_name"></a> [init\_user\_name](#input\_init\_user\_name) | Display name of the first user. Null lets Langfuse name it 'Provisioned User'. Only used when init\_user\_email and init\_user\_password are both set. | `string` | `null` | no |
| <a name="input_init_user_password"></a> [init\_user\_password](#input\_init\_user\_password) | Password of the first user. Langfuse only sets it while creating the user, so changing this value later does not reset the password. Both init\_user\_email and init\_user\_password have to be set, or neither. | `string` | `null` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace this tenant's Langfuse instance runs in. The module creates it. Give every tenant a namespace of its own. | `string` | `"langfuse"` | no |
| <a name="input_nextauth_secret"></a> [nextauth\_secret](#input\_nextauth\_secret) | Secret NextAuth signs its JWTs and hashes email verification tokens with. It must be unique per tenant, otherwise a session token minted for one tenant is accepted by another. Generate one with `openssl rand -base64 32`. | `string` | n/a | yes |
| <a name="input_oidc"></a> [oidc](#input\_oidc) | OIDC identity provider this tenant's users log in through. Null leaves the instance on username<br/>and password login, which then needs `init_user_email` and `init_user_password`.<br/><br/>Self-hosted SSO is free in Langfuse. It carries no entitlement, so it works without an<br/>Enterprise licence.<br/><br/>- `issuer_url`: discovery base URL of the provider, for example<br/>  `https://idp.example.com/realms/ai`. Langfuse reads `<issuer_url>/.well-known/openid-configuration`.<br/>- `client_id` and `client_secret`: credentials of the OIDC client.<br/>- `display_name`: label on the login button. The provider is not registered without it.<br/>- `scopes`: space-separated scope list. The default covers what Langfuse needs.<br/>- `allow_account_linking`: link an OIDC login to an existing user with the same email address.<br/>  Turn it on when a user already exists from a password login or from another provider.<br/><br/>Register the callback URL `<public_url>/api/auth/callback/custom` at the provider.<br/><br/>Give every tenant an OIDC client of its own and assign only that tenant's members to it. See the<br/>access control note in the module README: with auto-join on, everyone the provider authenticates<br/>becomes a member of this tenant's organisation. | <pre>object({<br/>    issuer_url            = string<br/>    client_id             = string<br/>    client_secret         = string<br/>    display_name          = optional(string, "Single Sign-On")<br/>    scopes                = optional(string, "openid email profile")<br/>    allow_account_linking = optional(bool, true)<br/>  })</pre> | `null` | no |
| <a name="input_postgres_args"></a> [postgres\_args](#input\_postgres\_args) | Query string appended to the Postgres connection URL, without the leading '?'. Managed Postgres offerings terminate TLS, so requiring it is the safe default. A server without TLS needs 'sslmode=prefer' or 'sslmode=disable'. The module appends `connection_limit` from postgres\_connection\_limit, and `pool_timeout` belongs here when the default of 10 seconds is too short for the pinned pool. | `string` | `"sslmode=require"` | no |
| <a name="input_postgres_auto_migrate"></a> [postgres\_auto\_migrate](#input\_postgres\_auto\_migrate) | Run `prisma migrate deploy` on every web pod start. Turn it off above a handful of tenants and run the migrations once out of band, because every pod of every tenant runs them on every restart. | `bool` | `true` | no |
| <a name="input_postgres_connection_limit"></a> [postgres\_connection\_limit](#input\_postgres\_connection\_limit) | Maximum number of Postgres connections one Langfuse pod opens. The module appends it to the<br/>connection URL as `connection_limit`, next to `postgres_args`.<br/><br/>Without the parameter Prisma sizes the pool as `physical cores × 2 + 1` read from the node, not<br/>from the pod's CPU limit, so a pod takes 33 connections on a 16-core node and a different number<br/>after it is rescheduled onto a node with more cores.<br/><br/>This module runs once per tenant against a shared instance, so the platform's budget is<br/>`tenants × pods per tenant × connection_limit + 15 ≤ max_connections`. STACKIT PostgreSQL Flex<br/>fixes `max_connections` per flavour and reserves 15 of them, so the default of 5 is what keeps a<br/>4 vCPU / 32 GiB instance at roughly 34 tenants with four pods each. | `number` | `5` | no |
| <a name="input_postgres_database"></a> [postgres\_database](#input\_postgres\_database) | Name of this tenant's Postgres database. It has to exist before the first apply, together with its owner user — Prisma creates the tables inside it, not the database itself. | `string` | n/a | yes |
| <a name="input_postgres_direct_url"></a> [postgres\_direct\_url](#input\_postgres\_direct\_url) | Full connection URL the schema migrations run against, used when the normal connection goes through a pooler or when migrations need a user with longer timeouts. The module appends `connection_limit` from postgres\_direct\_url\_connection\_limit to it. Null makes the migrations reuse the normal connection, which already carries the pinned pool. | `string` | `null` | no |
| <a name="input_postgres_direct_url_connection_limit"></a> [postgres\_direct\_url\_connection\_limit](#input\_postgres\_direct\_url\_connection\_limit) | Maximum number of Postgres connections the migration connection opens, appended to postgres\_direct\_url as `connection_limit`. Two covers the `prisma db execute` and the `prisma migrate deploy` the web entrypoint runs one after the other, each of which opens a single connection. Only used when postgres\_direct\_url is set. | `number` | `2` | no |
| <a name="input_postgres_host"></a> [postgres\_host](#input\_postgres\_host) | Hostname of the shared Postgres server. Langfuse keeps its relational data — organisations, projects, users, prompts and encrypted secrets — here. | `string` | n/a | yes |
| <a name="input_postgres_password"></a> [postgres\_password](#input\_postgres\_password) | Password of the Postgres user. Use only characters that are safe in a URL: Langfuse builds its connection URL by string substitution and does not percent-encode the value. | `string` | n/a | yes |
| <a name="input_postgres_port"></a> [postgres\_port](#input\_postgres\_port) | Port of the Postgres server. The module appends it to the host, because Langfuse builds its connection URL from the host only and ignores the port variable the chart sets. | `number` | `5432` | no |
| <a name="input_postgres_username"></a> [postgres\_username](#input\_postgres\_username) | User Langfuse connects as. It has to own this tenant's database, because `prisma migrate deploy` creates and alters tables under it on every web pod start. | `string` | n/a | yes |
| <a name="input_public_url"></a> [public\_url](#input\_public\_url) | Full canonical URL of this tenant's Langfuse instance, used as NEXTAUTH\_URL. Null derives 'https://<hostname>'. | `string` | `null` | no |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | Helm release name of this tenant's Langfuse instance. | `string` | `"langfuse"` | no |
| <a name="input_s3_access_key_id"></a> [s3\_access\_key\_id](#input\_s3\_access\_key\_id) | Access key id of the credential scoped to this tenant's bucket. | `string` | n/a | yes |
| <a name="input_s3_batch_export_prefix"></a> [s3\_batch\_export\_prefix](#input\_s3\_batch\_export\_prefix) | Prefix inside the bucket for batch exports. Keep the trailing slash. | `string` | `"exports/"` | no |
| <a name="input_s3_bucket"></a> [s3\_bucket](#input\_s3\_bucket) | Bucket this tenant's event uploads, batch exports and media uploads go to. Give every tenant a bucket of its own. | `string` | n/a | yes |
| <a name="input_s3_endpoint"></a> [s3\_endpoint](#input\_s3\_endpoint) | Endpoint URL of the object storage, including the scheme. | `string` | n/a | yes |
| <a name="input_s3_event_upload_prefix"></a> [s3\_event\_upload\_prefix](#input\_s3\_event\_upload\_prefix) | Prefix inside the bucket for raw ingestion events. Keep the trailing slash. | `string` | `"events/"` | no |
| <a name="input_s3_force_path_style"></a> [s3\_force\_path\_style](#input\_s3\_force\_path\_style) | Address the bucket as a path on the endpoint instead of as a subdomain. Required for MinIO and for most S3-compatible object storage. | `bool` | `true` | no |
| <a name="input_s3_media_upload_prefix"></a> [s3\_media\_upload\_prefix](#input\_s3\_media\_upload\_prefix) | Prefix inside the bucket for media uploads. Keep the trailing slash. | `string` | `"media/"` | no |
| <a name="input_s3_region"></a> [s3\_region](#input\_s3\_region) | Region of the bucket. 'auto' works for S3-compatible object storage that has no region concept. | `string` | `"auto"` | no |
| <a name="input_s3_secret_access_key"></a> [s3\_secret\_access\_key](#input\_s3\_secret\_access\_key) | Secret access key of the credential scoped to this tenant's bucket. | `string` | n/a | yes |
| <a name="input_salt"></a> [salt](#input\_salt) | Salt Langfuse hashes API keys with. It must be unique per tenant, because two tenants sharing a salt share the hash space of their API keys. Changing it later invalidates every API key of the tenant. | `string` | n/a | yes |
| <a name="input_telemetry_enabled"></a> [telemetry\_enabled](#input\_telemetry\_enabled) | Report basic usage statistics to Langfuse. The chart turns this on by default; a self-hosted tenant instance usually should not phone home. | `bool` | `false` | no |
| <a name="input_valkey_database"></a> [valkey\_database](#input\_valkey\_database) | Valkey database index of this tenant. It is a hard namespace that no application bug can cross, so give every tenant an index of its own. A stock Valkey serves indices 0 to 15. | `number` | n/a | yes |
| <a name="input_valkey_host"></a> [valkey\_host](#input\_valkey\_host) | Hostname of the shared Valkey or Redis instance. Langfuse uses it as the BullMQ queue backend, the cache and the rate limit store. | `string` | n/a | yes |
| <a name="input_valkey_key_prefix"></a> [valkey\_key\_prefix](#input\_valkey\_key\_prefix) | Prefix Langfuse puts in front of every Valkey key and every BullMQ queue name for this tenant,<br/>for example `tenant-a:`. Give every tenant a prefix of its own.<br/><br/>Set it together with `valkey_database`, not instead of it. The index is a hard namespace that no<br/>application bug can cross; the prefix survives a later move to Redis Cluster, where indices<br/>vanish because a cluster only has database 0.<br/><br/>Langfuse needs at least app version 3.157.0 for this to work. The variable existed before, but<br/>BullMQ ignored it until langfuse/langfuse#11898 merged on 2026-03-06. | `string` | n/a | yes |
| <a name="input_valkey_password"></a> [valkey\_password](#input\_valkey\_password) | Password of the Valkey instance. Use only characters that are safe in a URL, because the chart substitutes the value into the connection URL without encoding it. | `string` | n/a | yes |
| <a name="input_valkey_port"></a> [valkey\_port](#input\_valkey\_port) | Port of the Valkey instance. | `number` | `6379` | no |
| <a name="input_valkey_username"></a> [valkey\_username](#input\_valkey\_username) | Username for Valkey authentication. Null omits the username from the connection string, which is what a Valkey without ACLs expects. | `string` | `"default"` | no |
| <a name="input_web_replicas"></a> [web\_replicas](#input\_web\_replicas) | Number of Langfuse web pods. The default of 1 is sized for a demonstration and gives no redundancy: every restart interrupts the UI and the ingestion API. | `number` | `1` | no |
| <a name="input_web_resources"></a> [web\_resources](#input\_web\_resources) | Resource requests and limits of the Langfuse web pods. The default is sized for a demonstration<br/>and a production consumer has to raise it.<br/><br/>The chart sets `resources: {}` for the web deployment, so the pods run unbounded without these<br/>values. The web pod serves the UI and the ingestion API and runs both migrations on start, which<br/>is the peak of its memory use. Production wants `500m` CPU and `2Gi` of memory.<br/><br/>The module derives `NODE_OPTIONS=--max-old-space-size` from the memory limit at roughly 75%, so<br/>Node runs a garbage collection before the cgroup limit is reached instead of being OOMKilled. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "500m",<br/>    "memory": "1Gi"<br/>  },<br/>  "requests": {<br/>    "cpu": "100m",<br/>    "memory": "512Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_worker_replicas"></a> [worker\_replicas](#input\_worker\_replicas) | Number of Langfuse worker pods. The default of 1 is sized for a demonstration. Raise it when the ingestion queue backs up. | `number` | `1` | no |
| <a name="input_worker_resources"></a> [worker\_resources](#input\_worker\_resources) | Resource requests and limits of the Langfuse worker pods. The default is sized for a<br/>demonstration and a production consumer has to raise it.<br/><br/>The chart sets `resources: {}` for the worker deployment as well. The worker drains the BullMQ<br/>queues and batches writes into ClickHouse, so its memory grows with the batch size rather than<br/>with the number of users. Production wants `500m` CPU and `2Gi` of memory.<br/><br/>The module derives `NODE_OPTIONS=--max-old-space-size` from the memory limit at roughly 75%. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "500m",<br/>    "memory": "768Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "100m",<br/>    "memory": "384Mi"<br/>  }<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_base_url"></a> [base\_url](#output\_base\_url) | In-cluster base URL of this Langfuse instance, with the scheme and the port. Set it as LANGFUSE\_OTEL\_HOST on a LiteLLM gateway that traces into this instance. |
| <a name="output_host"></a> [host](#output\_host) | Fully qualified in-cluster hostname of the Langfuse web Service. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Namespace this tenant's Langfuse instance runs in. |
| <a name="output_oidc_callback_url"></a> [oidc\_callback\_url](#output\_oidc\_callback\_url) | Callback URL to register at the OIDC provider for this tenant's client. Null when var.oidc is not set. |
| <a name="output_port"></a> [port](#output\_port) | Port the Langfuse web Service listens on. |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | Identifier of the project Langfuse created. Traces belong to it and the API keypair is scoped to it. |
| <a name="output_project_public_key"></a> [project\_public\_key](#output\_project\_public\_key) | Public key of the project API keypair. A tracing client sends it together with the secret key as basic auth, for example as LANGFUSE\_PUBLIC\_KEY on a LiteLLM gateway. |
| <a name="output_project_secret_key"></a> [project\_secret\_key](#output\_project\_secret\_key) | Secret key of the project API keypair. A tracing client sends it together with the public key as basic auth, for example as LANGFUSE\_SECRET\_KEY on a LiteLLM gateway. |
| <a name="output_public_url"></a> [public\_url](#output\_public\_url) | Canonical external URL of this Langfuse instance. It is what NEXTAUTH\_URL is set to and what a browser opens. |
| <a name="output_release_name"></a> [release\_name](#output\_release\_name) | Helm release name of this tenant's Langfuse instance. |
| <a name="output_web_service_name"></a> [web\_service\_name](#output\_web\_service\_name) | Name of the Service in front of the Langfuse web pods. |
<!-- END_TF_DOCS -->
