locals {
  # The id is unknown only until a new cluster exists, so the kubeconfig waits for a new cluster and
  # opens at plan time for an existing one, which a refresh of the admin resources needs.
  cluster_id_parts = split(",", module.cluster.cluster.id)
}

ephemeral "stackit_ske_kubeconfig" "this" {
  project_id   = local.cluster_id_parts[0]
  region       = local.cluster_id_parts[1]
  cluster_name = local.cluster_id_parts[2]
  expiration   = 3600
}

locals {
  ske_kubeconfig = yamldecode(ephemeral.stackit_ske_kubeconfig.this.kube_config)

  admin_name = "meshstack-admin"

  admin_token_month = parseint(substr(var.admin_token_generation, 0, 4), 10) * 12 + parseint(substr(var.admin_token_generation, 5, 2), 10) - 1
  admin_token_generations = toset([
    var.admin_token_generation,
    format("%04d-%02d", floor((local.admin_token_month - 1) / 12), (local.admin_token_month - 1) % 12 + 1),
  ])
}

# Read after the cluster changes, as a new cluster has no API server to read at plan time.
data "kubernetes_config_map_v1" "shoot_info" {
  depends_on = [module.cluster]

  metadata {
    name      = "shoot-info"
    namespace = "kube-system"
  }
}

# The cluster resource does not report its API server; SKE serves it at `api.<shoot domain>`, which
# never changes for the cluster's life.
resource "terraform_data" "kube_host" {
  input = "https://api.${data.kubernetes_config_map_v1.shoot_info.data.domain}"

  lifecycle {
    ignore_changes = [input]
  }
}

resource "kubernetes_service_account_v1" "admin" {
  metadata {
    name      = local.admin_name
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding_v1" "admin" {
  metadata {
    name = local.admin_name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.admin.metadata[0].name
    namespace = kubernetes_service_account_v1.admin.metadata[0].namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
}

# The previous generation stays valid, so a reader that fetched the kubeconfig just before a rotation
# keeps working until the next one.
resource "kubernetes_secret_v1" "admin_token" {
  for_each = local.admin_token_generations

  metadata {
    name      = "${local.admin_name}-token-${each.key}"
    namespace = kubernetes_service_account_v1.admin.metadata[0].namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.admin.metadata[0].name
    }
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}

locals {
  admin_token = kubernetes_secret_v1.admin_token[var.admin_token_generation].data

  admin_kubeconfig = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = module.cluster.cluster.name
    clusters = [{
      name = module.cluster.cluster.name
      cluster = {
        server                     = terraform_data.kube_host.output
        certificate-authority-data = base64encode(local.admin_token["ca.crt"])
      }
    }]
    users = [{
      name = local.admin_name
      user = { token = local.admin_token["token"] }
    }]
    contexts = [{
      name    = module.cluster.cluster.name
      context = { cluster = module.cluster.cluster.name, user = local.admin_name }
    }]
  })
}
