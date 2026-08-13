variable "operator_namespace" {
  type        = string
  default     = "clickhouse-operator"
  description = "Namespace the ClickHouse operator runs in. The module creates it. The operator watches every namespace, so one installation serves the whole cluster."
}

variable "operator_chart_version" {
  type    = string
  default = "0.0.5"
  # The chart is published to GHCR as an OCI artifact only, so the tag on the registry is the
  # single source of truth. The `langfuse-k8s` v4 installation example pins the same version.
  description = "Version of the clickhouse-operator-helm chart. See https://github.com/ClickHouse/clickhouse-operator/pkgs/container/clickhouse-operator-helm."
}

variable "operator_resources" {
  type = object({
    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})
    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})
  })
  nullable = false
  default = {
    requests = { cpu = "10m", memory = "64Mi" }
    limits   = { cpu = "500m", memory = "128Mi" }
  }
  description = <<-EOT
  Resource requests and limits of the ClickHouse operator controller manager. The values match the
  chart's own defaults, which are already small, so a production consumer rarely has to change
  them. The controller reconciles custom resources and holds no data.
  EOT
}

variable "namespace" {
  type        = string
  default     = "clickhouse"
  description = "Namespace the ClickHouse cluster and the ClickHouse Keeper cluster run in. The module creates it. Every tenant's Langfuse instance connects across namespaces to the Service in here."
}

variable "cluster_name" {
  type    = string
  default = "clickhouse"
  # The operator derives every owned resource name from this: the headless Service is
  # '<cluster_name>-clickhouse-headless' and the StatefulSets carry the same prefix.
  description = "Name of the ClickHouseCluster and KeeperCluster resources. The operator names the headless Service '<cluster_name>-clickhouse-headless'."
}

variable "clickhouse_version" {
  type    = string
  default = "26.4"
  # Langfuse v4 requires ClickHouse 25.12 or newer. The ClickHouse version the Langfuse chart
  # bundles is older than that, which is the reason the operator runs the server instead.
  description = "Tag of the clickhouse/clickhouse-server image. Langfuse v4 needs 25.12 or newer, so do not lower this below that floor."
}

variable "clickhouse_replicas" {
  type    = number
  default = 1
  # The langfuse-k8s example ships 3, which is the production target: three replicas survive the
  # loss of one node and let a rolling upgrade proceed without downtime.
  description = "Number of ClickHouse replicas. The default of 1 is sized for a demonstration cluster and gives no redundancy: every restart or node drain interrupts ingestion. Production wants 3."

  validation {
    condition     = var.clickhouse_replicas >= 1
    error_message = "clickhouse_replicas must be at least 1."
  }
}

variable "clickhouse_storage" {
  type    = string
  default = "20Gi"
  # The langfuse-k8s example ships 100Gi and recommends starting large, because growing a volume
  # afterwards depends on the CSI driver supporting expansion.
  description = "Size of the data volume of each ClickHouse replica. The default of 20Gi is sized for a demonstration cluster. Production wants 100Gi or more, because trace data grows quickly and a later resize depends on CSI volume expansion."
}

variable "clickhouse_storage_class_name" {
  type        = string
  default     = null
  description = "StorageClass of the ClickHouse data volumes. Null uses the default StorageClass of the cluster."
}

variable "clickhouse_resources" {
  type = object({
    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})
    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})
  })
  nullable = false
  default = {
    requests = { cpu = "500m", memory = "1Gi" }
    limits   = { cpu = "2", memory = "2Gi" }
  }
  description = <<-EOT
  Resource requests and limits of each ClickHouse server container. The default is sized for a
  demonstration cluster and a production consumer has to raise it.

  `1Gi` of memory is a floor, not a target. ClickHouse allocates mark and uncompressed caches at
  startup and does not start reliably below roughly that figure, so a smaller request produces a
  pod that is OOMKilled during boot rather than a slow server. The Langfuse chart's own bundled
  ClickHouse asks for the Bitnami `2xlarge` preset. Production wants `2` to `4` CPUs and `8Gi` to
  `16Gi` of memory per replica.
  EOT

  validation {
    condition = var.clickhouse_resources.limits.memory == null ? true : (
      can(regex("^[0-9]+Gi$", var.clickhouse_resources.limits.memory))
      ? tonumber(trimsuffix(var.clickhouse_resources.limits.memory, "Gi")) >= 1
      : can(regex("^[0-9]+Mi$", var.clickhouse_resources.limits.memory))
      ? tonumber(trimsuffix(var.clickhouse_resources.limits.memory, "Mi")) >= 1024
      : true
    )
    error_message = "clickhouse_resources.limits.memory must be at least 1Gi. ClickHouse does not start reliably below that."
  }

  validation {
    condition = var.clickhouse_resources.requests.memory == null ? true : (
      can(regex("^[0-9]+Gi$", var.clickhouse_resources.requests.memory))
      ? tonumber(trimsuffix(var.clickhouse_resources.requests.memory, "Gi")) >= 1
      : can(regex("^[0-9]+Mi$", var.clickhouse_resources.requests.memory))
      ? tonumber(trimsuffix(var.clickhouse_resources.requests.memory, "Mi")) >= 1024
      : true
    )
    error_message = "clickhouse_resources.requests.memory must be at least 1Gi. ClickHouse does not start reliably below that."
  }
}

