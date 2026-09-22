---
name: STACKIT Forgejo Runner
supportedPlatforms:
  - stackit
description: Deploys a STACKIT VM running forgejo-runner, registered as a self-hosted Forgejo Actions runner at organization scope.
---

## Why self-hosted instead of the STACKIT managed runner

STACKIT's managed Actions runners are enabled per Git instance via a fee-based order plus a
Help Center service request with a multi-day response time — they cannot be provisioned instantly
from Terraform. This building block instead uses STACKIT's officially supported
[custom (self-hosted) runner](https://docs.stackit.cloud/products/developer-platform/git/how-tos/pipelines-custom-runner/)
path: a VM running `forgejo-runner`, registered against the instance in one apply.

The org-scoped registration token is minted at apply time via the Forgejo API
(`GET /api/v1/orgs/{org}/actions/runners/registration-token`) using an org-admin PAT, then baked
into the VM's cloud-init. `forgejo-runner` self-registers on first boot and runs as a systemd
daemon. **Prerequisite:** Actions must be enabled on the Git instance (a separate STACKIT Git
toggle) — otherwise the token endpoint returns 404.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.4.0, < 4.0.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.98.0, < 1.0.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0.0, < 5.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [stackit_key_pair.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/key_pair) | resource |
| [stackit_network.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/network) | resource |
| [stackit_network_interface.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/network_interface) | resource |
| [stackit_public_ip.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/public_ip) | resource |
| [stackit_server.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/server) | resource |
| [tls_private_key.this](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [http_http.registration_token](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zone"></a> [availability\_zone](#input\_availability\_zone) | STACKIT availability zone for the VM and its boot volume. | `string` | `"eu01-1"` | no |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Size of the runner VM boot volume in GB. | `number` | `50` | no |
| <a name="input_forgejo_base_url"></a> [forgejo\_base\_url](#input\_forgejo\_base\_url) | Base URL of the STACKIT Git (Forgejo) instance, e.g. https://<name>.git.onstackit.cloud. | `string` | n/a | yes |
| <a name="input_forgejo_organization"></a> [forgejo\_organization](#input\_forgejo\_organization) | Forgejo organization the runner is registered for. It serves all repositories in this org. | `string` | n/a | yes |
| <a name="input_forgejo_runner_version"></a> [forgejo\_runner\_version](#input\_forgejo\_runner\_version) | Version of forgejo-runner to install on the VM. Pin explicitly so a re-provision is reproducible. | `string` | `"6.3.1"` | no |
| <a name="input_forgejo_token"></a> [forgejo\_token](#input\_forgejo\_token) | Forgejo PAT with organization-admin rights on var.forgejo\_organization — used to mint the runner registration token. Not placed on the VM. | `string` | n/a | yes |
| <a name="input_image_id"></a> [image\_id](#input\_image\_id) | STACKIT image UUID to boot from (Ubuntu 22.04 recommended). Image UUIDs are region-specific — look up the current one for var.stackit\_region. | `string` | n/a | yes |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | STACKIT machine flavor for the runner VM. Verify the flavor exists in the target region before ordering. | `string` | `"c1.2"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the runner (used for the VM name and the Forgejo runner registration). | `string` | `"forgejo-runner"` | no |
| <a name="input_network_id"></a> [network\_id](#input\_network\_id) | ID of an existing STACKIT network to attach the runner VM to. Leave null to create a dedicated network for the runner. | `string` | `null` | no |
| <a name="input_runner_labels"></a> [runner\_labels](#input\_runner\_labels) | Forgejo Actions runner labels. Each is either <label>:host (run on the VM) or <label>:docker://<image> (run in that container). Referenced by workflows via runs-on. | `list(string)` | <pre>[<br/>  "self-hosted:host",<br/>  "stackit-docker:docker://code.forgejo.org/oci/node:20-bookworm"<br/>]</pre> | no |
| <a name="input_stackit_project_id"></a> [stackit\_project\_id](#input\_stackit\_project\_id) | STACKIT project ID the runner VM is created in. | `string` | n/a | yes |
| <a name="input_stackit_region"></a> [stackit\_region](#input\_stackit\_region) | STACKIT region for the VM and its network resources. | `string` | `"eu01"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_public_ip"></a> [public\_ip](#output\_public\_ip) | Public IP of the runner VM. |
| <a name="output_runner_name"></a> [runner\_name](#output\_runner\_name) | Name the runner registered under in Forgejo — also the value workflows target via runs-on labels. |
| <a name="output_server_id"></a> [server\_id](#output\_server\_id) | ID of the STACKIT server hosting the runner. |
| <a name="output_ssh_private_key"></a> [ssh\_private\_key](#output\_ssh\_private\_key) | Break-glass SSH private key for the runner VM. Provisioning is fully automated; this is only for debugging a stuck registration. |
<!-- END_TF_DOCS -->
