output "server_id" {
  description = "ID of the created IONOS server"
  value       = ionoscloud_server.main.id
}

output "server_name" {
  description = "Name of the created server"
  value       = ionoscloud_server.main.name
}

output "datacenter_id" {
  description = "ID of the datacenter containing the server"
  value       = var.datacenter_id
}

output "primary_nic_id" {
  description = "ID of the primary network interface"
  value       = var.create_network_interface ? (var.network_id != null ? data.ionoscloud_lan.existing[0].id : ionoscloud_lan.main[0].id) : null
}

output "boot_volume_id" {
  description = "ID of the boot/system volume"
  value       = ionoscloud_volume.boot.id
}

output "data_volumes" {
  description = "Map of data volume IDs by name"
  value = {
    for disk_name, volume in ionoscloud_volume.data : disk_name => volume.id
  }
}

output "public_ipblock_id" {
  description = "ID of the reserved public IP block (if requested)"
  value       = var.public_ip_required ? ionoscloud_ipblock.main[0].id : null
}

output "public_ips" {
  description = "List of reserved public IP addresses (if requested)"
  value       = var.public_ip_required ? ionoscloud_ipblock.main[0].ips : []
}

output "vm_specs" {
  description = "The effective VM specifications that were applied"
  value = {
    cpu_cores    = local.effective_specs.cpu_cores
    memory_mb    = local.effective_specs.memory_mb
    storage_gb   = local.effective_specs.storage_gb
    storage_type = local.effective_specs.storage_type
    os_image     = local.effective_specs.os_image
  }
}

output "boot_cdrom_id" {
  description = "ID of the boot CDROM"
  value       = ionoscloud_cdrom.main.id
}

output "server_details" {
  description = "Complete server resource details"
  value = {
    id                = ionoscloud_server.main.id
    name              = ionoscloud_server.main.name
    cores             = ionoscloud_server.main.cores
    ram               = ionoscloud_server.main.ram
    cpu_family        = ionoscloud_server.main.cpu_family
    availability_zone = ionoscloud_server.main.availability_zone
    datacenter_id     = ionoscloud_server.main.datacenter_id
  }
}

output "network_configuration" {
  description = "Network configuration details"
  value = {
    lan_id               = var.create_network_interface ? (var.network_id != null ? data.ionoscloud_lan.existing[0].id : ionoscloud_lan.main[0].id) : null
    lan_name             = var.create_network_interface ? (var.network_id != null ? data.ionoscloud_lan.existing[0].name : ionoscloud_lan.main[0].name) : null
    dhcp_enabled         = var.create_network_interface ? true : null
    public_ip_configured = var.public_ip_required
  }
}
