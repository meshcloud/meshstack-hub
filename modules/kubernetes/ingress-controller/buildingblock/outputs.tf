output "haproxy_lb_ip" {
  description = "External IP of the HAProxy LoadBalancer service. Point application DNS A records here before TLS provisioning can complete."
  value       = data.kubernetes_service_v1.haproxy_controller.status[0].load_balancer[0].ingress[0].ip
}

output "ingress_class_name" {
  description = "Name of the IngressClass an application puts on its Ingress to be served by this controller."
  value       = var.ingress_class_name

  depends_on = [module.haproxy]
}

output "cluster_issuer_name" {
  description = "Name of the ClusterIssuer an application references from the cert-manager.io/cluster-issuer annotation on its Ingress."
  value       = var.cluster_issuer_name

  depends_on = [module.issuer]
}

output "haproxy_namespace" {
  description = "Namespace of the HAProxy ingress controller."
  value       = module.haproxy_namespace.name
}

output "summary" {
  description = "Markdown summary shown on the building block."
  value       = <<-EOT
    # Kubernetes Ingress Controller

    | Property | Value |
    |----------|-------|
    | **Load Balancer IP** | `${data.kubernetes_service_v1.haproxy_controller.status[0].load_balancer[0].ingress[0].ip}` |
    | **IngressClass** | `${var.ingress_class_name}` |
    | **ClusterIssuer** | `${var.cluster_issuer_name}`, registered at `${var.acme_server}` |
    | **Certificates** | one per hostname, over HTTP-01 |
    | **HAProxy** | chart `${var.haproxy_version}`, ${var.haproxy_replica_count} replicas in `${module.haproxy_namespace.name}` |
    | **cert-manager** | chart `${var.cert_manager_version}` in `${module.cert_manager_namespace.name}` |

    Point the DNS records of your hostnames at the load balancer IP. An Ingress served by this
    controller, with a certificate from Let's Encrypt:

    ```yaml
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: my-app
      annotations:
        cert-manager.io/cluster-issuer: ${var.cluster_issuer_name}
    spec:
      ingressClassName: ${var.ingress_class_name}
      tls:
        - hosts: [my-app.example.com]
          secretName: my-app-tls
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
