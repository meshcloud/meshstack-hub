---
name: T Cloud Public CCE Cluster
supportedPlatforms:
  - otc
description: |
  Provisions a Cloud Container Engine (CCE) Kubernetes cluster with one worker node pool per availability zone in a T Cloud Public project's network.
requiresBackplane: true
---

# T Cloud Public CCE Cluster Building Block

Creates a CCE cluster in the VPC and subnet that the [T Cloud Public Network](../../network)
building block created in the same project, with one worker node pool per availability zone. It wraps
the [iits-consulting CCE module](https://github.com/iits-consulting/terraform-opentelekomcloud-cce),
pinned to a release tag.

The VPC and subnet come from its parent T Cloud Public Network building block, whose `vpc_id` and
`subnet_id` outputs meshStack passes in. The worker nodes pull images from the internet through the
network's SNAT gateway.

Node volumes are not KMS-encrypted: that needs an `EVSAccessKMS` agency in the domain, which this
building block does not create.

## Authentication

The building block holds no access key. Its runs sign in through workload identity federation: the
pre-run script from [`otc/workload-identity`](../../workload-identity) exchanges the run token at
the identity provider in `OTC_IDENTITY_PROVIDER`, which the [backplane](../backplane) federates, for
a temporary access key valid for one hour. The provider reads it from the file the script writes.
Without that file, as outside meshStack, it reads `OS_ACCESS_KEY` and `OS_SECRET_KEY` from the
environment.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_opentelekomcloud"></a> [opentelekomcloud](#requirement\_opentelekomcloud) | >= 1.37.0, < 2.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cce"></a> [cce](#module\_cce) | git::https://github.com/iits-consulting/terraform-opentelekomcloud-cce.git | v7.6.0 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | Availability zones of the worker nodes. Each zone gets its own node pool of `node_count` nodes. | `list(string)` | <pre>[<br/>  "eu-de-01"<br/>]</pre> | no |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | Kubernetes version of the cluster, as CCE names it, e.g. `v1.31`. Must be one CCE still offers. | `string` | `"v1.31"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the CCE cluster. Also prefixes its node pools and key pair. | `string` | n/a | yes |
| <a name="input_node_count"></a> [node\_count](#input\_node\_count) | Number of worker nodes per availability zone. | `number` | `2` | no |
| <a name="input_node_flavor"></a> [node\_flavor](#input\_node\_flavor) | ECS flavor of the worker nodes, e.g. `s3.xlarge.4` (4 vCPUs, 16 GiB). | `string` | `"s3.xlarge.4"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | ID of the T Cloud Public project the cluster is created in. | `string` | n/a | yes |
| <a name="input_public_api"></a> [public\_api](#input\_public\_api) | Bind an elastic IP to the Kubernetes API, so it is reachable from the internet. Without it the API is reachable only from inside the VPC. | `bool` | `true` | no |
| <a name="input_region"></a> [region](#input\_region) | T Cloud Public region of the project. | `string` | `"eu-de"` | no |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | ID of the subnet, from the parent T Cloud Public Network building block. | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC, from the parent T Cloud Public Network building block. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_endpoint"></a> [api\_endpoint](#output\_api\_endpoint) | URL of the Kubernetes API: public when `public_api` is set, otherwise private to the VPC. |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | ID of the CCE cluster. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the CCE cluster. |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Kubeconfig with cluster-admin access. |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown in meshPanel after the run. |
<!-- END_TF_DOCS -->
