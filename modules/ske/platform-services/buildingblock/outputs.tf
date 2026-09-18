output "haproxy_lb_ip" {
  description = "External IP of the HAProxy LoadBalancer service. Point application DNS A records here."
  value       = data.kubernetes_service_v1.haproxy_controller.status[0].load_balancer[0].ingress[0].ip
}

# Read from the data sources (not module.meshplatform.*_token) so the value is the token Kubernetes
# populated after the secret was created — the module's own output can be empty on the creating apply.
output "replicator_token" {
  description = "Service account token meshStack uses to replicate namespaces onto the cluster."
  value       = data.kubernetes_secret.replicator.data["token"]
  sensitive   = true
}

output "metering_token" {
  description = "Service account token meshStack uses to read metering data from the cluster."
  value       = data.kubernetes_secret.metering.data["token"]
  sensitive   = true
}
