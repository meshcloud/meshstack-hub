---
name: Shared ClickHouse Cluster
supportedPlatforms:
  - kubernetes
description: Installs the official ClickHouse Kubernetes operator and one operator-managed ClickHouse and ClickHouse Keeper cluster, sized for a demonstration and shared by every tenant of the AI platform.
# The cluster credentials arrive through the providers the caller configures and the administrative
# password arrives as an input, so there is nothing to set up on the cloud side.
requiresBackplane: false
---

# Shared ClickHouse Cluster Building Block

The platform team installs one ClickHouse cluster into the AI platform's Kubernetes cluster with this module. Every tenant's Langfuse instance stores its traces, observations and scores in that one cluster, separated by a database and a user of its own.

This documentation is intended as a reference for cloud foundation or platform engineers using this module.

## Sourced, not ordered

There is no `meshstack_integration.tf` and no `backplane/`. A tenant-facing building block sources `buildingblock/` and so does a foundation from a Terragrunt unit. Application teams never order this module: they order a Langfuse instance, and the composition behind it wires that instance to the cluster this module installs.

## Deployment cardinality

**This module is deployed once per Kubernetes cluster.** The operator installs cluster-scoped CustomResourceDefinitions and watches every namespace, and the ClickHouse cluster it manages is shared by all tenants. Instantiating the module a second time in the same Kubernetes cluster installs the operator twice.

`modules/ai/langfuse` is the opposite: it is instantiated once per tenant against the cluster this module provides.

## Prerequisites

| Prerequisite | Where it comes from |
|---|---|
| cert-manager | `modules/kubernetes/ingress` installs it. |
| A default StorageClass, or an explicit one | The cluster. ClickHouse and Keeper both claim persistent volumes. |
| A configured `kubernetes` and `helm` provider | The caller. |

The ClickHouse operator serves its admission webhook over TLS from a certificate cert-manager issues, so **cert-manager has to be running before this module applies**. This module does not install it, because `modules/kubernetes/ingress` already does and installing cert-manager twice in one cluster fails on the shared CRDs.

## The operator, not the bundled subchart

The Langfuse Helm chart bundles a Bitnami ClickHouse subchart. That subchart's image is older than the 25.12 floor Langfuse v4 requires, which is why the `langfuse-k8s` [v4 installation example](https://github.com/langfuse/langfuse-k8s/tree/main/examples/v4-installation) runs ClickHouse outside the chart under the [official ClickHouse Kubernetes operator](https://github.com/ClickHouse/clickhouse-operator). This module follows that example.

| | |
|---|---|
| Operator chart | `clickhouse-operator-helm` |
| Reference | `oci://ghcr.io/clickhouse/clickhouse-operator-helm` |
| Pinned version | `0.0.5` (`var.operator_chart_version`) |
| Custom resources | `clickhouse.com/v1alpha1` `ClickHouseCluster` and `KeeperCluster` |
| ClickHouse image | `clickhouse/clickhouse-server:26.4` (`var.clickhouse_version`) |
| Keeper image | `clickhouse/clickhouse-keeper:26.4` (`var.keeper_version`) |

The operator chart is published to GHCR as an OCI artifact only, so the tag on the registry is the single source of truth. The helm provider takes the registry and the path prefix as `repository` and the chart name on its own as `chart`.

### Why the custom resources run through a local Helm chart

A `kubernetes_manifest` resource looks the CRD schema up at plan time. The operator installs the `ClickHouseCluster` and `KeeperCluster` CRDs, so the schema does not exist during the first plan and the plan fails.

This module renders both custom resources through a Helm chart that lives in the module directory itself (`chart = path.module`). Helm applies the manifests at apply time and never asks Terraform for a schema, so the operator and its custom resources fit into a single Terraform unit. That is why the module directory carries a `Chart.yaml`, a `templates/` directory and a `.helmignore` that keeps every Terraform artifact out of the packaged chart. `modules/kubernetes/ingress` uses the same pattern for its ClusterIssuer.

### The readiness Job

Helm's `--wait` watches the resources a release creates. A `ClickHouseCluster` is a custom resource, and Helm has no idea what "ready" means for it, so the release reports success while the operator is still creating the StatefulSets. A Langfuse instance that starts against a ClickHouse that is not up yet crash-loops through its migrations.

