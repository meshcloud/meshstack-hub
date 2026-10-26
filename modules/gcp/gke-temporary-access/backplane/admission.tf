locals {
  system_namespaces    = ["kube-*", "gke-*", "gmp-*"]
  forbidden_namespaces = setunion(local.system_namespaces, var.forbidden_namespaces, [kubernetes_namespace_v1.cleanup.metadata[0].name])

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
      validations = [
        # Deletes stay allowed, so access granted before a namespace became forbidden can still end.
        {
          expression        = "request.operation == 'DELETE' || !(${local.namespace_is_forbidden_clause})"
          messageExpression = "'Namespace ' + request.namespace + ' is forbidden.'"
          reason            = "Forbidden"
        },
        {
          expression = "request.operation == 'CREATE' || (has(oldObject.metadata.labels) && ${local.binding_label_literal} in oldObject.metadata.labels && oldObject.metadata.labels[${local.binding_label_literal}] == 'true')"
          message    = "May only update or delete RoleBindings labelled ${local.binding_label}=true."
          reason     = "Forbidden"
        },
        {
          expression = "request.operation == 'DELETE' || (has(object.metadata.labels) && ${local.binding_label_literal} in object.metadata.labels && object.metadata.labels[${local.binding_label_literal}] == 'true' && has(object.metadata.annotations) && ${local.expiry_annotation_literal} in object.metadata.annotations)"
          message    = "RoleBindings must be labelled ${local.binding_label}=true and annotated with ${local.expiry_annotation}."
          reason     = "Forbidden"
        },
        {
          expression = "request.operation == 'DELETE' || (has(object.subjects) && size(object.subjects) == 1 && object.subjects[0].kind == 'User')"
          message    = "RoleBindings must have exactly one subject of kind User."
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
