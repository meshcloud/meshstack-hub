# Lets the tokens of one Kubernetes service account, and only those, act as the workload service account.
resource "stackit_service_account_federated_identity_provider" "this" {
  project_id            = var.stackit_project_id
  service_account_email = var.workload_service_account_email
  # Federation names are unique per service account and every building block adds one.
  name   = "k8s-${substr(sha256("${var.kubernetes_oidc_issuer} ${local.subject}"), 0, 16)}"
  issuer = var.kubernetes_oidc_issuer

  assertions = [
    {
      item     = "aud"
      operator = "equals"
      value    = var.audience
    },
    {
      item     = "sub"
      operator = "equals"
      value    = local.subject
    }
  ]
}

locals {
  subject = "system:serviceaccount:${var.namespace}:${var.kubernetes_service_account_name}"
}