The chart therefore ships a `post-install,post-upgrade` hook Job that runs `clickhouse-client --query "SELECT 1"` in a loop until the server answers. Helm waits for a hook Job to finish, so the Terraform apply only completes once ClickHouse accepts queries. The Job uses the same image the server runs, so no second image has to be pulled. `var.wait_for_ready` turns it off and `var.readiness_timeout` bounds it — keep the timeout below `var.helm_timeout`, otherwise the Helm release times out first and reports a less useful error.

## No provider blocks

This module carries no `provider` block. The caller configures the `kubernetes` and the `helm` provider and passes both down through the `providers` argument of the module call.

This is not a style preference. **A module with its own provider configuration cannot be called with `count` or `for_each`.** `modules/kubernetes/ingress` had to delete its `provider.tf` for exactly that reason, and the same constraint applies here, because a composition that deploys several platforms wants the shared ClickHouse under a `count`.

## Sizing

Every figure is a variable and every default is sized for a demonstration. The `langfuse-k8s` example ships the production shape: 3 ClickHouse replicas, 3 Keeper replicas, a 100Gi data volume per ClickHouse replica and 10Gi per Keeper replica.

| | Default here | `langfuse-k8s` example | Note |
|---|---|---|---|
| ClickHouse replicas | 1 | 3 | One replica gives no redundancy: every restart interrupts ingestion. |
| ClickHouse storage | `20Gi` | `100Gi` | Growing a volume later depends on CSI volume expansion. |
| ClickHouse memory | request `1Gi`, limit `2Gi` | Bitnami `2xlarge` preset | See the floor below. |
| Keeper replicas | 1 | 3 | Raft: the CustomResource only accepts 0, 1, 3, 5, 7, 9, 11, 13 or 15. |
| Keeper storage | `5Gi` | `10Gi` | |
| Keeper memory | request `256Mi`, limit `512Mi` | — | Grows with the number of tables, not with trace volume. |

**`1Gi` of memory is a floor, not a target.** ClickHouse allocates its mark and uncompressed caches at startup and does not start reliably below roughly that figure, so a smaller limit produces a pod that is OOMKilled during boot rather than a slow server. `var.clickhouse_resources` validates the request and the limit against that floor and rejects anything below it at plan time.

## Per-tenant separation, and who creates it

A Langfuse tenant needs two things in ClickHouse: **a database of its own** and **a user scoped to that database**. Neither is created here.

**The composition creates them** — the tenant-facing building block that sources both `modules/ai/clickhouse` and `modules/ai/langfuse`. Three reasons:

1. **This module is deployed once and must not churn with tenants.** A map of tenants as an input would mean every tenant order re-plans the operator release, the ClickHouseCluster and every other tenant's grants. Shared infrastructure would then share the failure domain of tenant churn.
2. **`modules/ai/langfuse` must never see the administrative credential.** It runs once per tenant, so its state is per-tenant state. A credential in there can drop any other tenant's database. Langfuse takes a tenant username and password as inputs, which means something else already created that user.
3. **The composition already owns the same decision for Postgres.** Langfuse takes `postgresql.auth.database` and `postgresql.auth.username` as inputs too, so whoever creates the Postgres database and its owner also creates the ClickHouse database and its user. Splitting the two across modules would put one tenant's identity in two places.

`modules/ai/clickhouse` supports the composition by exposing the host, the ports, the ON CLUSTER cluster name and the administrative credential. `modules/ai/langfuse` supports it by taking the tenant's database name, username and password as explicit inputs.

### The statements a composition runs

```sql
CREATE DATABASE IF NOT EXISTS tenant_x ON CLUSTER default;

CREATE USER IF NOT EXISTS tenant_x ON CLUSTER default
  IDENTIFIED WITH sha256_password BY '<password>'
  DEFAULT DATABASE tenant_x;

GRANT SELECT, INSERT, CREATE, DROP TABLE, ALTER UPDATE, ALTER DELETE, ALTER DROP INDEX
  ON tenant_x.* TO tenant_x ON CLUSTER default;
```

Two points about that grant list:

- **The tenant user does not need `CREATE DATABASE`.** Langfuse runs its ClickHouse schema migrations with golang-migrate, and golang-migrate never creates a database — it only creates tables inside one that already exists. Granting `CREATE DATABASE` would let a tenant create databases outside its own scope.
- **`ON CLUSTER default` is required** whenever the ClickHouse cluster has more than one replica, and harmless with one. `default` is the cluster name the operator configures, exposed as the `ddl_cluster_name` output.

