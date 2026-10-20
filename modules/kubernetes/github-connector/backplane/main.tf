resource "kubernetes_namespace_v1" "connector" {
  metadata {
    name = var.namespace
  }
}

# Identity of the building block run. It needs no access to workloads: it only sets up the service
# account that GitHub Actions deploys with, inside the tenant namespace it is connected to.
resource "kubernetes_service_account_v1" "connector" {
  metadata {
    name      = var.service_account_name
    namespace = kubernetes_namespace_v1.connector.metadata[0].name
  }
}

resource "kubernetes_secret_v1" "connector_token" {
  metadata {
    name      = "${var.service_account_name}-token"
    namespace = kubernetes_namespace_v1.connector.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.connector.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_cluster_role_v1" "connector" {
  metadata {
    name = var.service_account_name
  }

  # No `list` or `watch`: RBAC cannot scope reads to tenant namespaces, so the run may only read
  # objects it knows by name instead of enumerating every secret in the cluster.
  rule {
    api_groups = [""]
    resources  = ["serviceaccounts", "secrets"]
    verbs      = ["get", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["rolebindings"]
    verbs      = ["get", "create", "update", "patch", "delete"]
  }

  # RBAC escalation prevention lets a subject grant a role only if it holds the role's permissions
  # itself or may `bind` it. `bind` on exactly `edit` keeps the run from handing out anything else.
  rule {
    api_groups     = ["rbac.authorization.k8s.io"]
    resources      = ["clusterroles"]
    verbs          = ["bind"]
    resource_names = ["edit"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "connector" {
  metadata {
    name = var.service_account_name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.connector.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.connector.metadata[0].name
    namespace = kubernetes_namespace_v1.connector.metadata[0].name
  }
}

locals {
  connector_username = "system:serviceaccount:${kubernetes_namespace_v1.connector.metadata[0].name}:${kubernetes_service_account_v1.connector.metadata[0].name}"
}

# The cluster role above applies to every namespace, because RBAC cannot select namespaces by
# label. This policy confines the run's writes to meshStack tenant namespaces.
resource "kubernetes_validating_admission_policy_v1" "tenant_namespaces_only" {
  metadata = {
    name = "${var.service_account_name}-tenant-namespaces-only"
  }

  spec = {
    failure_policy    = "Fail"
    audit_annotations = []

    match_constraints = {
      resource_rules = [{
        api_groups   = ["", "rbac.authorization.k8s.io"]
        api_versions = ["*"]
        operations   = ["CREATE", "UPDATE", "DELETE"]
        resources    = ["serviceaccounts", "secrets", "rolebindings"]
      }]
    }

    match_conditions = [{
      name       = "is-connector"
      expression = "request.userInfo.username == '${local.connector_username}'"
    }]

    validations = [{
      expression = "namespaceObject != null && has(namespaceObject.metadata.labels) && '${var.tenant_namespace_label}' in namespaceObject.metadata.labels && namespaceObject.metadata.labels['${var.tenant_namespace_label}'] == 'true'"
      message    = "The GitHub connector may only change objects in namespaces labeled ${var.tenant_namespace_label}=true."
    }]
  }
}

# The provider has no resource for policy bindings yet.
resource "kubernetes_manifest" "tenant_namespaces_only_binding" {
  manifest = {
    apiVersion = "admissionregistration.k8s.io/v1"
    kind       = "ValidatingAdmissionPolicyBinding"
    metadata = {
      name = "${var.service_account_name}-tenant-namespaces-only"
    }
    spec = {
      policyName        = kubernetes_validating_admission_policy_v1.tenant_namespaces_only.metadata.name
      validationActions = ["Deny"]
    }
  }
}
