output "config_tf" {
  description = "Generates a config.tf that can be dropped into meshStack's BuildingBlockDefinition as an encrypted file input to configure this building block."
  sensitive   = true
  value       = <<-EOF
    provider "kubernetes" {
    host = "${var.cluster_host}"
    cluster_ca_certificate = base64decode("${var.cluster_ca_certificate}")
    client_certificate = base64decode("${var.client_certificate}")
    client_key = base64decode("${var.client_key}")
  }
  EOF
}

output "kubeconfig_cluster_name" {
  description = "Cluster name to use when merging static kubeconfig and generated service-account credentials."
  value       = "stackit_k8s"
}
