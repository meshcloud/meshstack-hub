---
name: Kubernetes Service Account
supportedPlatforms:
  - kubernetes
description: Creates a Kubernetes service account with ClusterRole binding and generates a kubeconfig for authentication
---

# Kubernetes Service Account Building Block

Creates and manages a Kubernetes service account with role binding to a specified ClusterRole, and generates a kubeconfig file for authentication.

This documentation is intended as a reference for cloud foundation or platform engineers using this module.

## Prerequisites

- Access to a Kubernetes cluster
- A service account with permissions to create service accounts, secrets, and role bindings
- Cluster CA certificate (base64 encoded)
- Token for the service account executing this module

## Features

- Creates a Kubernetes service account in a specified namespace
- Creates a secret with service account token
- Binds the service account to a specified ClusterRole (admin, edit, view, or custom)
- Generates a ready-to-use kubeconfig file as output

> ⚠️ **Security Notice**: The `kubeconfig` output contains a service account token that grants access to the Kubernetes cluster. When displayed as plain text in meshStack, this sensitive credential will be visible to users who can view the building block outputs. Ensure that only authorized users have access to view these outputs, and advise users to store the kubeconfig securely after retrieval.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.38 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_role_binding.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding) | resource |
| [kubernetes_secret.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_service_account.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_ca_certificate"></a> [cluster\_ca\_certificate](#input\_cluster\_ca\_certificate) | Cluster CA certificate, base64 encoded | `string` | n/a | yes |
| <a name="input_cluster_endpoint"></a> [cluster\_endpoint](#input\_cluster\_endpoint) | IP address of the cluster control plane | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the k8s cluster hosting this service account | `string` | n/a | yes |
| <a name="input_cluster_role"></a> [cluster\_role](#input\_cluster\_role) | ClusterRole to bind the service account with. e.g. admin, edit, view (or any custom cluster role) | `string` | n/a | yes |
| <a name="input_context"></a> [context](#input\_context) | Defines which cluster to interact with. Can be any name | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Service account name | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace where the service account will be created. Recommended: Use platform tenant ID as input in meshStack | `string` | n/a | yes |
| <a name="input_token"></a> [token](#input\_token) | Token for the service account executing this module (not this service account) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_instructions"></a> [instructions](#output\_instructions) | Instructions for using the kubeconfig |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Kubeconfig file content for authenticating with the Kubernetes cluster |
<!-- END_TF_DOCS -->
