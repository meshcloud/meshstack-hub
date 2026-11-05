resource "kubernetes_namespace_v1" "backplane" {
  metadata {
    name = var.name
  }
}

resource "kubernetes_service_account_v1" "backplane" {
  metadata {
    name      = var.name
    namespace = kubernetes_namespace_v1.backplane.metadata[0].name
  }
}

resource "kubernetes_secret_v1" "backplane_token" {
  metadata {
    name      = "${kubernetes_service_account_v1.backplane.metadata[0].name}-token"
    namespace = kubernetes_namespace_v1.backplane.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.backplane.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_cluster_role_v1" "backplane" {
  metadata {
    name = var.name
  }

  rule {
    api_groups = [""]
    resources  = ["serviceaccounts", "secrets"]
    verbs      = ["get", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["roles", "rolebindings"]
    verbs      = ["get", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["get", "create", "update", "patch", "delete"]
  }

  # RBAC lets the building block grant the run-controller's Role only what it holds itself.
  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["get", "list", "watch", "create", "patch"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "backplane" {
  metadata {
    name = var.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.backplane.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.backplane.metadata[0].name
    namespace = kubernetes_namespace_v1.backplane.metadata[0].name
  }
}

locals {
  backplane_username = "system:serviceaccount:${kubernetes_namespace_v1.backplane.metadata[0].name}:${kubernetes_service_account_v1.backplane.metadata[0].name}"
}

resource "kubernetes_validating_admission_policy_v1" "managed_namespaces_only" {
  metadata = {
    name = "${var.name}-managed-namespaces-only"
  }

  spec = {
    failure_policy    = "Fail"
    audit_annotations = []

    match_constraints = {
      resource_rules = [{
        api_groups   = ["", "rbac.authorization.k8s.io", "apps", "batch"]
        api_versions = ["*"]
        operations   = ["CREATE", "UPDATE", "DELETE"]
        resources    = ["serviceaccounts", "secrets", "roles", "rolebindings", "deployments", "jobs"]
      }]
    }

    match_conditions = [{
      name       = "is-backplane"
      expression = "request.userInfo.username == '${local.backplane_username}'"
    }]

    validations = [{
      expression = "namespaceObject != null && has(namespaceObject.metadata.labels) && '${var.managed_namespace_label}' in namespaceObject.metadata.labels && namespaceObject.metadata.labels['${var.managed_namespace_label}'] == 'true'"
      message    = "The run-controller building block may only change objects in namespaces labeled ${var.managed_namespace_label}=true."
    }]
  }
}

# The provider has no resource for policy bindings yet.
resource "kubernetes_manifest" "managed_namespaces_only_binding" {
  manifest = {
    apiVersion = "admissionregistration.k8s.io/v1"
    kind       = "ValidatingAdmissionPolicyBinding"
    metadata = {
      name = "${var.name}-managed-namespaces-only"
    }
    spec = {
      policyName        = kubernetes_validating_admission_policy_v1.managed_namespaces_only.metadata.name
      validationActions = ["Deny"]
    }
  }
}
