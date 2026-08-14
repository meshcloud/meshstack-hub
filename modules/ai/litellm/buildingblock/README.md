---
name: LiteLLM AI Gateway
supportedPlatforms:
  - kubernetes
description: Installs the LiteLLM gateway into a Kubernetes namespace and registers OpenAI-compatible model endpoints behind one API, with virtual keys, teams, budgets and spend tracking backed by Postgres, and optional OIDC single sign-on for the admin console.
# The cluster credentials, the database connection and the upstream model credentials all arrive
# as inputs, so there is nothing to set up on the cloud side before this module runs.
requiresBackplane: false
---

# LiteLLM AI Gateway Building Block

The platform team installs the LiteLLM gateway into a Kubernetes namespace with this module. The gateway puts one OpenAI-compatible API in front of the model endpoints the platform team registers, and it issues virtual keys with their own budgets and rate limits, so an application team never sees the credential of an upstream provider.

This documentation is intended as a reference for cloud foundation or platform engineers using this module.

## Sourced, not ordered

There is no `meshstack_integration.tf` and no `backplane/`. The `ai-platform` reference architecture sources `buildingblock/` from its own building block, and a foundation can source it from a Terragrunt unit. Application teams do not order this module; they order a virtual key from a separate building block that talks to the gateway this module installs.

## The chart

