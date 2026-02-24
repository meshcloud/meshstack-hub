# Create network interface if requested
resource "ionoscloud_nic" "main" {
  count           = var.create_network_interface ? 1 : 0
  datacenter_id   = var.datacenter_id
  lan             = var.network_id != null ? data.ionoscloud_lan.existing[0].id : ionoscloud_lan.main[0].id
  name            = "${var.vm_name}-nic"
  dhcp            = true
  firewall_active = false

  depends_on = [ionoscloud_lan.main]
}

# Create LAN if network interface creation is requested and no network_id provided
resource "ionoscloud_lan" "main" {
  count         = var.create_network_interface && var.network_id == null ? 1 : 0
  datacenter_id = var.datacenter_id
  name          = "${var.vm_name}-lan"
  public        = var.public_ip_required
}

# Data source for existing network if provided
data "ionoscloud_lan" "existing" {
  count         = var.create_network_interface && var.network_id != null ? 1 : 0
  datacenter_id = var.datacenter_id
  id            = var.network_id
}

# Get NIC to attach - either newly created or reference existing
locals {
  nic_id = var.create_network_interface ? ionoscloud_nic.main[0].id : null
}

# Create the boot/system volume
resource "ionoscloud_volume" "boot" {
  datacenter_id = var.datacenter_id
  name          = "${var.vm_name}-boot"
  size          = local.effective_specs.storage_gb
  disk_type     = local.effective_specs.storage_type
  image_name    = local.effective_specs.os_image
  licence_type  = "LINUX"
}

# Create additional data volumes
resource "ionoscloud_volume" "data" {
  for_each = {
    for disk in var.additional_data_disks : disk.name => disk
  }

  datacenter_id = var.datacenter_id
  name          = "${var.vm_name}-${each.value.name}"
  size          = each.value.size_gb
  disk_type     = each.value.storage_type
  licence_type  = "LINUX"
}

# Create the server
resource "ionoscloud_server" "main" {
  name              = var.vm_name
  datacenter_id     = var.datacenter_id
  cores             = local.effective_specs.cpu_cores
  ram               = local.effective_specs.memory_mb
  availability_zone = "ZONE_1"
  cpu_family        = "INTEL_XEON"
  boot_cdrom        = ionoscloud_cdrom.main.id

  volume {
    disk_id    = ionoscloud_volume.boot.id
    bus        = "VIRTIO"
    boot_order = 1
  }

  dynamic "nic" {
    for_each = var.create_network_interface ? [1] : []
    content {
      lan             = var.network_id != null ? data.ionoscloud_lan.existing[0].id : ionoscloud_lan.main[0].id
      name            = "${var.vm_name}-nic"
      dhcp            = true
      firewall_active = false
    }
  }
}

# Attach additional data volumes to the server
resource "ionoscloud_server_volume" "data" {
  for_each = {
    for disk in var.additional_data_disks : disk.name => disk
  }

  datacenter_id = var.datacenter_id
  server_id     = ionoscloud_server.main.id
  volume_id     = ionoscloud_volume.data[each.key].id
  bus           = "VIRTIO"
}

# Get CDROM for boot (empty boot CD)
resource "ionoscloud_cdrom" "main" {
  datacenter_id = var.datacenter_id
  name          = "${var.vm_name}-boot-cd"
  description   = "Boot CDROM for ${var.vm_name}"
}

# Reserve public IP if required
resource "ionoscloud_ipblock" "main" {
  count    = var.public_ip_required ? 1 : 0
  location = "us/las" # Default location, may need adjustment based on datacenter
  size     = 1
  name     = "${var.vm_name}-ip"
}
