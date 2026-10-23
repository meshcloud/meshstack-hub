resource "kubernetes_namespace_v1" "connector" {
  metadata {
    name = var.namespace
  }
}

# Service account to be used by building block runs to create service accounts for GH.
resource "kubernetes_service_account_v1" "connector" {
  metadata {
    name      = var.service_account_name
    namespace = kubernetes_namespace_v1.connector.metadata[0].name
  }
}

resource "kubernetes_secret_v1" "connector_token" {
  metadata {
    name      = "${kubernetes_service_account_v1.connector.metadata[0].name}-token"
    namespace = kubernetes_namespace_v1.connector.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.connector.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_cluster_role_v1" "connector" {
  metadata {
    name = kubernetes_service_account_v1.connector.metadata[0].name
  }

  # Because RBAC cannot scope reads to managed namespaces, we at least forbid `list` and `watch` access.
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

  # Clusterrole bind only allowed for the specific role.
  rule {
    api_groups     = ["rbac.authorization.k8s.io"]
    resources      = ["clusterroles"]
    verbs          = ["bind"]
    resource_names = [var.github_actions_cluster_role]
  }
}

resource "kubernetes_cluster_role_binding_v1" "connector" {
  metadata {
    name = kubernetes_service_account_v1.connector.metadata[0].name
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

# Restrict the service account's writes to managed namespaces.
# Admission never sees reads, so `get` on secrets stays cluster-wide.
resource "kubernetes_validating_admission_policy_v1" "managed_namespaces_only" {
  metadata = {
    name = "${kubernetes_service_account_v1.connector.metadata[0].name}-managed-namespaces-only"
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

    # If the request comes from the connector service account.
    match_conditions = [{
      name       = "is-connector"
      expression = "request.userInfo.username == '${local.connector_username}'"
    }]

    # The namespace must have the managed namespace label set to true.
    validations = [{
      expression = "namespaceObject != null && has(namespaceObject.metadata.labels) && '${var.managed_namespace_label}' in namespaceObject.metadata.labels && namespaceObject.metadata.labels['${var.managed_namespace_label}'] == 'true'"
      message    = "The GitHub connector may only change objects in namespaces labeled ${var.managed_namespace_label}=true."
    }]
  }
}

# Use manifest because the provider has no resource for policy bindings yet.
resource "kubernetes_manifest" "managed_namespaces_only_binding" {
  manifest = {
    apiVersion = "admissionregistration.k8s.io/v1"
    kind       = "ValidatingAdmissionPolicyBinding"
    metadata = {
      name = "${kubernetes_service_account_v1.connector.metadata[0].name}-managed-namespaces-only"
    }
    spec = {
      policyName        = kubernetes_validating_admission_policy_v1.managed_namespaces_only.metadata.name
      validationActions = ["Deny"]
    }
  }
}
