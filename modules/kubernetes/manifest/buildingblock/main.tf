resource "helm_release" "this" {
  name      = var.release_name
  namespace = var.namespace
  chart     = path.module

  atomic  = true
  timeout = 300

  values = [var.values_yaml]

  lifecycle {
    precondition {
      condition     = local.kubeconfig_cluster["server"] != "https://example.invalid"
      error_message = "Mock kubeconfig detected. Ensure meshStack injected kubeconfig.yaml before apply."
    }
  }
}
