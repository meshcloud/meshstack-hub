output "cluster_issuer_name" {
  description = "Name of the ACME ClusterIssuer. Application teams put this in the `cert-manager.io/cluster-issuer` annotation on their Ingress to get a certificate."
  value       = kubernetes_manifest.clusterissuer_letsencrypt_prod.manifest.metadata.name
}
