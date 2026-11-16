resource "stackit_service_account" "this" {
  project_id = var.project_id
  name       = "cert-manager-dns01"
}

# STACKIT grants DNS rights per project only.
resource "stackit_authorization_project_role_assignment" "dns_admin" {
  resource_id = var.project_id
  role        = "dns.admin"
  subject     = stackit_service_account.this.email
}

resource "stackit_service_account_key" "this" {
  project_id            = var.project_id
  service_account_email = stackit_service_account.this.email
}

resource "kubernetes_secret_v1" "key" {
  metadata {
    name      = "stackit-sa-authentication"
    namespace = var.cert_manager_namespace
  }

  data = {
    "sa.json" = stackit_service_account_key.this.json
  }
}

# cert-manager has no built-in solver for STACKIT DNS.
resource "helm_release" "webhook" {
  name       = "stackit-cert-manager-webhook"
  namespace  = var.cert_manager_namespace
  repository = "https://stackitcloud.github.io/stackit-cert-manager-webhook"
  chart      = "stackit-cert-manager-webhook"
  version    = "0.5.1"
  wait       = true
  timeout    = 300

  values = [
    yamlencode({
      groupName = local.group_name
      certManager = {
        namespace          = var.cert_manager_namespace
        serviceAccountName = "cert-manager"
      }
      stackitSaAuthentication = {
        enabled    = true
        secretName = kubernetes_secret_v1.key.metadata[0].name
      }
      resources = {
        requests = { cpu = "10m", memory = "64Mi" }
        limits   = { cpu = "100m", memory = "128Mi" }
      }
    })
  ]
}

locals {
  group_name = "acme.stackit.de"
}

# Helm waits for the webhook pod only; the aggregator marks the APIService Available seconds later.
resource "time_sleep" "solver_api" {
  create_duration = "30s"
  triggers        = { revision = tostring(helm_release.webhook.metadata.revision) }
}

# cert-manager reaches the solver through this APIService.
data "kubernetes_resource" "solver_api" {
  api_version = "apiregistration.k8s.io/v1"
  kind        = "APIService"

  metadata {
    name = "v1alpha1.${local.group_name}"
  }

  depends_on = [time_sleep.solver_api]

  lifecycle {
    postcondition {
      # try: an APIService the aggregator has not checked yet has no status.conditions.
      condition     = anytrue([for c in try(self.object.status.conditions, []) : c.type == "Available" && c.status == "True"])
      error_message = "The APIService v1alpha1.${local.group_name} of the STACKIT cert-manager webhook is not Available, so cert-manager cannot solve DNS-01 challenges. See the webhook pod in ${var.cert_manager_namespace}."
    }
  }
}
