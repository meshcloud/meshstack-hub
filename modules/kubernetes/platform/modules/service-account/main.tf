resource "kubernetes_service_account_v1" "this" {
  lifecycle {
    enabled = !var.release_on_destroy
  }

  metadata {
    name        = var.name
    namespace   = var.namespace
    annotations = var.annotations
  }
}

resource "kubernetes_service_account_v1" "released" {
  lifecycle {
    enabled         = var.release_on_destroy
    destroy         = false
    prevent_destroy = true
  }

  metadata {
    name        = var.name
    namespace   = var.namespace
    annotations = var.annotations
  }
}

# The previous generation stays valid, so meshStack keeps working with a token it read just before a
# rotation.
resource "kubernetes_secret_v1" "token" {
  for_each   = var.token_generations
  depends_on = [kubernetes_service_account_v1.this, kubernetes_service_account_v1.released]

  metadata {
    name      = "${var.name}-token-${each.key}"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/service-account.name" = var.name
    }
  }

  type = "kubernetes.io/service-account-token"
  # The token is filled in asynchronously; waiting keeps it non-empty on the creating apply.
  wait_for_service_account_token = true
}

# An adopted token Secret belongs to the platform registration it was adopted from.
removed {
  from = kubernetes_secret_v1.released

  lifecycle {
    destroy = false
  }
}

resource "kubernetes_cluster_role_v1" "this" {
  lifecycle {
    enabled = !var.release_on_destroy
  }

  metadata {
    name        = var.name
    annotations = var.annotations
  }

  dynamic "rule" {
    for_each = var.rules
    content {
      api_groups        = rule.value.api_groups
      resources         = rule.value.resources
      verbs             = rule.value.verbs
      resource_names    = rule.value.resource_names
      non_resource_urls = rule.value.non_resource_urls
    }
  }
}

resource "kubernetes_cluster_role_v1" "released" {
  lifecycle {
    enabled         = var.release_on_destroy
    destroy         = false
    prevent_destroy = true
  }

  metadata {
    name        = var.name
    annotations = var.annotations
  }

  dynamic "rule" {
    for_each = var.rules
    content {
      api_groups        = rule.value.api_groups
      resources         = rule.value.resources
      verbs             = rule.value.verbs
      resource_names    = rule.value.resource_names
      non_resource_urls = rule.value.non_resource_urls
    }
  }
}

resource "kubernetes_cluster_role_binding_v1" "this" {
  depends_on = [kubernetes_service_account_v1.this, kubernetes_cluster_role_v1.this]

  lifecycle {
    enabled = !var.release_on_destroy
  }

  metadata {
    name        = var.name
    annotations = var.annotations
  }

  subject {
    kind      = "ServiceAccount"
    name      = var.name
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = var.name
  }
}

resource "kubernetes_cluster_role_binding_v1" "released" {
  depends_on = [kubernetes_service_account_v1.released, kubernetes_cluster_role_v1.released]

  lifecycle {
    enabled         = var.release_on_destroy
    destroy         = false
    prevent_destroy = true
  }

  metadata {
    name        = var.name
    annotations = var.annotations
  }

  subject {
    kind      = "ServiceAccount"
    name      = var.name
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = var.name
  }
}

# Flipping the flag on existing state would replace every object above.
resource "terraform_data" "release_on_destroy" {
  input = var.release_on_destroy

  lifecycle {
    ignore_changes = [input]

    postcondition {
      condition     = self.output == var.release_on_destroy
      error_message = "release_on_destroy cannot change once managed."
    }
  }
}
