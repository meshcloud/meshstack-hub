output "namespace" {
  description = "Namespace the ClickHouse cluster runs in."
  value       = kubernetes_namespace_v1.clickhouse.metadata[0].name
}

output "cluster_name" {
  description = "Name of the ClickHouseCluster and KeeperCluster resources."
  value       = var.cluster_name
}

output "host" {
  description = "Fully qualified in-cluster hostname of the ClickHouse headless Service. Pass it to the Langfuse chart as clickhouse.host."
  value       = local.host

  depends_on = [helm_release.cluster]
}

output "http_port" {
  description = "HTTP port of ClickHouse. Langfuse reads and writes trace data over it and the chart takes it as clickhouse.httpPort."
  value       = local.http_port
}

output "native_port" {
  description = "Native protocol port of ClickHouse. The golang-migrate migrations and clickhouse-client use it, and the Langfuse chart takes it as clickhouse.nativePort."
  value       = local.native_port
}

output "ddl_cluster_name" {
  description = "Name of the ClickHouse cluster as the server knows it. Every ON CLUSTER statement — the Langfuse migrations included — names it."
  value       = local.ddl_cluster_name
}

output "admin_username" {
  description = "Name of the administrative ClickHouse user. Use it to create the per-tenant databases and users."
  value       = var.admin_username
}

output "admin_password" {
  description = "Password of the administrative ClickHouse user. It grants full access to every tenant's database, so never pass it to a tenant."
  value       = var.admin_password
  sensitive   = true
}

output "admin_secret" {
  description = "Name and key of the Kubernetes Secret in the ClickHouse namespace that holds the administrative password. A Job that creates per-tenant databases can mount it instead of taking the value through Terraform."
  value = {
    name      = kubernetes_secret_v1.admin.metadata[0].name
    namespace = kubernetes_namespace_v1.clickhouse.metadata[0].name
    key       = local.admin_secret_key
  }
}
