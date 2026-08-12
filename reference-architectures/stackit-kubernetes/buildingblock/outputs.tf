output "cluster_name" {
  description = "Name of the SKE cluster."
  value       = module.cluster.cluster_name
}

output "cluster_url" {
  description = "Deep link to the STACKIT project that holds the cluster."
  value       = "https://portal.stackit.cloud/projects/${var.stackit_project_id}"
}

output "platform_identifier" {
  description = "Identifier of the Kubernetes platform registered in meshStack, in the `<name>.<location>` form."
  value       = module.platform.platform_identifier
}

output "landing_zones" {
  description = "Namespace landing zones created for the platform."
  value       = join(", ", values(module.platform.landing_zone_identifiers))
}

output "apps_domain" {
  description = "Domain the cluster's application hostnames live under, `<cluster_name>.<dns_parent_zone_name>` by default. The wildcard certificate covers it. Empty when the architecture runs without DNS."
  value       = local.dns_enabled ? local.dns_apps_domain : ""
}

output "ingress_ip" {
  description = "External address of the HAProxy load balancer. Empty when `expose` is `none`."
  value       = var.expose == "none" ? "" : one(module.ingress[*].haproxy_lb_ip)
}

output "ingress_class_name" {
  description = "IngressClass an application puts on its Ingress to be served by this cluster's controller. Empty when `expose` is `none`."
  value       = var.expose == "none" ? "" : one(module.ingress[*].ingress_class_name)
}

output "cluster_issuer_name" {
  description = "ClusterIssuer an application references from the `cert-manager.io/cluster-issuer` annotation on its Ingress. Empty when `expose` is `none`."
  value       = var.expose == "none" ? "" : one(module.ingress[*].cluster_issuer_name)
}

output "kubeconfig" {
  description = "Kubeconfig of the cluster. Composed architectures consume it as a static input, for example to install a gateway by Helm."
  value       = yamlencode(module.cluster.kubeconfig)
  sensitive   = true
}