There is no first-class Terraform provider for DDL against a self-hosted ClickHouse. In practice a composition runs the statements from a Kubernetes Job in the ClickHouse namespace, using the `clickhouse/clickhouse-server` image and mounting the administrative password from the Secret named by the `admin_secret` output.

## Upgrading ClickHouse

`var.clickhouse_version` and `var.keeper_version` are separate variables, but they belong on the same release: the two speak one protocol. Raise Keeper first, then ClickHouse. The operator rolls the StatefulSets one replica at a time, so a single-replica demonstration cluster is unavailable for the duration of the upgrade.

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
| [helm_release.clickhouse_operator](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.cluster](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace_v1.clickhouse](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_namespace_v1.operator](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_secret_v1.admin](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password) | Password of the administrative ClickHouse user. The caller that creates the per-tenant databases and users authenticates with it, so it must not be handed to a tenant. | `string` | n/a | yes |
| <a name="input_admin_username"></a> [admin\_username](#input\_admin\_username) | Name of the administrative ClickHouse user the operator creates. The operator only manages the 'default' user, so changing this does not create a different user. | `string` | `"default"` | no |
| <a name="input_clickhouse_replicas"></a> [clickhouse\_replicas](#input\_clickhouse\_replicas) | Number of ClickHouse replicas. The default of 1 is sized for a demonstration cluster and gives no redundancy: every restart or node drain interrupts ingestion. Production wants 3. | `number` | `1` | no |
| <a name="input_clickhouse_resources"></a> [clickhouse\_resources](#input\_clickhouse\_resources) | Resource requests and limits of each ClickHouse server container. The default is sized for a<br/>demonstration cluster and a production consumer has to raise it.<br/><br/>`1Gi` of memory is a floor, not a target. ClickHouse allocates mark and uncompressed caches at<br/>startup and does not start reliably below roughly that figure, so a smaller request produces a<br/>pod that is OOMKilled during boot rather than a slow server. The Langfuse chart's own bundled<br/>ClickHouse asks for the Bitnami `2xlarge` preset. Production wants `2` to `4` CPUs and `8Gi` to<br/>`16Gi` of memory per replica. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "2",<br/>    "memory": "2Gi"<br/>  },<br/>  "requests": {<br/>    "cpu": "500m",<br/>    "memory": "1Gi"<br/>  }<br/>}</pre> | no |
| <a name="input_clickhouse_storage"></a> [clickhouse\_storage](#input\_clickhouse\_storage) | Size of the data volume of each ClickHouse replica. The default of 20Gi is sized for a demonstration cluster. Production wants 100Gi or more, because trace data grows quickly and a later resize depends on CSI volume expansion. | `string` | `"20Gi"` | no |
| <a name="input_clickhouse_storage_class_name"></a> [clickhouse\_storage\_class\_name](#input\_clickhouse\_storage\_class\_name) | StorageClass of the ClickHouse data volumes. Null uses the default StorageClass of the cluster. | `string` | `null` | no |
| <a name="input_clickhouse_version"></a> [clickhouse\_version](#input\_clickhouse\_version) | Tag of the clickhouse/clickhouse-server image. Langfuse v4 needs 25.12 or newer, so do not lower this below that floor. | `string` | `"26.4"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the ClickHouseCluster and KeeperCluster resources. The operator names the headless Service '<cluster\_name>-clickhouse-headless'. | `string` | `"clickhouse"` | no |
| <a name="input_helm_timeout"></a> [helm\_timeout](#input\_helm\_timeout) | Seconds to wait for each Helm release of this module. The operator install and the custom resources share the same budget per release. | `number` | `900` | no |
| <a name="input_keeper_replicas"></a> [keeper\_replicas](#input\_keeper\_replicas) | Number of ClickHouse Keeper replicas. The CustomResource accepts only 0, 1, 3, 5, 7, 9, 11, 13 or 15. The default of 1 is sized for a demonstration cluster and gives no redundancy. Production wants 3. | `number` | `1` | no |
| <a name="input_keeper_resources"></a> [keeper\_resources](#input\_keeper\_resources) | Resource requests and limits of each ClickHouse Keeper container. The default is sized for a<br/>demonstration cluster and a production consumer has to raise it.<br/><br/>Keeper holds the coordination state — replication queues, the distributed DDL queue and part<br/>metadata — in memory, so its footprint grows with the number of tables rather than with the<br/>volume of trace data. Production wants `500m` CPU and `1Gi` to `2Gi` of memory per replica. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "500m",<br/>    "memory": "512Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "100m",<br/>    "memory": "256Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_keeper_storage"></a> [keeper\_storage](#input\_keeper\_storage) | Size of the data volume of each Keeper replica. The default of 5Gi is sized for a demonstration cluster. The langfuse-k8s example ships 10Gi, which is the production target. | `string` | `"5Gi"` | no |
| <a name="input_keeper_storage_class_name"></a> [keeper\_storage\_class\_name](#input\_keeper\_storage\_class\_name) | StorageClass of the Keeper data volumes. Null uses the default StorageClass of the cluster. | `string` | `null` | no |
| <a name="input_keeper_version"></a> [keeper\_version](#input\_keeper\_version) | Tag of the clickhouse/clickhouse-keeper image. Keep it on the same release as clickhouse\_version, because the two speak one protocol. | `string` | `"26.4"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace the ClickHouse cluster and the ClickHouse Keeper cluster run in. The module creates it. Every tenant's Langfuse instance connects across namespaces to the Service in here. | `string` | `"clickhouse"` | no |
| <a name="input_operator_chart_version"></a> [operator\_chart\_version](#input\_operator\_chart\_version) | Version of the clickhouse-operator-helm chart. See https://github.com/ClickHouse/clickhouse-operator/pkgs/container/clickhouse-operator-helm. | `string` | `"0.0.5"` | no |
| <a name="input_operator_namespace"></a> [operator\_namespace](#input\_operator\_namespace) | Namespace the ClickHouse operator runs in. The module creates it. The operator watches every namespace, so one installation serves the whole cluster. | `string` | `"clickhouse-operator"` | no |
| <a name="input_operator_resources"></a> [operator\_resources](#input\_operator\_resources) | Resource requests and limits of the ClickHouse operator controller manager. The values match the<br/>chart's own defaults, which are already small, so a production consumer rarely has to change<br/>them. The controller reconciles custom resources and holds no data. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "500m",<br/>    "memory": "128Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "10m",<br/>    "memory": "64Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_readiness_timeout"></a> [readiness\_timeout](#input\_readiness\_timeout) | Seconds the readiness Job waits for ClickHouse to answer a query before it fails. Keep it below helm\_timeout, otherwise the Helm release times out first and reports a less useful error. | `number` | `900` | no |
| <a name="input_wait_for_ready"></a> [wait\_for\_ready](#input\_wait\_for\_ready) | Run a Helm hook Job after the custom resources are applied that blocks until ClickHouse answers a query. Turn it off only when the caller waits for readiness itself. | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_admin_password"></a> [admin\_password](#output\_admin\_password) | Password of the administrative ClickHouse user. It grants full access to every tenant's database, so never pass it to a tenant. |
| <a name="output_admin_secret"></a> [admin\_secret](#output\_admin\_secret) | Name and key of the Kubernetes Secret in the ClickHouse namespace that holds the administrative password. A Job that creates per-tenant databases can mount it instead of taking the value through Terraform. |
| <a name="output_admin_username"></a> [admin\_username](#output\_admin\_username) | Name of the administrative ClickHouse user. Use it to create the per-tenant databases and users. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the ClickHouseCluster and KeeperCluster resources. |
| <a name="output_ddl_cluster_name"></a> [ddl\_cluster\_name](#output\_ddl\_cluster\_name) | Name of the ClickHouse cluster as the server knows it. Every ON CLUSTER statement — the Langfuse migrations included — names it. |
| <a name="output_host"></a> [host](#output\_host) | Fully qualified in-cluster hostname of the ClickHouse headless Service. Pass it to the Langfuse chart as clickhouse.host. |
| <a name="output_http_port"></a> [http\_port](#output\_http\_port) | HTTP port of ClickHouse. Langfuse reads and writes trace data over it and the chart takes it as clickhouse.httpPort. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Namespace the ClickHouse cluster runs in. |
| <a name="output_native_port"></a> [native\_port](#output\_native\_port) | Native protocol port of ClickHouse. The golang-migrate migrations and clickhouse-client use it, and the Langfuse chart takes it as clickhouse.nativePort. |
<!-- END_TF_DOCS -->
