# Image ids are per-region and change as STACKIT republishes a release, so the image is resolved by
# name rather than pinned. The regex is anchored: unanchored `distro`/`version` filtering returns the
# ARM64 build of the same release, which does not boot on the x86 flavors this VM uses.
data "stackit_image_v2" "this" {
  project_id = var.stackit_project_id
  region     = var.stackit_region
  name_regex = var.image_name_regex
}

locals {
  create_network = var.network_id == ""
  network_id     = local.create_network ? stackit_network.this.network_id : var.network_id
}

# A key pair is generated per VM so the ordering team can log in right after creation. The private
# key never touches the VM — STACKIT injects only the public key via keypair_name, and the private
# key is surfaced solely as a sensitive building block output.
resource "tls_private_key" "this" {
  algorithm = "ED25519"
}

resource "stackit_key_pair" "this" {
  name       = var.name
  public_key = chomp(tls_private_key.this.public_key_openssh)
}

resource "stackit_network" "this" {
  lifecycle {
    enabled = local.create_network
  }

  project_id         = var.stackit_project_id
  name               = var.name
  ipv4_nameservers   = ["9.9.9.9", "149.112.112.112"]
  ipv4_prefix_length = 24
  # Without routing the VM boots on an unrouted network and cannot reach the internet for package
  # installs or for the user's cloud-init to pull anything down.
  routed = true
}

resource "stackit_security_group" "this" {
  project_id  = var.stackit_project_id
  name        = var.name
  description = "VM ${var.name}: inbound SSH from ${var.ssh_allowed_cidr}, outbound to the internet."
}

# Only inbound SSH is declared: STACKIT gives a new security group allow-all egress rules of its own,
# so declaring egress here would 409 against the rule it already made (learned in stackit/git-runner).
resource "stackit_security_group_rule" "ssh" {
  project_id        = var.stackit_project_id
  security_group_id = stackit_security_group.this.security_group_id
  direction         = "ingress"
  ether_type        = "IPv4"
  ip_range          = var.ssh_allowed_cidr
  protocol          = { name = "tcp" }
  port_range        = { min = 22, max = 22 }
}

resource "stackit_network_interface" "this" {
  project_id         = var.stackit_project_id
  network_id         = local.network_id
  name               = var.name
  security_group_ids = [stackit_security_group.this.security_group_id]
}

# A floating public IP on the VM's NIC so the ordering team can SSH straight in with the generated key.
resource "stackit_public_ip" "this" {
  project_id           = var.stackit_project_id
  network_interface_id = stackit_network_interface.this.network_interface_id
}

resource "stackit_server" "this" {
  project_id        = var.stackit_project_id
  name              = var.name
  machine_type      = var.machine_type
  availability_zone = var.availability_zone
  keypair_name      = stackit_key_pair.this.name

  boot_volume = {
    source_type           = "image"
    source_id             = data.stackit_image_v2.this.image_id
    size                  = var.disk_size_gb
    delete_on_termination = true
  }

  network_interfaces = [stackit_network_interface.this.network_interface_id]

  # The personal cloud-init is applied verbatim when supplied. SSH access does not depend on it — the
  # generated key pair is injected by STACKIT via keypair_name — so an empty value is a valid no-op.
  user_data = var.cloud_init != "" ? var.cloud_init : null
}
