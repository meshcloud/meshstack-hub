---
name: LiteLLM AI Gateway
supportedPlatforms:
  - kubernetes
description: Installs the LiteLLM gateway into a Kubernetes namespace and registers OpenAI-compatible model endpoints behind one API, with virtual keys, teams, budgets and spend tracking backed by Postgres.
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

The chart's default connection URL carries no port, so the module writes its own `db.url` with `postgres_port` and the sslmode parameter in it. The credentials stay in a Kubernetes Secret and never appear in the pod spec, because the URL keeps the `$(…)` references that Kubernetes resolves from the environment.

### The Prisma migration Job

The chart runs the schema migrations in a Prisma Job (`migrationJob.enabled`, default true). Its default annotations address ArgoCD, which means nothing to a Terraform-driven install: the Job would be applied together with the Deployment, and the pods would restart until the schema exists, because the proxy itself runs with `DISABLE_SCHEMA_UPDATE=true` whenever the Job is enabled.

This module therefore turns the Helm hook on and the ArgoCD annotations off. The Job runs as a `pre-install,pre-upgrade` hook, Helm waits for it to finish, and only then creates the Deployment. Two consequences follow:

- A failing migration fails the whole `helm_release`, which is what you want — the alternative is a pod crash loop that Terraform reports as a timeout.
- The Job needs its share of `helm_timeout`. The default of 600 seconds covers a migration and a rollout together.

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

## Notes for platform engineers

- **Providers.** Only `kubernetes` and `helm`. No cloud provider enters this module, so it runs on SKE, AKS and anything else that speaks the Kubernetes API.
- **Permissions.** The token in `var.token` needs to create a namespace, secrets and the workloads of the release in that namespace. Cluster-admin is not required; the chart installs no CRDs and no cluster-scoped RBAC.
- **The namespace belongs to the module.** It creates `var.namespace` and destroys it again, together with the secrets it wrote there.
- **Reachability.** The Service is a ClusterIP, so the gateway answers inside the cluster at the `api_base` output. Put an Ingress in front of it when callers live outside the cluster.

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
}
```

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
| [helm_release.litellm](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_secret_v1.master_key](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.model_credentials](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.postgres](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Version of the litellm-helm chart. See https://github.com/BerriAI/litellm/pkgs/container/litellm-helm. | `string` | `"1.96.2"` | no |
| <a name="input_cluster_ca_certificate"></a> [cluster\_ca\_certificate](#input\_cluster\_ca\_certificate) | Cluster CA certificate, base64 encoded. | `string` | n/a | yes |
| <a name="input_cluster_endpoint"></a> [cluster\_endpoint](#input\_cluster\_endpoint) | IP address or hostname of the cluster control plane, without the https:// scheme. | `string` | n/a | yes |
| <a name="input_helm_timeout"></a> [helm\_timeout](#input\_helm\_timeout) | Seconds to wait for the Helm release to become ready. The Prisma migration Job runs first and takes part of this budget. | `number` | `600` | no |
| <a name="input_master_key"></a> [master\_key](#input\_master\_key) | Master key of the gateway. It must start with 'sk-', because LiteLLM rejects a key without that prefix. | `string` | n/a | yes |
| <a name="input_model_backend_api_keys"></a> [model\_backend\_api\_keys](#input\_model\_backend\_api\_keys) | API key per model alias, keyed exactly like model\_backends. Several aliases that share one upstream endpoint repeat the same value. | `map(string)` | n/a | yes |
| <a name="input_model_backends"></a> [model\_backends](#input\_model\_backends) | Models the gateway exposes, keyed by the alias callers ask for in the `model` field of a request.<br/><br/>- `model`: name of the model at the upstream provider. The module prefixes it with `openai/`,<br/>  which is what selects the OpenAI-compatible driver.<br/>- `api_base`: base URL of the upstream OpenAI-compatible endpoint, including the `/v1` suffix.<br/><br/>Pass the credential for each alias in `model_backend_api_keys` under the same key. | <pre>map(object({<br/>    model    = string<br/>    api_base = string<br/>  }))</pre> | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace the gateway runs in. The module creates it. | `string` | `"litellm"` | no |
| <a name="input_postgres_database"></a> [postgres\_database](#input\_postgres\_database) | Name of the database on the Postgres server. It has to exist before the first apply; the Prisma migration Job creates the tables inside it, not the database itself. | `string` | `"litellm"` | no |
| <a name="input_postgres_host"></a> [postgres\_host](#input\_postgres\_host) | Hostname of the Postgres server that holds virtual keys, teams, budgets and spend records. | `string` | n/a | yes |
| <a name="input_postgres_password"></a> [postgres\_password](#input\_postgres\_password) | Password of the Postgres user. Use only characters that are safe in a URL, because the chart substitutes the value into the connection URL without encoding it. | `string` | n/a | yes |
| <a name="input_postgres_port"></a> [postgres\_port](#input\_postgres\_port) | Port of the Postgres server. | `number` | `5432` | no |
| <a name="input_postgres_ssl_mode"></a> [postgres\_ssl\_mode](#input\_postgres\_ssl\_mode) | Value of the sslmode parameter on the Postgres connection URL. One of 'disable', 'prefer', 'require', 'verify-ca' or 'verify-full'. | `string` | `"require"` | no |
| <a name="input_postgres_username"></a> [postgres\_username](#input\_postgres\_username) | User the gateway connects as. It needs rights to create and alter tables, because the Prisma migration Job runs the schema migrations under this user. | `string` | n/a | yes |
| <a name="input_redis_host"></a> [redis\_host](#input\_redis\_host) | Hostname of an existing Redis instance the gateway coordinates through. Leave it null to run without Redis, which is only correct with a single replica. | `string` | `null` | no |
| <a name="input_redis_password"></a> [redis\_password](#input\_redis\_password) | Password of the Redis instance. Leave it null for a Redis without authentication. Only used when redis\_host is set. | `string` | `null` | no |
| <a name="input_redis_port"></a> [redis\_port](#input\_redis\_port) | Port of the Redis instance. Only used when redis\_host is set. | `number` | `6379` | no |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | Helm release name of the gateway. | `string` | `"litellm"` | no |
| <a name="input_replica_count"></a> [replica\_count](#input\_replica\_count) | Number of gateway pods. Set redis\_host as well when this is greater than 1. | `number` | `1` | no |
| <a name="input_token"></a> [token](#input\_token) | Token of the service account this module runs as. It needs permission to create a namespace, secrets and the workloads of the Helm release. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_base"></a> [api\_base](#output\_api\_base) | In-cluster base URL of the gateway, including the '/v1' suffix. Callers send the master key or a virtual key as a bearer token. |
| <a name="output_master_key_secret_name"></a> [master\_key\_secret\_name](#output\_master\_key\_secret\_name) | Name of the secret in the gateway namespace that holds the master key under the 'masterkey' key. |
| <a name="output_model_aliases"></a> [model\_aliases](#output\_model\_aliases) | Model aliases the gateway exposes. A caller puts one of them in the 'model' field of a request. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Namespace the gateway runs in. |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | Name of the Service in front of the gateway pods. |
<!-- END_TF_DOCS -->
