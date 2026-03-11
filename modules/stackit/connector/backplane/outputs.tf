output "config_tf" {
  description = "Generates a config.tf that can be dropped into meshStack's BuildingBlockDefinition as an encrypted file input to configure this building block."
  sensitive   = true
  value       = <<-EOF
    provider "kubernetes" {
    host = "${var.cluster_host}"
    cluster_ca_certificate = base64decode("${var.cluster_ca_certificate}")
    client_certificate = base64decode("${var.client_certificate}")
    client_key = base64decode("${var.client_key}")
  }

  locals {
    stackit_kubeconfig_stub = {
      apiVersion      = "v1"
      kind            = "Config"
      current-context = "stackit_k8s"

      clusters = [
        {
          name = "stackit_k8s"
          cluster = {
            server = "${var.cluster_host}"
            certificate-authority-data = "${var.cluster_ca_certificate}"
          }
        }
      ]
    }

    harbor = {
      host     = "${var.harbor_host}"
      username = "${var.harbor_username}"
      password = "${var.harbor_password}"
    }

    forgejo = {
      host             = "${var.forgejo_host}"
      api_token        = "${var.forgejo_api_token}"
      repository_name  = "${var.forgejo_repository_name}"
      repository_owner = "${var.forgejo_repository_owner}"
    }

  }
  EOF
}