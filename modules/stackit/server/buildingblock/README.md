---
name: STACKIT Server
supportedPlatforms:
  - stackit
description: Deploys a STACKIT VM with a generated SSH key and an optional personal cloud-init.
requiresBackplane: false # authenticates as an existing service account via the STACKIT Service Account Federation building block, so there is no cloud-side setup to run here
---

## What this provisions

A single STACKIT VM (server, network, security group, network interface and public IP) reachable
over SSH. The module generates an ED25519 key pair, registers the public half with STACKIT and
returns the private half as a sensitive output, so the owner can log in the moment the run finishes
without pre-seeding a key. An optional personal cloud-init runs on first boot.

The VM gets a public IP, and its security group opens TCP 22 to a caller-chosen CIDR. Everything
else is closed inbound; outbound uses the network router's NAT.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.98.0, < 1.0.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0.0, < 5.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [stackit_key_pair.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/key_pair) | resource |
| [stackit_network.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/network) | resource |
| [stackit_network_interface.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/network_interface) | resource |
| [stackit_public_ip.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/public_ip) | resource |
| [stackit_security_group.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/security_group) | resource |
| [stackit_security_group_rule.ssh](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/security_group_rule) | resource |
| [stackit_server.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/server) | resource |
| [tls_private_key.ssh](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [stackit_image_v2.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/data-sources/image_v2) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_availability_zone"></a> [availability\_zone](#input\_availability\_zone) | STACKIT availability zone for the VM and its boot volume. | `string` | n/a | yes |
| <a name="input_cloud_init"></a> [cloud\_init](#input\_cloud\_init) | Optional personal cloud-init (`#cloud-config` or a shell script) applied on first boot. Empty boots the image unmodified. | `string` | `""` | no |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Size of the VM boot volume in GB. | `number` | n/a | yes |
| <a name="input_image_name_regex"></a> [image\_name\_regex](#input\_image\_name\_regex) | Anchored regex matching the STACKIT image name the VM boots from, so it skips the ARM64 variant. | `string` | n/a | yes |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | STACKIT machine flavor for the VM. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the VM, reused for its network, security group, key pair and network interface. | `string` | n/a | yes |
| <a name="input_network_id"></a> [network\_id](#input\_network\_id) | Existing STACKIT network to attach the VM to. Empty creates a dedicated one. | `string` | n/a | yes |
| <a name="input_ssh_allowed_cidr"></a> [ssh\_allowed\_cidr](#input\_ssh\_allowed\_cidr) | CIDR allowed to reach the VM on TCP 22. Narrow it to an office range; 0.0.0.0/0 exposes SSH to the internet. | `string` | n/a | yes |
| <a name="input_ssh_username"></a> [ssh\_username](#input\_ssh\_username) | Login user the chosen image ships with (e.g. `ubuntu`), reported in the SSH command output. | `string` | n/a | yes |
| <a name="input_stackit_project_id"></a> [stackit\_project\_id](#input\_stackit\_project\_id) | STACKIT project ID the VM is created in. | `string` | n/a | yes |
| <a name="input_stackit_region"></a> [stackit\_region](#input\_stackit\_region) | STACKIT region for the VM and its network resources. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_public_ip"></a> [public\_ip](#output\_public\_ip) | Public IP the VM is reachable on over SSH. |
| <a name="output_server_id"></a> [server\_id](#output\_server\_id) | ID of the STACKIT server. |
| <a name="output_ssh_command"></a> [ssh\_command](#output\_ssh\_command) | Ready-to-use SSH command once the generated private key is on disk (see ssh\_private\_key). |
| <a name="output_ssh_private_key"></a> [ssh\_private\_key](#output\_ssh\_private\_key) | Generated OpenSSH private key to log into the VM. Save it to a file, chmod 600, and pass it with ssh -i. |
| <a name="output_ssh_username"></a> [ssh\_username](#output\_ssh\_username) | Login user for the VM, as shipped by the chosen image. |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown in meshPanel after the run. |
<!-- END_TF_DOCS -->
