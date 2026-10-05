---
name: STACKIT Virtual Machine
supportedPlatforms:
  - stackit
description: Deploys a STACKIT VM with an optional public IP, a generated or supplied SSH key, and an optional personal cloud-init.
# No cloud-side setup: the VM is created with the WIF service account passed in as a static input,
# the same identity model as the STACKIT Git Runner building block.
requiresBackplane: false
---

## What it provisions

A single STACKIT VM (`stackit_server`) on its own network, security group and network interface. The
VM boots a STACKIT image resolved by name regex, so it tracks the republished image id rather than
pinning a UUID.

Two things make it usable the moment it comes up:

- **SSH access.** The module authorizes an SSH key on the VM via a `stackit_key_pair`. Supply your
  own public key, or leave it empty and the module generates an ed25519 key pair and returns the
  private key as an output. When a public IP is attached, inbound SSH (port 22) is opened to a CIDR
  you choose, so you can log in right after creation. Without a public IP the VM stays private and
  reachable only from inside its network.
- **Personal cloud-init.** An optional cloud-init document is passed straight to the VM as user data
  on first boot. The SSH key is wired through the key pair, not cloud-init, so a personal cloud-init
  carries only your own setup.

The VM is created with a STACKIT service account passed in as a static input (WIF), the same
identity model as the STACKIT Git Runner — this building block provisions nothing cloud-side itself.

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
| <a name="input_cloud_init"></a> [cloud\_init](#input\_cloud\_init) | Optional cloud-init user data run on first boot. Empty boots the image unmodified. The SSH key is injected via the key pair, not this file, so a personal cloud-init needs no key handling. | `string` | `""` | no |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Size of the VM boot volume in GB. | `number` | n/a | yes |
| <a name="input_enable_public_ip"></a> [enable\_public\_ip](#input\_enable\_public\_ip) | Attaches a public IP and opens inbound SSH, so the VM is reachable directly after creation. Disable to keep it private (reachable only from inside the network). | `bool` | n/a | yes |
| <a name="input_image_name_regex"></a> [image\_name\_regex](#input\_image\_name\_regex) | Anchored regex matching the STACKIT image name the VM boots from, so it skips the ARM64 variant. | `string` | n/a | yes |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | STACKIT machine flavor for the VM, e.g. g1a.1d or c1a.2d. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the VM, also used to name its network resources and SSH key pair. | `string` | n/a | yes |
| <a name="input_network_id"></a> [network\_id](#input\_network\_id) | Existing STACKIT network to attach the VM to. Empty creates a dedicated one. | `string` | n/a | yes |
| <a name="input_ssh_allowed_cidr"></a> [ssh\_allowed\_cidr](#input\_ssh\_allowed\_cidr) | CIDR allowed to reach SSH (port 22) when a public IP is attached. Has no effect without a public IP. | `string` | n/a | yes |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | OpenSSH public key authorized on the VM. Empty generates an ed25519 key pair and returns the private key as an output. | `string` | `""` | no |
| <a name="input_stackit_project_id"></a> [stackit\_project\_id](#input\_stackit\_project\_id) | STACKIT project ID the VM is created in. | `string` | n/a | yes |
| <a name="input_stackit_region"></a> [stackit\_region](#input\_stackit\_region) | STACKIT region for the VM and its network resources. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_public_ip"></a> [public\_ip](#output\_public\_ip) | Public IP of the VM, for SSH. Empty when no public IP is attached. |
| <a name="output_server_id"></a> [server\_id](#output\_server\_id) | ID of the STACKIT server. |
| <a name="output_ssh_key_pair_name"></a> [ssh\_key\_pair\_name](#output\_ssh\_key\_pair\_name) | Name of the STACKIT key pair authorized on the VM. |
| <a name="output_ssh_private_key"></a> [ssh\_private\_key](#output\_ssh\_private\_key) | Generated OpenSSH private key to log in as the default user. Null when a public key was supplied. |
| <a name="output_ssh_username"></a> [ssh\_username](#output\_ssh\_username) | Default login user of the booted image. STACKIT Ubuntu images use `ubuntu`. |
<!-- END_TF_DOCS -->
