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
  description = "Namespace of the HAProxy ingress controller and of the wildcard certificate secret."
  value       = module.ingress.haproxy_namespace
}

output "wildcard_certificate_domain" {
  description = "Domain the wildcard certificate covers, so the certificate is issued for `*.<domain>`. Null when dns01 is not set."
  value       = module.ingress.wildcard_certificate_domain
}

output "wildcard_certificate_secret_name" {
  description = "Name of the secret in haproxy_namespace holding the wildcard certificate. Null when dns01 is not set."
  value       = module.ingress.wildcard_certificate_secret_name
}