variable "keeper_version" {
  type        = string
  default     = "26.4"
  description = "Tag of the clickhouse/clickhouse-keeper image. Keep it on the same release as clickhouse_version, because the two speak one protocol."
}

variable "keeper_replicas" {
  type    = number
  default = 1
  # Keeper runs Raft, so a quorum needs an odd number and tolerates (n-1)/2 failures. One replica
  # is a quorum of one: correct, but it stops the whole cluster whenever that pod restarts.
  description = "Number of ClickHouse Keeper replicas. The CustomResource accepts only 0, 1, 3, 5, 7, 9, 11, 13 or 15. The default of 1 is sized for a demonstration cluster and gives no redundancy. Production wants 3."

  validation {
    # The CRD declares an enum on this field, so the API server rejects anything else with a
    # message that names the whole list. Catching it here fails the plan instead of the apply.
    condition     = contains([1, 3, 5, 7, 9, 11, 13, 15], var.keeper_replicas)
    error_message = "keeper_replicas must be one of 1, 3, 5, 7, 9, 11, 13 or 15, because Keeper needs a Raft quorum and the CustomResource restricts the field to those values."
  }
}

variable "keeper_storage" {
  type        = string
  default     = "5Gi"
  description = "Size of the data volume of each Keeper replica. The default of 5Gi is sized for a demonstration cluster. The langfuse-k8s example ships 10Gi, which is the production target."
}

variable "keeper_storage_class_name" {
  type        = string
  default     = null
  description = "StorageClass of the Keeper data volumes. Null uses the default StorageClass of the cluster."
}

variable "keeper_resources" {
  type = object({
    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})
    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})
  })
  nullable = false
  default = {
    requests = { cpu = "100m", memory = "256Mi" }
    limits   = { cpu = "500m", memory = "512Mi" }
  }
  description = <<-EOT
  Resource requests and limits of each ClickHouse Keeper container. The default is sized for a
  demonstration cluster and a production consumer has to raise it.

  Keeper holds the coordination state — replication queues, the distributed DDL queue and part
  metadata — in memory, so its footprint grows with the number of tables rather than with the
  volume of trace data. Production wants `500m` CPU and `1Gi` to `2Gi` of memory per replica.
  EOT
}

variable "admin_username" {
  type    = string
  default = "default"
  # The operator creates exactly one user from the CustomResource, and that user is named
  # 'default'. Every other user is created with SQL against this one.
  description = "Name of the administrative ClickHouse user the operator creates. The operator only manages the 'default' user, so changing this does not create a different user."
}

variable "admin_password" {
  type      = string
  sensitive = true
  # Handed to the operator through a Kubernetes Secret and used by whoever creates the per-tenant
  # databases and users. Keep it out of any per-tenant state.
  description = "Password of the administrative ClickHouse user. The caller that creates the per-tenant databases and users authenticates with it, so it must not be handed to a tenant."

  validation {
    condition     = length(var.admin_password) >= 16
    error_message = "The admin password must be at least 16 characters long."
  }
}

variable "helm_timeout" {
  type        = number
  default     = 900
  description = "Seconds to wait for each Helm release of this module. The operator install and the custom resources share the same budget per release."
}

variable "wait_for_ready" {
  type    = bool
  default = true
  # Helm's own --wait never looks at custom resources, so without this Job the module reports
  # success while the operator is still creating the StatefulSets.
  description = "Run a Helm hook Job after the custom resources are applied that blocks until ClickHouse answers a query. Turn it off only when the caller waits for readiness itself."
}

variable "readiness_timeout" {
  type        = number
  default     = 900
  description = "Seconds the readiness Job waits for ClickHouse to answer a query before it fails. Keep it below helm_timeout, otherwise the Helm release times out first and reports a less useful error."
}
