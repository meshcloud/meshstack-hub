output "namespace" {
  description = "Namespace this tenant's Langfuse instance runs in."
  value       = kubernetes_namespace_v1.this.metadata[0].name
}

output "release_name" {
  description = "Helm release name of this tenant's Langfuse instance."
  value       = var.release_name
}

output "web_service_name" {
  description = "Name of the Service in front of the Langfuse web pods."
  value       = local.web_service_name

  depends_on = [helm_release.langfuse]
}

output "host" {
  description = "Fully qualified in-cluster hostname of the Langfuse web Service."
  value       = local.web_service_host

  depends_on = [helm_release.langfuse]
}

output "port" {
  description = "Port the Langfuse web Service listens on."
  value       = local.web_service_port
}

output "base_url" {
  # LiteLLM's langfuse_otel callback appends '/api/public/otel' to the host it is given, so this
  # value goes into LANGFUSE_OTEL_HOST unchanged.
  description = "In-cluster base URL of this Langfuse instance, with the scheme and the port. Set it as LANGFUSE_OTEL_HOST on a LiteLLM gateway that traces into this instance."
  value       = local.base_url

  depends_on = [helm_release.langfuse]
}

output "public_url" {
  description = "Canonical external URL of this Langfuse instance. It is what NEXTAUTH_URL is set to and what a browser opens."
  value       = local.public_url
}

output "oidc_callback_url" {
  description = "Callback URL to register at the OIDC provider for this tenant's client. Null when var.oidc is not set."
  value       = local.oidc_enabled ? "${local.public_url}/api/auth/callback/custom" : null
}

output "project_id" {
  description = "Identifier of the project Langfuse created. Traces belong to it and the API keypair is scoped to it."
  value       = var.init_project_id
}

output "project_public_key" {
  # Not a secret on its own, but it is half of a credential and a caller passes it around with the
  # secret key, so it is marked as well.
  description = "Public key of the project API keypair. A tracing client sends it together with the secret key as basic auth, for example as LANGFUSE_PUBLIC_KEY on a LiteLLM gateway."
  value       = var.init_project_public_key
  sensitive   = true

  depends_on = [helm_release.langfuse]
}

output "project_secret_key" {
  description = "Secret key of the project API keypair. A tracing client sends it together with the public key as basic auth, for example as LANGFUSE_SECRET_KEY on a LiteLLM gateway."
  value       = var.init_project_secret_key
  sensitive   = true

  depends_on = [helm_release.langfuse]
}
