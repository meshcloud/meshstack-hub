locals {
  api_endpoint = var.public_api ? module.cce.cluster_public_ip : module.cce.cluster_private_ip
}

output "cluster_id" {
  value       = module.cce.cluster_id
  description = "ID of the CCE cluster."
}

output "cluster_name" {
  value       = module.cce.cluster_name
  description = "Name of the CCE cluster."
}

output "api_endpoint" {
  value       = local.api_endpoint
  description = "URL of the Kubernetes API: public when `public_api` is set, otherwise private to the VPC."
}

# Holds a cluster-admin client certificate; the application team owns the cluster and needs it.
output "kubeconfig" {
  value       = module.cce.kubeconfig_yaml
  sensitive   = true
  description = "Kubeconfig with cluster-admin access."
}

output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value       = <<-EOT
    # CCE cluster ${module.cce.cluster_name}

    The cluster runs ${var.node_count} worker node(s) of flavor `${var.node_flavor}` in each of
    ${join(", ", var.availability_zones)}, in the project's network.

    Its Kubernetes API is at `${local.api_endpoint}`${var.public_api ? "" : ", reachable only from inside the VPC"}.

    ## Connect

    Copy the **Kubeconfig** output of this building block into a file and point kubectl at it:

    ```sh
    export KUBECONFIG=./kubeconfig.yaml
    kubectl get nodes
    ```

    The kubeconfig carries a cluster-admin certificate. Keep it out of repositories and chat.
  EOT
}
