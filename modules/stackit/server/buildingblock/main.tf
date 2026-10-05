# Image ids are per-region and change as STACKIT republishes a release, so the image is resolved by
# name rather than pinned. The regex is anchored: `distro`/`version` filtering returns the ARM64
# build of the same release, which does not boot on the x86 flavors these machine types use.
data "stackit_image_v2" "this" {
  project_id = var.stackit_project_id
  region     = var.stackit_region
  name_regex = var.image_name_regex
}

locals {
  create_network = var.network_id == ""
  network_id     = local.create_network ? stackit_network.this.network_id : var.network_id

  # Empty ssh_public_key means the module generates the key pair; otherwise the caller brought their
  # own. Referencing a disabled resource (lifecycle.enabled = false) yields null, so guard the
  # dereference with a null check rather than reading the attribute directly.
  public_key = tls_private_key.this != null ? tls_private_key.this.public_key_openssh : var.ssh_public_key
}

# Generated only when the caller did not bring their own public key.
resource "tls_private_key" "this" {
  lifecycle {
    enabled = var.ssh_public_key == ""
  }

  algorithm = "ED25519"
}

resource "stackit_key_pair" "this" {
  name       = "${var.name}-key"
  public_key = chomp(local.public_key)
}

resource "stackit_network" "this" {
  lifecycle {
    enabled = local.create_network
  }

  project_id         = var.stackit_project_id
  name               = var.name
  ipv4_nameservers   = ["9.9.9.9", "149.112.112.112"]
  ipv4_prefix_length = 24
  # Without routing the VM boots on an unrouted network with no path off the host, so a personal
  # cloud-init that installs packages or a public IP that should reach the internet both silently fail.
  routed = true
}

# STACKIT gives a newly created security group allow-all egress rules of its own, so the VM reaches
# the internet outbound without any rule here. Inbound is closed by default; the SSH rule below is
# the only opening, and only when a public IP makes the VM reachable at all.
resource "stackit_security_group" "this" {
  project_id  = var.stackit_project_id
  name        = var.name
  description = "VM ${var.name}: outbound to the internet, inbound SSH only when a public IP is attached."
}

resource "stackit_security_group_rule" "ssh" {
  lifecycle {
    enabled = var.enable_public_ip
  }

  project_id        = var.stackit_project_id
  security_group_id = stackit_security_group.this.security_group_id
  direction         = "ingress"
  ether_type        = "IPv4"
  ip_range          = var.ssh_allowed_cidr

  protocol = {
    name = "tcp"
  }

  port_range = {
    min = 22
    max = 22
  }
}

resource "stackit_network_interface" "this" {
  project_id         = var.stackit_project_id
  network_id         = local.network_id
  name               = var.name
  security_group_ids = [stackit_security_group.this.security_group_id]
}

resource "stackit_public_ip" "this" {
  lifecycle {
    enabled = var.enable_public_ip
  }

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

  # A personal cloud-init is optional; null boots the image unmodified.
  user_data = var.cloud_init == "" ? null : var.cloud_init
}
