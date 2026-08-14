locals {
  # The operator derives the name of the public headless Service from the CustomResource:
  # '<name>-clickhouse' plus the 'headless' suffix. Every client outside the namespace needs the
  # fully qualified name.
  headless_service_name = "${var.cluster_name}-clickhouse-headless"
  host                  = "${local.headless_service_name}.${var.namespace}.svc.cluster.local"

  # Fixed by the operator rather than configurable, so pinning them here keeps the outputs and the
  # readiness Job in step with the ports the Service actually publishes.
  http_port   = 8123
  native_port = 9000

  # The operator always names the ClickHouse cluster 'default'. Langfuse writes its ON CLUSTER DDL
  # against that name, so a consumer that overrides it breaks the migrations.
  ddl_cluster_name = "default"

  admin_secret_key = "password"

  # Helm renders these values into the pod spec as YAML, and the API server rejects a resource
  # quantity that is null, so drop every field the caller left unset.
  resources = {
    for name, spec in {
      operator   = var.operator_resources
      clickhouse = var.clickhouse_resources
      keeper     = var.keeper_resources
      } : name => {
      requests = { for key, value in spec.requests : key => value if value != null }
      limits   = { for key, value in spec.limits : key => value if value != null }
    }
  }
}

resource "kubernetes_namespace_v1" "operator" {
  metadata {
    name = var.operator_namespace
  }
}

# The operator is cluster-scoped: it installs the ClickHouseCluster and KeeperCluster CRDs and
# watches every namespace. Install it once per Kubernetes cluster.
#
# Its admission webhook serves TLS from a certificate cert-manager issues, so cert-manager has to
# be present before this release. In this hub, modules/kubernetes/ingress installs it.
resource "helm_release" "clickhouse_operator" {
  name       = "clickhouse-operator"
  namespace  = kubernetes_namespace_v1.operator.metadata[0].name
  repository = "oci://ghcr.io/clickhouse"
  chart      = "clickhouse-operator-helm"
  version    = var.operator_chart_version

  create_namespace = false
  atomic           = true
  wait             = true
  timeout          = var.helm_timeout

  values = [
    yamlencode({
      manager = {
        resources = local.resources.operator
      }
      crd = {
        enabled = true
        # Keeping the CRDs on uninstall preserves every ClickHouseCluster and KeeperCluster object
        # in the cluster. Deleting a CRD deletes its custom resources, and the operator would then
        # tear down the StatefulSets and their volumes.
        keep = true
      }
      certManager = {
        enable = true
      }
    })
  ]
}

resource "kubernetes_namespace_v1" "clickhouse" {
  metadata {
    name = var.namespace
  }
}

# The operator reads the password of the 'default' user from this secret, and the caller that
# creates the per-tenant databases and users authenticates with the same value.
resource "kubernetes_secret_v1" "admin" {
  metadata {
    name      = "${var.cluster_name}-admin"
    namespace = kubernetes_namespace_v1.clickhouse.metadata[0].name
  }

  data = {
    (local.admin_secret_key) = var.admin_password
  }
}

# ClickHouseCluster and KeeperCluster are custom resources whose CRDs only exist once the operator
# is installed. A kubernetes_manifest resource looks the schema up at plan time, so the first plan
# of this module would fail. Helm renders and applies the manifests at apply time and never asks
# Terraform for a schema, which is why the module directory itself is a chart with a Chart.yaml, a
# templates/ directory and a .helmignore that keeps every Terraform artifact out of the package.
resource "helm_release" "cluster" {
  name      = var.cluster_name
  namespace = kubernetes_namespace_v1.clickhouse.metadata[0].name
  chart     = path.module

  create_namespace = false
  atomic           = true
  wait             = true
  timeout          = var.helm_timeout

  values = [
    yamlencode({
      cluster = {
        name = var.cluster_name
      }

      auth = {
        username   = var.admin_username
        secretName = kubernetes_secret_v1.admin.metadata[0].name
        secretKey  = local.admin_secret_key
      }

      clickhouse = {
        replicas = var.clickhouse_replicas
        image = {
          repository = "clickhouse/clickhouse-server"
          tag        = var.clickhouse_version
        }
        storage          = var.clickhouse_storage
        storageClassName = var.clickhouse_storage_class_name
        resources        = local.resources.clickhouse
        nativePort       = local.native_port
      }

      keeper = {
        replicas = var.keeper_replicas
        image = {
          repository = "clickhouse/clickhouse-keeper"
          tag        = var.keeper_version
        }
        storage          = var.keeper_storage
        storageClassName = var.keeper_storage_class_name
        resources        = local.resources.keeper
      }

      readiness = {
        enabled        = var.wait_for_ready
        timeoutSeconds = var.readiness_timeout
      }
    })
  ]

  depends_on = [helm_release.clickhouse_operator]
}
