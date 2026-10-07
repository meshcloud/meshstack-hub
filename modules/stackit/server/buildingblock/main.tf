# Image ids are per-region and change as STACKIT republishes a release, so the image is resolved by
# name rather than pinned. The regex is anchored: `distro`/`version` filtering returns the ARM64
# build of the same release, which does not boot on the x86 flavors a generic VM uses.
data "stackit_image_v2" "this" {
  project_id = var.stackit_project_id
  region     = var.stackit_region
  name_regex = var.image_name_regex
}

locals {
  create_network = var.network_id == ""
  network_id     = local.create_network ? stackit_network.this.network_id : var.network_id
}

# A freshly created VM carries no key the owner holds, so the key pair is generated here instead of
# taken as an input: STACKIT only ever stores the public half, and the private half leaves as a
# sensitive output the owner reads once to log in.
resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "stackit_key_pair" "this" {
  name       = var.name
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "stackit_network" "this" {
  lifecycle {
    enabled = local.create_network
  }

  project_id         = var.stackit_project_id
  name               = var.name
  ipv4_nameservers   = ["9.9.9.9", "149.112.112.112"]
  ipv4_prefix_length = 24
  # A public IP only reaches the VM on a routed network; an unrouted one leaves it unreachable.
  routed = true
}

# STACKIT gives a newly created group allow-all egress of its own, so only the inbound SSH rule is
# declared here — adding an egress rule would 409 against the one STACKIT already made.
resource "stackit_security_group" "this" {
  project_id  = var.stackit_project_id
  name        = var.name
  description = "VM ${var.name}: inbound SSH from ${var.ssh_allowed_cidr}, outbound to the internet."
}

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

  # The personal cloud-init is optional; an empty input boots the image unmodified.
  user_data = var.cloud_init == "" ? null : var.cloud_init
}
