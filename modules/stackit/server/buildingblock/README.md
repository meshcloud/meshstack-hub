---
name: STACKIT Server
supportedPlatforms:
  - stackit
description: Provisions a STACKIT virtual machine with a generated SSH key and optional personal cloud-init.
---

## What it is

A generic **STACKIT virtual machine** building block. It creates a server on its own routed network,
puts a floating public IP on it, and opens inbound SSH so the ordering team can log straight in. An
ED25519 key pair is generated per VM — STACKIT injects the public key, and the private key is
returned as a sensitive output. An optional personal cloud-init (`#cloud-config`) is applied verbatim
on first boot.

It started life as the networking/VM core of `stackit/git-runner`, generalised once the Git runner
turned out to be natively supported on STACKIT: everything runner-specific was stripped, SSH access
and the generated key pair were added, and the runner's baked-in cloud-init became a free-form input.

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
| [tls_private_key.this](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [stackit_image_v2.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/data-sources/image_v2) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_availability_zone"></a> [availability\_zone](#input\_availability\_zone) | STACKIT availability zone for the VM and its boot volume. | `string` | n/a | yes |
| <a name="input_cloud_init"></a> [cloud\_init](#input\_cloud\_init) | Optional personal cloud-init (#cloud-config) applied to the VM on first boot. Empty means none. SSH access does not depend on it. | `string` | n/a | yes |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Size of the VM boot volume in GB. | `number` | n/a | yes |
| <a name="input_image_name_regex"></a> [image\_name\_regex](#input\_image\_name\_regex) | Anchored regex matching the STACKIT image the VM boots from, so it skips the ARM64 variant. | `string` | n/a | yes |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | STACKIT machine flavor for the VM. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the VM, used for the server and its network resources. | `string` | n/a | yes |
| <a name="input_network_id"></a> [network\_id](#input\_network\_id) | Existing STACKIT network to attach the VM to. Empty creates a dedicated one. | `string` | n/a | yes |
| <a name="input_ssh_allowed_cidr"></a> [ssh\_allowed\_cidr](#input\_ssh\_allowed\_cidr) | CIDR range allowed to reach the VM on TCP 22. Authentication is key-only; narrow this to a trusted range in production. | `string` | n/a | yes |
| <a name="input_ssh_username"></a> [ssh\_username](#input\_ssh\_username) | Default login user of the chosen image (e.g. `ubuntu`), surfaced only to render the SSH login hint output. | `string` | n/a | yes |
| <a name="input_stackit_project_id"></a> [stackit\_project\_id](#input\_stackit\_project\_id) | STACKIT project ID the VM is created in. | `string` | n/a | yes |
| <a name="input_stackit_region"></a> [stackit\_region](#input\_stackit\_region) | STACKIT region for the VM and its network resources. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_public_ip"></a> [public\_ip](#output\_public\_ip) | Public IP of the VM. SSH in as ssh\_username with the generated private key. |
| <a name="output_server_id"></a> [server\_id](#output\_server\_id) | ID of the STACKIT server. |
| <a name="output_ssh_command"></a> [ssh\_command](#output\_ssh\_command) | Ready-to-use SSH command once the generated private key is on disk. |
| <a name="output_ssh_private_key"></a> [ssh\_private\_key](#output\_ssh\_private\_key) | Generated SSH private key (OpenSSH format) to log into the VM as ssh\_username. |
| <a name="output_ssh_username"></a> [ssh\_username](#output\_ssh\_username) | Default login user of the VM image, e.g. `ubuntu` on the Ubuntu image. |
| <a name="output_summary"></a> [summary](#output\_summary) | Human-readable summary shown in meshPanel after the run. |
<!-- END_TF_DOCS -->
