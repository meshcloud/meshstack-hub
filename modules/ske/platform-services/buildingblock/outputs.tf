output "haproxy_lb_ip" {
  description = "External IP of the HAProxy LoadBalancer service. Point application DNS A records here."
  value       = data.kubernetes_service_v1.haproxy_controller.status[0].load_balancer[0].ingress[0].ip
}

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
