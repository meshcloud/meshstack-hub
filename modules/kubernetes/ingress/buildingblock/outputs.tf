output "haproxy_lb_ip" {
  description = "External IP of the HAProxy LoadBalancer service. Point application DNS A records here before TLS provisioning can complete."
  value       = module.ingress.haproxy_lb_ip
}

output "ingress_class_name" {
  description = "Name of the IngressClass an application puts on its Ingress to be served by this controller."
  value       = module.ingress.ingress_class_name
}

output "cluster_issuer_name" {
  description = "Name of the ClusterIssuer an application references from the cert-manager.io/cluster-issuer annotation on its Ingress."
  value       = module.ingress.cluster_issuer_name
}

output "haproxy_namespace" {
  description = "Namespace of the HAProxy ingress controller."
  value       = module.ingress.haproxy_namespace
}