| | |
|---|---|
| Chart | `litellm-helm` |
| Reference | `oci://ghcr.io/berriai/litellm-helm` |
| Pinned version | `1.96.2` (`var.chart_version`) |
| Source | [`helm/litellm-helm/`](https://github.com/BerriAI/litellm/tree/main/helm/litellm-helm) in `BerriAI/litellm` |
| Prerequisites | Kubernetes 1.21+, Helm 3.8.0+ |

Three details about this chart cost time when you meet them for the first time:

- **The chart is published to GHCR as an OCI artifact only.** There is no classic Helm repository to add. The helm provider takes the registry and the path prefix as `repository` and the chart name on its own as `chart`, which is why `main.tf` reads `repository = "oci://ghcr.io/berriai"` and `chart = "litellm-helm"`.
- **`Chart.yaml` on the repository's main branch lies about the version.** It reads a much lower number, because the release pipeline overwrites the field while publishing. Pick the version from the [GHCR tag list](https://github.com/BerriAI/litellm/pkgs/container/litellm-helm) instead.
- **A second, newer chart lives at `helm/litellm/`.** That one splits the proxy into microservices. This module uses the monolithic `litellm-helm` chart. The old `deploy/charts/` path from older documentation no longer exists.

## Postgres is required

Virtual keys, teams, budgets and spend tracking all live in Postgres. Without a database the gateway is a stateless proxy and none of those endpoints work, which is the whole reason to run it here. The module therefore takes the connection as mandatory inputs: `postgres_host`, `postgres_port`, `postgres_database`, `postgres_username` and `postgres_password`. Any Postgres works. On STACKIT a PostgreSQL Flex instance fits; in another foundation an operator-managed cluster in the same Kubernetes cluster fits just as well.

The chart bundles a Bitnami postgresql subchart under `db.deployStandalone`, and that switch defaults to **true**. This module sets it to `false` and sets `db.useExisting = true` instead. The chart's own README recommends the same: those images no longer receive updates and the subchart is pinned to `bitnamilegacy/postgresql`.

Four points to keep in mind:

- **The database has to exist before the first apply.** The migration Job creates the tables inside it, not the database itself.
- **The user needs rights to create and alter tables**, because the migration Job runs the schema migrations under it.
- **The password has to be safe in a URL.** The chart builds the connection URL from `$(DATABASE_USERNAME)` and `$(DATABASE_PASSWORD)`, which Kubernetes substitutes verbatim and does not URL-encode, so a password containing `:`, `@`, `/` or `?` breaks the URL.
- **`postgres_ssl_mode` defaults to `require`.** A managed Postgres terminates TLS and accepts this. A server without TLS needs `prefer` or `disable`.

The chart's default connection URL carries no port, so the module writes its own `db.url` with `postgres_port`, the sslmode parameter and the pinned `connection_limit` in it. The credentials stay in a Kubernetes Secret and never appear in the pod spec, because the URL keeps the `$(…)` references that Kubernetes resolves from the environment.

### The Prisma migration Job

The chart runs the schema migrations in a Prisma Job (`migrationJob.enabled`, default true). Its default annotations address ArgoCD, which means nothing to a Terraform-driven install: the Job would be applied together with the Deployment, and the pods would restart until the schema exists, because the proxy itself runs with `DISABLE_SCHEMA_UPDATE=true` whenever the Job is enabled.

This module therefore turns the Helm hook on and the ArgoCD annotations off. The Job runs as a `pre-install,pre-upgrade` hook, Helm waits for it to finish, and only then creates the Deployment. Two consequences follow:

- A failing migration fails the whole `helm_release`, which is what you want — the alternative is a pod crash loop that Terraform reports as a timeout.
- The Job needs its share of `helm_timeout`. The default of 600 seconds covers a migration and a rollout together.

### The connection pool is pinned, and by two settings

**Prisma sizes its connection pool as `physical cores × 2 + 1` when the connection URL names no `connection_limit`**, and it counts the physical cores of the *node*, not the pod's CPU limit. [prisma-engines#4341](https://github.com/prisma/prisma-engines/issues/4341) records that as an oversight and was closed without a fix. A pod with a `100m` CPU limit therefore takes 33 connections on a 16-core node, and a different number after it is rescheduled onto a node with a different core count.

A managed Postgres caps `max_connections` by the shape you bought. STACKIT PostgreSQL Flex fixes it per flavour — 195 on 4 vCPU / 8 GiB, 785 on 4 vCPU / 32 GiB — reserves 15 for its own processes and exposes no parameter group in the API, the SDK or the Terraform provider. The pool has to be pinned on the client side, because there is no server-side lever.

`var.postgres_connection_limit` pins it, and the module writes it in two places:

| Where | What it binds |
|---|---|
| `connection_limit` on `db.url` | The Prisma migration Job, and anything else that reads `DATABASE_URL` as it stands. |
| `general_settings.database_connection_pool_limit` | The running proxy. |

Both are needed. **The proxy rewrites `DATABASE_URL` on startup** and replaces `connection_limit` with `general_settings.database_connection_pool_limit`, so the URL parameter alone does not bind the pods. The module writes the same number into both, and the pool is then the same whichever path sets it.

The default is `10`, which is LiteLLM's own default, so pinning the value changes nothing at runtime. The gateway is deployed once for the whole platform, so it costs `replica_count × postgres_connection_limit` connections in total — 10 at the defaults. Budget it against the instance like this:

```
pods per tenant × connection_limit × tenants  +  15 reserved  ≤  max_connections
```

The gateway is one tenant of that sum. Everything else on the instance, a Langfuse instance per tenant above all, competes for the same ceiling. `modules/stackit/postgresflex` carries the [per-flavour table and the budget](../../../stackit/postgresflex/buildingblock/README.md#how-many-connections-one-instance-carries).

`pool_timeout` is the companion parameter: a request that finds no free connection waits that long and then fails with `P2024`. LiteLLM sets it from `general_settings.database_connection_pool_timeout` and defaults to 60 seconds, which is generous, so this module leaves it alone.

## Redis

`redis.enabled` defaults to false in the chart and the module keeps the bundled Redis subchart off, for the same reason as the bundled Postgres. Redis is the coordination store of the gateway: cross-pod rate limits, spend tracking and the pod lock manager.

| Deployment | Redis |
|---|---|
| `replica_count = 1` | Not needed. One pod counts everything in its own memory and the counts are correct. |
| `replica_count > 1` | Required as soon as you enforce budgets or rate limits. Without it every pod counts on its own, so a team with three pods in front of it can spend up to three times its budget before anything is refused. |

Set `redis_host`, and optionally `redis_port` and `redis_password`, to point at an existing Redis. The module puts those values into the same secret as the model credentials and writes a `general_settings.coordination_redis` block into the proxy config that reads them from the environment.

## Registering model backends

`var.model_backends` is a map keyed by the alias a caller puts in the `model` field of a request. Each entry carries the name of the model at the upstream provider and the base URL of its OpenAI-compatible endpoint. The credentials live in `var.model_backend_api_keys`, keyed the same way and marked sensitive, so a plan stays readable and only the credentials are hidden.

The module renders this into the chart's `proxy_config.model_list`:

```yaml
model_list:
  - model_name: chat-large
    litellm_params:
      model: openai/neuralmagic/Mistral-Small-3.1-24B-Instruct-2503-FP8-dynamic
      api_base: https://api.openai-compat.model-serving.eu01.onstackit.cloud/v1
      api_key: os.environ/LITELLM_API_KEY_CHAT_LARGE
```

Two traps are worth naming, because both produce errors that point somewhere else:

- **The `openai/` prefix on `model` selects the OpenAI-compatible driver.** Without it LiteLLM tries to guess the provider from the model name and reaches for a different driver. The module adds the prefix, so `var.model_backends` carries the bare upstream model name.
- **`api_base` has to end with `/v1`.** LiteLLM appends the route to this URL, so an endpoint without the suffix answers "Not Found" on every call. The module rejects an `api_base` without it at plan time.

Each alias becomes an environment variable named `LITELLM_API_KEY_<ALIAS>`, with every character outside `[A-Za-z0-9]` replaced by an underscore. The module writes those variables into a Kubernetes Secret and lists it under `environmentSecrets`, which the chart exports into the pods with `envFrom`. That is what the `os.environ/…` references in the proxy config resolve against. Two aliases that would collapse to the same variable name are rejected at plan time, because they would otherwise share one credential.

Several aliases can share one upstream endpoint and one credential. Repeat the value in `model_backend_api_keys` for each alias.

## The master key

`var.master_key` is the root credential of the gateway. It authenticates every call to the `/key` and `/team` endpoints and works as a virtual key itself. LiteLLM rejects a key that does not start with `sk-`, so the module validates the prefix.

The module writes the key into a Kubernetes Secret and points the chart at it with `masterkeySecretName`. Without that the chart generates a key of its own on every install, which no caller knows and which changes whenever the secret is recreated.

## The admin console and single sign-on

The console at `<public_url>/ui` belongs to the platform team. Tenants never open it: they hold a virtual key and call the API. This module deploys **one** gateway for the whole platform, so there is one console for everybody who administers it.

`var.oidc` turns on the proxy's native generic OIDC provider. Two things this module deliberately does not offer:

- **No static `UI_USERNAME` and `UI_PASSWORD` fallback.** A shared password on a console that hands out the powers of the master key is not access control. Either an identity provider decides who gets in, or nobody logs in.
- **No console at all when `var.oidc` is null.** The gateway still works in full — every tenant reaches it with a virtual key — so a foundation without an identity provider gets a working gateway and no login page.

Native SSO is free in the open-source proxy up to five users. The five are the subject of [the next section](#the-console-holds-five-users-platform-wide), and you have to read it before you hand the console to a sixth person.

### What the module writes onto the pods

`var.oidc` and `var.public_url` become plain environment variables on the proxy container, apart from the client secret, which travels in a Kubernetes Secret listed under `environmentSecrets` — the same path the model credentials take.

| Environment variable | Set from | Default in the proxy at v1.96.2 |
|---|---|---|
| `GENERIC_CLIENT_ID` | `oidc.client_id` | none; its presence is what selects the generic provider |
| `GENERIC_CLIENT_SECRET` | `oidc.client_secret`, through the secret | none; login fails without it |
| `GENERIC_AUTHORIZATION_ENDPOINT` | discovery, or `oidc.authorization_endpoint` | none; login fails without it |
| `GENERIC_TOKEN_ENDPOINT` | discovery, or `oidc.token_endpoint` | none; login fails without it |
| `GENERIC_USERINFO_ENDPOINT` | discovery, or `oidc.userinfo_endpoint` | none; login fails without it |
| `GENERIC_SCOPE` | `oidc.scopes` | `openid email profile` |
| `GENERIC_USER_ID_ATTRIBUTE` | `oidc.user_id_attribute`, `sub` by default | `preferred_username` |
| `GENERIC_USER_EMAIL_ATTRIBUTE` | `oidc.user_email_attribute` | `email` |
| `GENERIC_USER_DISPLAY_NAME_ATTRIBUTE` | `oidc.user_display_name_attribute` | `sub` |
| `GENERIC_USER_ROLE_ATTRIBUTE` | `oidc.user_role_attribute` | `role` |
| `PROXY_BASE_URL` | `var.public_url` | the base URL of the incoming request |
| `PROXY_LOGOUT_URL` | `oidc.logout_url` | none |
| `PROXY_ADMIN_ID` | `oidc.proxy_admin_id` | none |
| `ALLOWED_EMAIL_DOMAINS` | `oidc.allowed_email_domains`, joined with commas | none, so every authenticated user may log in |
| `AUTO_REDIRECT_UI_LOGIN_TO_SSO` | `oidc.auto_redirect_to_sso` | `false` |

A setting the caller leaves null is not written at all, so the proxy stays on its own default instead of receiving an empty string.

Three details are worth carrying in your head, because the documentation and the code disagree:

- **`GENERIC_USER_ID_ATTRIBUTE` defaults to `preferred_username` in the code**, while the documentation table says `sub`. This module pins `sub`. `preferred_username` is reassignable at most providers, and a reassignment produces a second row in the user table for the same person — which costs one of the five seats.
- **`GENERIC_USER_DISPLAY_NAME_ATTRIBUTE` defaults to `sub` in the code**, not to `display_name` as the documentation says. Set it to whichever claim carries a readable name, usually `name`, or the console shows opaque subject identifiers.
- **`ALLOWED_EMAIL_DOMAINS` matches the part after the `@` exactly.** There is no wildcard and no subdomain match, so `example.com` does not admit `mail.example.com`.

### One issuer in, three endpoints out

`modules/ai/langfuse` takes an issuer and reads the discovery document itself. The LiteLLM proxy does not: it reads the authorization, token and userinfo endpoints as three separate environment variables and fails the login when one of them is missing. This module closes that gap so both modules present the same `oidc` input — it reads `<issuer_url>/.well-known/openid-configuration` through the `http` data source and takes the three endpoints from there.

That request runs on **every plan**, which has a cost worth stating plainly: the identity provider has to answer the machine that runs Terraform, not only the pods in the cluster. An outage at the provider, or a provider reachable from inside the cluster only, fails a plan that has nothing to do with SSO — adding a model backend, for instance.

The way out is in `var.oidc`: set `authorization_endpoint`, `token_endpoint` and `userinfo_endpoint`, and the module creates no data source at all. Set one or two of them and discovery still runs for the rest, with the override winning. Prefer the three explicit endpoints in a foundation where the Terraform runner cannot reach the provider.

### The callback URL

Register `<public_url>/sso/callback` at the provider.

The proxy builds that URL from `PROXY_BASE_URL` joined with `SERVER_ROOT_PATH` and then `/sso/callback`. This module sets no `SERVER_ROOT_PATH`, so the short form holds.

`PROXY_BASE_URL` is not required by the code — it falls back to the base URL of the incoming request — but that fallback is the internal `http://` address of the pod behind a TLS-terminating Ingress, and the provider then rejects the redirect URI it receives. `var.public_url` is therefore mandatory whenever `var.oidc` is set, and the module rejects the pair at plan time.

### There is no claim discovery on the free tier

`/sso/debug/login`, the route the documentation offers for reading back the claims a provider returns, raises 403 without an Enterprise licence as soon as any SSO client id is configured. Take the claim names from the provider's own documentation or from its discovery document instead.

## The console holds five users, platform-wide

Read this section before you give a sixth person access to the console. Recovery from the failure it describes means a manual change in Postgres.

### A user is a row in the user table

Five is a limit on rows in `LiteLLM_UserTable`. It is **not** a limit on virtual keys, on teams, or on tenants. A platform with two hundred tenants and two thousand virtual keys can sit at zero users.

`_raise_if_sso_exceeds_free_user_limit` in `litellm/proxy/management_endpoints/ui_sso.py` counts them through `UserRepository.count_billable_users()`, which is every row in `LiteLLM_UserTable` minus the rows whose metadata marks them SCIM-inactive. The comparison is strictly "greater than five", so the table may hold five rows and not six.

Where rows come from, verified in the v1.96.2 source:

| Action | Rows it writes to `LiteLLM_UserTable` |
|---|---|
| `/key/generate`, so every virtual key a tenant receives | **none.** There is an explicit guard against creating a user |
| `/team/new` with `disable_auto_add_proxy_admin_to_teams: true` | **none** |
| `/team/new` without that setting | **one, ever.** Every caller that authenticates with the master key is identified as the same constant user id, `default_user_id`, so the row is written on the first team and reused afterwards |
| `/team/member_add` | one per member |
| `/user/new` | one per user |
| An SSO login | one per human |

With this module's defaults the only rows are the humans who log in to the console. `var.disable_auto_add_proxy_admin_to_teams` defaults to `true` and is what keeps `/team/new` at zero rows.

### The failure mode: the sixth login locks out everybody

The check runs at login **initiation** — `/sso/key/generate`, the route behind the login button — and not at the callback. Two consequences follow, and the second one is the expensive one:

- The refusal arrives as a 403 before the browser is ever sent to the identity provider, so the person sees an error on the gateway and not at their provider.
- The check looks at the table, not at the person. The sixth human's own login still passes it, because five rows are not more than five, and it writes the sixth row. **From that moment every login initiation fails, for all six of them.** Nobody who was working in the console yesterday can start a new session today.

Sessions already open keep working until they expire. That is the whole grace period.

The error message names the cause:

> You must be a LiteLLM Enterprise user to use SSO for more than 5 users. If you have a license please set `LITELLM_LICENSE` in your env. […] You are seeing this error message because You configured SSO […] in your env. Please unset it

### Operations that are forbidden here

Two API calls write one row per member into `LiteLLM_UserTable`, and each is one line of Terraform away:

- **`/team/member_add`**, which the `ncecere/litellm` provider exposes as `resource "litellm_team_member"` and `resource "litellm_team_member_add"`.
- **`/user/new`**, for which that provider has no resource at version 2.0.1, so it takes a direct API call or a newer provider version.

Neither belongs in this architecture, and no module in this repository creates either. A tenant needs no team membership and no user of its own: `modules/ai/model-access` creates a team and a virtual key, and the key alone carries the budget, the rate limit and the model allowance. A membership adds nothing a tenant can use and costs one of five seats.

**The provider makes the mistake easy, which is exactly why the rule needs writing down.** `litellm_team_member` sits next to `litellm_team` in the provider documentation and reads like the natural next resource to add. It is not. Review any change that introduces it, and reject it unless somebody has bought an Enterprise licence first.

### An Enterprise licence is out of scope

`LITELLM_LICENSE` lifts the limit — the check returns immediately for a premium user — and this architecture does not buy one. Five console users is therefore a fixed property of the platform and not a temporary state to grow out of. Plan the platform team's console access around it. A sixth administrator is a licensing decision, not a Terraform change.

## Notes for platform engineers

- **Providers.** `kubernetes`, `helm` and `http`. No cloud provider enters this module, so it runs on SKE, AKS and anything else that speaks the Kubernetes API. The `http` provider only reads the OIDC discovery document, and only when `var.oidc` is set without all three endpoint overrides.
- **Permissions.** The token in `var.token` needs to create a namespace, secrets and the workloads of the release in that namespace. Cluster-admin is not required; the chart installs no CRDs and no cluster-scoped RBAC.
- **The namespace belongs to the module.** It creates `var.namespace` and destroys it again, together with the secrets it wrote there.
- **Reachability.** The Service is a ClusterIP, so the gateway answers inside the cluster at the `api_base` output. Put an Ingress in front of it when callers live outside the cluster, and in any case when you turn on console SSO: the identity provider redirects a browser to `var.public_url`, which therefore has to resolve from outside.

## Usage

```hcl
module "litellm" {
  source = "github.com/meshcloud/meshstack-hub//modules/ai/litellm/buildingblock?ref=main"

  cluster_endpoint       = var.cluster_endpoint
  cluster_ca_certificate = var.cluster_ca_certificate
  token                  = var.token

  master_key = var.litellm_master_key

  postgres_host     = var.postgres_host
  postgres_database = "litellm"
  postgres_username = var.postgres_username
  postgres_password = var.postgres_password

  model_backends = {
    "chat-large" = {
      model    = "neuralmagic/Mistral-Small-3.1-24B-Instruct-2503-FP8-dynamic"
      api_base = "https://api.openai-compat.model-serving.eu01.onstackit.cloud/v1"
    }
    "embed" = {
      model    = "intfloat/e5-mistral-7b-instruct"
      api_base = "https://api.openai-compat.model-serving.eu01.onstackit.cloud/v1"
    }
  }

  model_backend_api_keys = {
    "chat-large" = var.stackit_model_serving_token
    "embed"      = var.stackit_model_serving_token
  }

  # Leave both out for a gateway without an admin console. Everything else keeps working.
  public_url = "https://litellm.example.com"

  oidc = {
    issuer_url    = "https://idp.example.com/realms/platform"
    client_id     = "litellm-console"
    client_secret = var.litellm_oidc_client_secret

    user_display_name_attribute = "name"
    allowed_email_domains       = ["example.com"]
  }
}
```

## Follow-up

**A locked console has no tested recovery path yet.** Once a sixth row exists in
`LiteLLM_UserTable`, every login initiation fails and nobody can start a new session. The defaults
here make that unlikely — `var.disable_auto_add_proxy_admin_to_teams` keeps Terraform from writing
any row, and `user_id_attribute` is pinned to `sub` so one person cannot become two rows — but the
risk does not go away, because each console user is one of five.

Removing a row through the API is the likely way out, and the master key does keep working while the
console is locked, because the seat check sits on the two SSO login routes and not in the general
authentication path. What is **not** tested is the side effects, so no procedure is documented here.
Two things need establishing on a throwaway database first: whether deleting a user also deletes
virtual keys that carry the same `user_id`, and whether the `scim_active` flag the counting function
honours can be set without an Enterprise licence.

Until then, treat five console users as a hard limit to plan around rather than a threshold to
recover from.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.4 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.38 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.litellm](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_secret_v1.master_key](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.model_credentials](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.oidc](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.postgres](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [http_http.oidc_discovery](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Version of the litellm-helm chart. See https://github.com/BerriAI/litellm/pkgs/container/litellm-helm. | `string` | `"1.96.2"` | no |
| <a name="input_client_certificate"></a> [client\_certificate](#input\_client\_certificate) | PEM-encoded client certificate this module authenticates with, as an alternative to `token`. Pass the decoded certificate, not the base64 blob a kubeconfig carries. | `string` | `null` | no |
| <a name="input_client_key"></a> [client\_key](#input\_client\_key) | PEM-encoded private key belonging to `client_certificate`. Pass the decoded key, not the base64 blob a kubeconfig carries. | `string` | `null` | no |
| <a name="input_cluster_ca_certificate"></a> [cluster\_ca\_certificate](#input\_cluster\_ca\_certificate) | Cluster CA certificate, base64 encoded. | `string` | n/a | yes |
| <a name="input_cluster_endpoint"></a> [cluster\_endpoint](#input\_cluster\_endpoint) | IP address or hostname of the cluster control plane, without the https:// scheme. | `string` | n/a | yes |
| <a name="input_disable_auto_add_proxy_admin_to_teams"></a> [disable\_auto\_add\_proxy\_admin\_to\_teams](#input\_disable\_auto\_add\_proxy\_admin\_to\_teams) | Write `general_settings.disable_auto_add_proxy_admin_to_teams: true` into the proxy config, so<br/>the proxy adds no admin member to a team it creates.<br/><br/>Leave it at `true`. With it `false`, the first call to `/team/new` writes one row to<br/>`LiteLLM_UserTable` and that row consumes one of the five console seats the free open-source<br/>proxy allows. The row is written once and not once per team, because every caller that<br/>authenticates with the master key is identified as the same constant user id, but it still costs<br/>one of the five seats. | `bool` | `true` | no |
| <a name="input_helm_timeout"></a> [helm\_timeout](#input\_helm\_timeout) | Seconds to wait for the Helm release to become ready. The Prisma migration Job runs first and takes part of this budget. | `number` | `600` | no |
| <a name="input_master_key"></a> [master\_key](#input\_master\_key) | Master key of the gateway. It must start with 'sk-', because LiteLLM rejects a key without that prefix. | `string` | n/a | yes |
| <a name="input_model_backend_api_keys"></a> [model\_backend\_api\_keys](#input\_model\_backend\_api\_keys) | API key per model alias, keyed exactly like model\_backends. Several aliases that share one upstream endpoint repeat the same value. | `map(string)` | n/a | yes |
| <a name="input_model_backends"></a> [model\_backends](#input\_model\_backends) | Models the gateway exposes, keyed by the alias callers ask for in the `model` field of a request.<br/><br/>- `model`: name of the model at the upstream provider. The module prefixes it with `openai/`,<br/>  which is what selects the OpenAI-compatible driver.<br/>- `api_base`: base URL of the upstream OpenAI-compatible endpoint, including the `/v1` suffix.<br/><br/>Pass the credential for each alias in `model_backend_api_keys` under the same key. | <pre>map(object({<br/>    model    = string<br/>    api_base = string<br/>  }))</pre> | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace the gateway runs in. The module creates it. | `string` | `"litellm"` | no |
| <a name="input_oidc"></a> [oidc](#input\_oidc) | OIDC identity provider the platform engineers log in to the admin console through. Null leaves<br/>the console without a login path, which is the correct setting for a gateway nobody administers<br/>through the browser.<br/><br/>Native SSO is free in the open-source proxy for up to five users, and it needs no Enterprise<br/>licence below that.<br/><br/>- `issuer_url`: discovery base URL of the provider, for example<br/>  `https://idp.example.com/realms/ai`. The module reads<br/>  `<issuer_url>/.well-known/openid-configuration` and takes the three endpoints from it, because<br/>  the proxy wants them spelled out and does no discovery of its own.<br/>- `client_id` and `client_secret`: credentials of the OIDC client.<br/>- `scopes`: space-separated scope list.<br/>- `authorization_endpoint`, `token_endpoint`, `userinfo_endpoint`: override one endpoint each and<br/>  skip discovery for it. Set all three when the provider is unreachable from the Terraform<br/>  runner, and the module then creates no discovery request at all.<br/>- `user_id_attribute`: claim the proxy stores as the user id. It defaults to `sub` here, not to<br/>  the proxy's own default of `preferred_username`, because `preferred_username` is reassignable<br/>  at most providers and a reassignment produces a second row in the user table for the same<br/>  person. Every row counts against the limit of five.<br/>- `user_email_attribute`, `user_display_name_attribute`, `user_role_attribute`: the rest of the<br/>  claim mapping. Null leaves the proxy on its own defaults, which are `email`, `sub` and `role`.<br/>- `allowed_email_domains`: only users whose email address carries one of these domains may log<br/>  in. The proxy compares the part after the `@` exactly, so there is no wildcard and no<br/>  subdomain match. Null lets every user the provider authenticates log in.<br/>- `proxy_admin_id`: user id that is set to the `proxy_admin` role on every login. It is compared<br/>  against the value of the `user_id_attribute` claim, so it is that claim's value and not an<br/>  email address unless the claim carries one.<br/>- `logout_url`: URL the console sends the browser to after a logout.<br/>- `auto_redirect_to_sso`: send the login page straight to the provider instead of showing a<br/>  button.<br/><br/>Register the callback URL `<public_url>/sso/callback` at the provider. The module sets no<br/>`SERVER_ROOT_PATH`, which is the only setting that would move the callback to another path.<br/><br/>**The console holds at most five users.** Read the free user limit section of the module README<br/>before you hand the console to a sixth person: the sixth login locks out everyone. | <pre>object({<br/>    issuer_url    = string<br/>    client_id     = string<br/>    client_secret = string<br/>    scopes        = optional(string, "openid email profile")<br/><br/>    authorization_endpoint = optional(string)<br/>    token_endpoint         = optional(string)<br/>    userinfo_endpoint      = optional(string)<br/><br/>    user_id_attribute           = optional(string, "sub")<br/>    user_email_attribute        = optional(string)<br/>    user_display_name_attribute = optional(string)<br/>    user_role_attribute         = optional(string)<br/><br/>    allowed_email_domains = optional(list(string))<br/>    proxy_admin_id        = optional(string)<br/>    logout_url            = optional(string)<br/>    auto_redirect_to_sso  = optional(bool, false)<br/>  })</pre> | `null` | no |
| <a name="input_postgres_connection_limit"></a> [postgres\_connection\_limit](#input\_postgres\_connection\_limit) | Maximum number of Postgres connections one gateway pod opens. The module writes it as<br/>`connection_limit` on the connection URL and as `general_settings.database_connection_pool_limit`<br/>in the proxy config, because the proxy rewrites the URL on startup from that setting.<br/><br/>Without the parameter Prisma sizes the pool as `physical cores × 2 + 1` read from the node, not<br/>from the pod's CPU limit, so a pod takes 33 connections on a 16-core node and a different number<br/>after it is rescheduled. The gateway is deployed once for the platform, so it costs<br/>`replica_count × postgres_connection_limit` connections in total.<br/><br/>The default of 10 is LiteLLM's own default, so pinning the value changes nothing at runtime and<br/>only bounds what the URL asks for. | `number` | `10` | no |
| <a name="input_postgres_database"></a> [postgres\_database](#input\_postgres\_database) | Name of the database on the Postgres server. It has to exist before the first apply; the Prisma migration Job creates the tables inside it, not the database itself. | `string` | `"litellm"` | no |
| <a name="input_postgres_host"></a> [postgres\_host](#input\_postgres\_host) | Hostname of the Postgres server that holds virtual keys, teams, budgets and spend records. | `string` | n/a | yes |
| <a name="input_postgres_password"></a> [postgres\_password](#input\_postgres\_password) | Password of the Postgres user. Use only characters that are safe in a URL, because the chart substitutes the value into the connection URL without encoding it. | `string` | n/a | yes |
| <a name="input_postgres_port"></a> [postgres\_port](#input\_postgres\_port) | Port of the Postgres server. | `number` | `5432` | no |
| <a name="input_postgres_ssl_mode"></a> [postgres\_ssl\_mode](#input\_postgres\_ssl\_mode) | Value of the sslmode parameter on the Postgres connection URL. One of 'disable', 'prefer', 'require', 'verify-ca' or 'verify-full'. | `string` | `"require"` | no |
| <a name="input_postgres_username"></a> [postgres\_username](#input\_postgres\_username) | User the gateway connects as. It needs rights to create and alter tables, because the Prisma migration Job runs the schema migrations under this user. | `string` | n/a | yes |
| <a name="input_public_url"></a> [public\_url](#input\_public\_url) | Canonical URL the gateway is reached at from outside the cluster, for example<br/>`https://litellm.example.com`, without a trailing slash. The module writes it as<br/>`PROXY_BASE_URL`, and the proxy builds the SSO callback as `<public_url>/sso/callback`.<br/><br/>Required when `var.oidc` is set. The proxy falls back to the base URL of the incoming request,<br/>which behind a TLS-terminating Ingress is the internal `http://` address of the pod, and the<br/>provider then rejects the redirect URI. The module creates no Ingress, so this is the URL of<br/>whatever Ingress or load balancer stands in front of the Service. | `string` | `null` | no |
| <a name="input_redis_host"></a> [redis\_host](#input\_redis\_host) | Hostname of an existing Redis instance the gateway coordinates through. Leave it null to run without Redis, which is only correct with a single replica. | `string` | `null` | no |
| <a name="input_redis_password"></a> [redis\_password](#input\_redis\_password) | Password of the Redis instance. Leave it null for a Redis without authentication. Only used when redis\_host is set. | `string` | `null` | no |
| <a name="input_redis_port"></a> [redis\_port](#input\_redis\_port) | Port of the Redis instance. Only used when redis\_host is set. | `number` | `6379` | no |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | Helm release name of the gateway. | `string` | `"litellm"` | no |
| <a name="input_replica_count"></a> [replica\_count](#input\_replica\_count) | Number of gateway pods. Set redis\_host as well when this is greater than 1. | `number` | `1` | no |
| <a name="input_token"></a> [token](#input\_token) | Token of the service account this module runs as. It needs permission to create a namespace, secrets and the workloads of the Helm release. Leave it null and set `client_certificate` and `client_key` instead when the cluster hands out a certificate pair. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_base"></a> [api\_base](#output\_api\_base) | In-cluster base URL of the gateway, including the '/v1' suffix. Callers send the master key or a virtual key as a bearer token. |
| <a name="output_console_url"></a> [console\_url](#output\_console\_url) | URL of the admin console. Null when var.public\_url is not set, because the console is then reachable in-cluster only. |
| <a name="output_master_key_secret_name"></a> [master\_key\_secret\_name](#output\_master\_key\_secret\_name) | Name of the secret in the gateway namespace that holds the master key under the 'masterkey' key. |
| <a name="output_model_aliases"></a> [model\_aliases](#output\_model\_aliases) | Model aliases the gateway exposes. A caller puts one of them in the 'model' field of a request. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Namespace the gateway runs in. |
| <a name="output_oidc_callback_url"></a> [oidc\_callback\_url](#output\_oidc\_callback\_url) | Callback URL to register at the identity provider. Null when var.oidc is not set. |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | Name of the Service in front of the gateway pods. |
| <a name="output_service_port"></a> [service\_port](#output\_service\_port) | Port the Service in front of the gateway pods listens on. An Ingress backend needs it. |
<!-- END_TF_DOCS -->
