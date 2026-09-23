---
name: STACKIT Git Runner
supportedPlatforms:
  - stackit
description: Deploys a STACKIT VM running a self-hosted STACKIT Git Actions runner at organization scope.
---

## Why self-hosted instead of the STACKIT managed runner

STACKIT hosts one shared Actions runner per Git instance, which the `stackit/git` building block
orders through `shared_runner_labels`. This building block instead uses STACKIT's officially
supported
[custom (self-hosted) runner](https://docs.stackit.cloud/products/developer-platform/git/how-tos/pipelines-custom-runner/)
path: a VM the platform controls — flavor, image, labels — running the runner agent, registered
against the instance in one apply.

The org-scoped registration token is minted at apply time via the STACKIT Git API
(`GET /api/v1/orgs/{org}/actions/runners/registration-token`) using an org-admin PAT, then baked
into the VM's cloud-init. The runner self-registers on first boot and runs as a systemd daemon.
**Prerequisite:** Actions must be enabled on the Git instance (a separate STACKIT Git toggle) —
otherwise the token endpoint returns 404.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.4.0, < 4.0.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.98.0, < 1.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [stackit_network.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/network) | resource |
| [stackit_network_interface.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/network_interface) | resource |
| [stackit_security_group.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/security_group) | resource |
| [stackit_server.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/server) | resource |
| [terraform_data.await_registration](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [http_http.registration_token](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [stackit_image_v2.runner](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/data-sources/image_v2) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zone"></a> [availability\_zone](#input\_availability\_zone) | STACKIT availability zone for the VM and its boot volume. | `string` | n/a | yes |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Size of the runner VM boot volume in GB. | `number` | n/a | yes |
| <a name="input_forgejo_api_token"></a> [forgejo\_api\_token](#input\_forgejo\_api\_token) | Org-admin PAT on `git_organization` that mints the registration token; it never reaches the VM. | `string` | n/a | yes |
| <a name="input_git_base_url"></a> [git\_base\_url](#input\_git\_base\_url) | Base URL of the STACKIT Git instance, e.g. https://<name>.git.onstackit.cloud. | `string` | n/a | yes |
| <a name="input_git_organization"></a> [git\_organization](#input\_git\_organization) | STACKIT Git organization the runner is registered for and serves. | `string` | n/a | yes |
| <a name="input_image_name_regex"></a> [image\_name\_regex](#input\_image\_name\_regex) | Anchored regex matching the STACKIT image name the runner boots from, so it skips the ARM64 variant. | `string` | n/a | yes |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | STACKIT machine flavor for the runner VM. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the runner, used for the VM and the runner registration. | `string` | n/a | yes |
| <a name="input_network_id"></a> [network\_id](#input\_network\_id) | Existing STACKIT network to attach the runner VM to. Empty creates a dedicated one. | `string` | n/a | yes |
| <a name="input_node_version"></a> [node\_version](#input\_node\_version) | Node.js version installed on the VM, used by JavaScript actions such as actions/checkout. | `string` | n/a | yes |
| <a name="input_runner_labels"></a> [runner\_labels](#input\_runner\_labels) | Runner labels, each `<label>:host` or `<label>:docker://<image>`, targeted by workflows via runs-on. | `list(string)` | n/a | yes |
| <a name="input_runner_version"></a> [runner\_version](#input\_runner\_version) | Version of the STACKIT Git Actions runner agent installed on the VM. | `string` | n/a | yes |
| <a name="input_stackit_project_id"></a> [stackit\_project\_id](#input\_stackit\_project\_id) | STACKIT project ID the runner VM is created in. | `string` | n/a | yes |
| <a name="input_stackit_region"></a> [stackit\_region](#input\_stackit\_region) | STACKIT region for the VM and its network resources. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_egress_ip"></a> [egress\_ip](#output\_egress\_ip) | Public SNAT IP of the runner's network router, for allowlisting. Empty on an existing network. |
| <a name="output_runner_name"></a> [runner\_name](#output\_runner\_name) | Name the runner registered under in STACKIT Git. |
| <a name="output_server_id"></a> [server\_id](#output\_server\_id) | ID of the STACKIT server hosting the runner. |
<!-- END_TF_DOCS -->
