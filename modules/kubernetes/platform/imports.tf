locals {
  namespace_imports         = var.imports == null ? toset([]) : toset([var.service_account_namespace])
  service_account_imports   = var.imports == null ? {} : { for key, account in local.service_accounts : key => account.name }
  released_namespaces       = var.release_on_destroy ? local.namespace_imports : toset([])
  managed_namespaces        = var.release_on_destroy ? toset([]) : local.namespace_imports
  released_service_accounts = var.release_on_destroy ? local.service_account_imports : {}
  managed_service_accounts  = var.release_on_destroy ? {} : local.service_account_imports
}

import {
  for_each = local.managed_namespaces
  to       = module.namespace.kubernetes_namespace_v1.this
  id       = each.value
}

import {
  for_each = local.released_namespaces
  to       = module.namespace.kubernetes_namespace_v1.released
  id       = each.value
}

import {
  for_each = local.managed_service_accounts
  to       = module.service_accounts[each.key].kubernetes_service_account_v1.this
  id       = "${var.service_account_namespace}/${each.value}"
}

import {
  for_each = local.released_service_accounts
  to       = module.service_accounts[each.key].kubernetes_service_account_v1.released
  id       = "${var.service_account_namespace}/${each.value}"
}



import {
  for_each = local.managed_service_accounts
  to       = module.service_accounts[each.key].kubernetes_cluster_role_v1.this
  id       = each.value
}

import {
  for_each = local.released_service_accounts
  to       = module.service_accounts[each.key].kubernetes_cluster_role_v1.released
  id       = each.value
}

import {
  for_each = local.managed_service_accounts
  to       = module.service_accounts[each.key].kubernetes_cluster_role_binding_v1.this
  id       = each.value
}

import {
  for_each = local.released_service_accounts
  to       = module.service_accounts[each.key].kubernetes_cluster_role_binding_v1.released
  id       = each.value
}
