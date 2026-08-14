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

output "console_url" {
  description = "URL of the admin console. Null when var.public_url is not set, because the console is then reachable in-cluster only."
  value       = var.public_url == null ? null : "${var.public_url}/ui"
}

output "oidc_callback_url" {
  description = "Callback URL to register at the identity provider. Null when var.oidc is not set."
  value       = local.oidc_enabled ? "${var.public_url}/sso/callback" : null
}

output "master_key_secret_name" {
  description = "Name of the secret in the gateway namespace that holds the master key under the 'masterkey' key."
  value       = kubernetes_secret_v1.master_key.metadata[0].name
}

output "service_port" {
  # The chart fixes the port and the module does not take it as an input, so a caller that puts an
  # Ingress in front of the Service reads it here instead of repeating a number it does not own.
  description = "Port the Service in front of the gateway pods listens on. An Ingress backend needs it."
  value       = local.service_port
}
