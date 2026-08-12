output "namespace" {
  description = "Namespace the gateway runs in."
  value       = kubernetes_namespace_v1.this.metadata[0].name
}

output "service_name" {
  description = "Name of the Service in front of the gateway pods."
  value       = local.service_name

  depends_on = [helm_release.litellm]
}

output "api_base" {
  # The '/v1' suffix belongs to the base URL. A client that drops it gets a 'Not Found' error, so
  # this output carries the suffix instead of leaving it to the caller.
  description = "In-cluster base URL of the gateway, including the '/v1' suffix. Callers send the master key or a virtual key as a bearer token."
  value       = "http://${local.service_name}.${kubernetes_namespace_v1.this.metadata[0].name}.svc.cluster.local:${local.service_port}/v1"

  depends_on = [helm_release.litellm]
}

output "model_aliases" {
  description = "Model aliases the gateway exposes. A caller puts one of them in the 'model' field of a request."
  value       = sort(keys(var.model_backends))
}

output "master_key_secret_name" {
  description = "Name of the secret in the gateway namespace that holds the master key under the 'masterkey' key."
  value       = kubernetes_secret_v1.master_key.metadata[0].name
}
