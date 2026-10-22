# The names below are cluster-global: `meshfed-service` and `meshfed-metering` are ClusterRoles, and
# two of these deployed to one cluster would collide. That is fine here — each platform ordered from
# the STACKIT Kubernetes Platform reference architecture gets a cluster of its own — and it is why
# the upstream module's `name_suffix` / `existing_clusterrole_name` machinery is not carried over.
# Reintroduce it if a cluster ever has to carry more than one meshStack platform registration.
locals {
  replicator_name = "meshfed-service"
  metering_name   = "meshfed-metering"

  service_accounts = merge({
    replicator = {
      name = local.replicator_name
      annotations = {
        "io.meshcloud/meshstack.replicator-kubernetes.version" = "1.0"
      }
      rules = concat([
        {
          api_groups     = [""]
          resources      = ["namespaces"]
          verbs          = ["get", "list", "watch", "create", "delete", "update"]
          resource_names = null
        },
        {
          api_groups     = [""]
          resources      = ["resourcequotas", "resourcequotas/status"]
          verbs          = ["get", "list", "watch", "create", "delete", "deletecollection", "patch", "update"]
          resource_names = null
        },
        {
          api_groups     = [""]
          resources      = ["appliedclusterresourcequotas", "clusterresourcequotas", "clusterresourcequotas/status"]
          verbs          = ["get", "list", "watch", "create", "delete", "deletecollection", "patch", "update"]
          resource_names = null
        },
        {
          api_groups     = ["", "rbac.authorization.k8s.io"]
          resources      = ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
          verbs          = ["get", "list", "watch"]
          resource_names = null
        },
        {
          api_groups     = ["", "rbac.authorization.k8s.io"]
          resources      = ["rolebindings"]
          verbs          = ["create", "delete", "update"]
          resource_names = null
        },
        {
          api_groups     = ["", "rbac.authorization.k8s.io"]
          resources      = ["clusterroles"]
          verbs          = ["bind"]
          resource_names = ["admin", "edit", "view"]
        },
      ], var.replicator_additional_rules)
    }
    }, !var.metering_enabled ? {} : {
    metering = {
      name = local.metering_name
      annotations = {
        "io.meshcloud/meshstack.metering-kubernetes.version" = "1.0"
      }
      rules = concat([
        {
          api_groups     = [""]
          resources      = ["pods", "persistentvolumeclaims"]
          verbs          = ["get", "list"]
          resource_names = null
        },
      ], var.metering_additional_rules)
    }
  })

  token_month = parseint(substr(var.token_generation, 0, 4), 10) * 12 + parseint(substr(var.token_generation, 5, 2), 10) - 1
  token_generations = toset([
    var.token_generation,
    format("%04d-%02d", floor((local.token_month - 1) / 12), (local.token_month - 1) % 12 + 1),
  ])

  replicator_token = module.service_accounts["replicator"].token
  # meshStack fails a building block whose declared output is null.
  metering_token = var.metering_enabled ? module.service_accounts["metering"].token : ""
}

resource "terraform_data" "kubeconfig" {
  lifecycle {
    precondition {
      condition     = fileexists("${path.module}/kubeconfig.yaml")
      error_message = "kubeconfig.yaml is missing. meshStack writes it from the FILE input of the building block."
    }
  }
}

module "namespace" {
  source = "./modules/namespace"

  depends_on = [terraform_data.kubeconfig]

  release_on_destroy = var.release_on_destroy
  name               = var.service_account_namespace
}

module "service_accounts" {
  source   = "./modules/service-account"
  for_each = local.service_accounts

  release_on_destroy = var.release_on_destroy
  name               = each.value.name
  namespace          = module.namespace.name
  annotations        = each.value.annotations
  rules              = each.value.rules

  token_generations        = local.token_generations
  current_token_generation = var.token_generation
}
