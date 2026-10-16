moved {
  from = kubernetes_namespace_v1.meshcloud
  to   = module.namespace.kubernetes_namespace_v1.this
}

moved {
  from = kubernetes_service_account_v1.replicator
  to   = module.service_accounts["replicator"].kubernetes_service_account_v1.this
}

moved {
  from = kubernetes_secret_v1.replicator
  to   = module.service_accounts["replicator"].kubernetes_secret_v1.this
}

moved {
  from = kubernetes_cluster_role_v1.replicator
  to   = module.service_accounts["replicator"].kubernetes_cluster_role_v1.this
}

moved {
  from = kubernetes_cluster_role_binding_v1.replicator
  to   = module.service_accounts["replicator"].kubernetes_cluster_role_binding_v1.this
}

moved {
  from = kubernetes_service_account_v1.metering[0]
  to   = kubernetes_service_account_v1.metering
}

moved {
  from = kubernetes_secret_v1.metering[0]
  to   = kubernetes_secret_v1.metering
}

moved {
  from = kubernetes_cluster_role_v1.metering[0]
  to   = kubernetes_cluster_role_v1.metering
}

moved {
  from = kubernetes_cluster_role_binding_v1.metering[0]
  to   = kubernetes_cluster_role_binding_v1.metering
}

moved {
  from = kubernetes_service_account_v1.metering
  to   = module.service_accounts["metering"].kubernetes_service_account_v1.this
}

moved {
  from = kubernetes_secret_v1.metering
  to   = module.service_accounts["metering"].kubernetes_secret_v1.this
}

moved {
  from = kubernetes_cluster_role_v1.metering
  to   = module.service_accounts["metering"].kubernetes_cluster_role_v1.this
}

moved {
  from = kubernetes_cluster_role_binding_v1.metering
  to   = module.service_accounts["metering"].kubernetes_cluster_role_binding_v1.this
}
