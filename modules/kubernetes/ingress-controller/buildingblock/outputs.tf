output "haproxy_lb_ip" {
  description = "External IP of the HAProxy LoadBalancer service. Point application DNS A records here before TLS provisioning can complete."
  value       = data.kubernetes_service_v1.haproxy_controller.status[0].load_balancer[0].ingress[0].ip
}

output "ingress_class_name" {
  description = "Name of the IngressClass an application puts on its Ingress to be served by this controller."
  value       = local.ingress_class_name

  depends_on = [module.haproxy]
}

output "cluster_issuer_name" {
  description = "Name of the ClusterIssuer an application references from the cert-manager.io/cluster-issuer annotation on its Ingress."
  value       = local.cluster_issuer_name

  depends_on = [module.issuer]
}

output "haproxy_namespace" {
  description = "Namespace of the HAProxy ingress controller and of the wildcard certificate."
  value       = module.haproxy_namespace.name
}

output "wildcard_certificate_domain" {
  description = "Domain the wildcard certificate `*.<domain>` covers; null without `wildcard_certs`."
  value       = var.wildcard_certs == null ? null : var.wildcard_certs.domain

  depends_on = [module.issuer]
}

output "summary" {
  description = "Markdown summary shown on the building block."
  value       = <<-EOT
    # Kubernetes Ingress Controller

    | Property | Value |
    |----------|-------|
    | **Load Balancer IP** | `${data.kubernetes_service_v1.haproxy_controller.status[0].load_balancer[0].ingress[0].ip}` |
    | **IngressClass** | `${local.ingress_class_name}` |
    | **ClusterIssuer** | `${local.cluster_issuer_name}`, registered at `${local.acme_server}` |
    | **Certificates** | ${var.wildcard_certs == null ? "one per Ingress, over HTTP-01" : "`*.${var.wildcard_certs.domain}` over DNS-01 (${local.wildcard_certificate_ready ? "ready" : "not ready yet"}), served to every Ingress"} |
    | **HAProxy** | chart `${module.haproxy.chart_version}`, ${var.haproxy_replica_count} replicas in `${module.haproxy_namespace.name}` |
    | **cert-manager** | chart `${module.cert_manager.chart_version}` in `${module.cert_manager_namespace.name}` |

    Point the DNS records of your hostnames at the load balancer IP. An Ingress served by this
    controller over HTTPS:

    ```yaml
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: my-app
    %{~if var.wildcard_certs == null~}
      annotations:
        cert-manager.io/cluster-issuer: ${local.cluster_issuer_name}
    %{~endif~}
    spec:
      ingressClassName: ${local.ingress_class_name}
      tls:
        - hosts: [my-app.example.com]
    %{~if var.wildcard_certs == null~}
          secretName: my-app-tls
    %{~endif~}
      rules:
        - host: my-app.example.com
          http:
            paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: my-app
                    port:
                      number: 80
    ```
  EOT

  depends_on = [module.haproxy, module.issuer]
}
