locals {
  forbidden_namespaces = toset(concat(var.forbidden_namespaces, [var.cleanup_namespace]))

  forbidden_exact_namespaces    = [for pattern in local.forbidden_namespaces : pattern if !endswith(pattern, "*")]
  forbidden_namespace_prefixes  = [for pattern in local.forbidden_namespaces : trimsuffix(pattern, "*") if endswith(pattern, "*")]
  namespace_is_forbidden_clause = "request.namespace in ${jsonencode(local.forbidden_exact_namespaces)} || ${jsonencode(local.forbidden_namespace_prefixes)}.exists(prefix, request.namespace.startsWith(prefix))"

  # CEL string literals. JSON string escaping is valid CEL.
  binding_label_literal     = jsonencode(local.binding_label)
  expiry_annotation_literal = jsonencode(local.expiry_annotation)
  cluster_role_literal      = jsonencode(var.cluster_role)

  guarded_usernames = [
    google_service_account.buildingblock.email,
    "system:serviceaccount:${kubernetes_service_account_v1.cleanup.metadata[0].namespace}:${kubernetes_service_account_v1.cleanup.metadata[0].name}",
  ]
}

# RBAC can't limit RoleBindings by label or by subject. Without this policy the building block could
# delete any RoleBinding in the cluster, or bind cluster_role to a whole group.
# kubernetes_manifest, because the provider has no resource for ValidatingAdmissionPolicyBinding.
resource "kubernetes_manifest" "rolebinding_policy" {
  manifest = {
    apiVersion = "admissionregistration.k8s.io/v1"
    kind       = "ValidatingAdmissionPolicy"
    metadata = {
      name = "${var.service_account_id}-rolebindings"
    }
    spec = {
      failurePolicy = "Fail"
      matchConstraints = {
        resourceRules = [{
          apiGroups   = ["rbac.authorization.k8s.io"]
          apiVersions = ["*"]
          operations  = ["CREATE", "UPDATE", "DELETE"]
          resources   = ["rolebindings"]
        }]
      }
      matchConditions = [{
        name       = "from-gke-temporary-access"
        expression = "request.userInfo.username in ${jsonencode(local.guarded_usernames)}"
      }]
      # Evaluated lazily, so oldObject being null on CREATE and object being null on DELETE is fine.
      variables = [
        {
          name       = "old_is_managed"
          expression = "has(oldObject.metadata.labels) && ${local.binding_label_literal} in oldObject.metadata.labels && oldObject.metadata.labels[${local.binding_label_literal}] == 'true'"
        },
        {
          name       = "new_is_managed"
          expression = "has(object.metadata.labels) && ${local.binding_label_literal} in object.metadata.labels && object.metadata.labels[${local.binding_label_literal}] == 'true'"
        },
      ]
      validations = [
        # Deletes are allowed even on forbidden namespaces so that we can revoke access if forbidden namespaces change.
        {
          expression        = "request.operation == 'DELETE' || !(${local.namespace_is_forbidden_clause})"
          messageExpression = "'Namespace ' + request.namespace + ' is forbidden.'"
          reason            = "Forbidden"
        },
        {
          expression = "request.operation == 'CREATE' || variables.old_is_managed"
          message    = "May only update or delete RoleBindings labelled ${local.binding_label}=true."
          reason     = "Forbidden"
        },
        {
          expression = "request.operation == 'DELETE' || (variables.new_is_managed && has(object.metadata.annotations) && ${local.expiry_annotation_literal} in object.metadata.annotations)"
          message    = "RoleBindings must be labelled ${local.binding_label}=true and annotated with ${local.expiry_annotation}."
          reason     = "Forbidden"
        },
        {
          # Kubernetes reserves the system: prefix for built-in identities such as system:anonymous
          # and ServiceAccounts, which a User subject could otherwise name.
          expression = "request.operation == 'DELETE' || object.subjects.all(s, s.kind == 'User' && !s.name.startsWith('system:'))"
          message    = "RoleBinding subjects must be Users whose names do not start with 'system:'."
          reason     = "Forbidden"
        },
        {
          expression = "request.operation == 'DELETE' || (object.roleRef.kind == 'ClusterRole' && object.roleRef.name == ${local.cluster_role_literal})"
          message    = "RoleBindings must reference the ClusterRole ${var.cluster_role}."
          reason     = "Forbidden"
        },
      ]
    }
  }
}

resource "kubernetes_manifest" "rolebinding_policy_binding" {
  manifest = {
    apiVersion = "admissionregistration.k8s.io/v1"
    kind       = "ValidatingAdmissionPolicyBinding"
    metadata = {
      name = kubernetes_manifest.rolebinding_policy.manifest.metadata.name
    }
    spec = {
      policyName        = kubernetes_manifest.rolebinding_policy.manifest.metadata.name
      validationActions = ["Deny"]
    }
  }
}

# RBAC refuses a RoleBinding to a role its creator doesn't hold, unless the creator has `bind` on
# that role. `bind` on the one role alone keeps the building block from binding other roles.
resource "kubernetes_cluster_role_v1" "grant_access" {
  metadata {
    name = "${var.service_account_id}-grant-access"
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["rolebindings"]
    verbs      = ["get", "list", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups     = ["rbac.authorization.k8s.io"]
    resources      = ["clusterroles"]
    verbs          = ["bind"]
    resource_names = [var.cluster_role]
  }
}

# Cluster-wide, because RBAC can't exclude namespaces.
resource "kubernetes_cluster_role_binding_v1" "grant_access" {
  depends_on = [kubernetes_manifest.rolebinding_policy_binding]

  metadata {
    name = kubernetes_cluster_role_v1.grant_access.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.grant_access.metadata[0].name
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name      = google_service_account.buildingblock.email
  }
}
