output "haproxy_lb_ip" {
  description = "External IP of the HAProxy LoadBalancer service. Point application DNS A records here."
  value       = data.kubernetes_service_v1.haproxy_controller.status[0].load_balancer[0].ingress[0].ip
}

# The module's token secrets wait for Kubernetes to populate them (wait_for_service_account_token), so
# these outputs are reliably non-empty on the creating apply — the composing architecture feeds them
# into the meshstack_platform replication/metering credentials.
output "replicator_token" {
  description = "Service account token meshStack uses to replicate namespaces onto the cluster."
  value       = module.meshplatform.replicator_token
  sensitive   = true
}

output "metering_token" {
  description = "Service account token meshStack uses to read metering data from the cluster."
  value       = module.meshplatform.metering_token
  sensitive   = true
}
