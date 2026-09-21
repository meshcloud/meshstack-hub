output "haproxy_lb_ip" {
  description = "External IP of the HAProxy LoadBalancer service. Point your DNS A record here before TLS provisioning can complete."
  value       = data.kubernetes_service_v1.haproxy_controller.status[0].load_balancer[0].ingress[0].ip
}

output "ingress_class_name" {
  description = "Name of the IngressClass an application puts on its Ingress to be served by this controller."
  value       = var.ingress_class_name

  depends_on = [helm_release.haproxy]
}

output "cluster_issuer_name" {
  description = "Name of the ClusterIssuer an application references from the cert-manager.io/cluster-issuer annotation on its Ingress."
  value       = var.cluster_issuer_name

  depends_on = [helm_release.issuer]
}

output "haproxy_namespace" {
  description = "Namespace of the HAProxy ingress controller and of the wildcard certificate secret."
  value       = kubernetes_namespace_v1.haproxy_ingress.metadata[0].name
}

output "wildcard_certificate_domain" {
  description = "Domain the wildcard certificate covers, so the certificate is issued for `*.<domain>`. Equals dns01.zone_name when the caller set no dns01.certificate_domain. Null when dns01 is not set."
  value       = local.dns01_certificate_domain

  depends_on = [helm_release.issuer]
}

output "wildcard_certificate_secret_name" {
  description = "Name of the secret in haproxy_namespace holding the wildcard certificate. Null when dns01 is not set."
  value       = local.dns01_enabled ? var.wildcard_certificate_name : null

  depends_on = [helm_release.issuer]
}
