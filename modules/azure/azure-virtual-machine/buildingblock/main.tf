data "azurerm_subscription" "current" {}

data "azurerm_client_config" "current" {}

resource "random_string" "resource_code" {
  length  = 5
  special = false
  upper   = false
}

resource "azurerm_resource_group" "vm_rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Virtual Network
resource "azurerm_virtual_network" "vm_vnet" {
  name                = "${var.vm_name}-vnet"
  location            = azurerm_resource_group.vm_rg.location
  resource_group_name = azurerm_resource_group.vm_rg.name
  address_space       = [var.vnet_address_space]

  tags = var.tags
}

# Subnet
resource "azurerm_subnet" "vm_subnet" {
  name                 = "${var.vm_name}-subnet"
  resource_group_name  = azurerm_resource_group.vm_rg.name
  virtual_network_name = azurerm_virtual_network.vm_vnet.name
  address_prefixes     = [var.subnet_address_prefix]
}

# Network Interface
resource "azurerm_network_interface" "vm_nic" {
  name                = "${var.vm_name}-nic"
  location            = azurerm_resource_group.vm_rg.location
  resource_group_name = azurerm_resource_group.vm_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.enable_public_ip ? azurerm_public_ip.vm_public_ip[0].id : null
  }

  tags = var.tags
}

# Public IP (optional)
resource "azurerm_public_ip" "vm_public_ip" {
  count               = var.enable_public_ip ? 1 : 0
  name                = "${var.vm_name}-pip"
  location            = azurerm_resource_group.vm_rg.location
  resource_group_name = azurerm_resource_group.vm_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# Network Security Group
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "${var.vm_name}-nsg"
  location            = azurerm_resource_group.vm_rg.location
  resource_group_name = azurerm_resource_group.vm_rg.name

  tags = var.tags
}

# NSG Rule: Allow SSH for Linux VMs with public IP
resource "azurerm_network_security_rule" "allow_ssh" {
  count                       = var.os_type == "Linux" && var.enable_public_ip ? 1 : 0
  name                        = "AllowSSH"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.vm_rg.name
  network_security_group_name = azurerm_network_security_group.vm_nsg.name
}

# NSG Rule: Allow RDP for Windows VMs with public IP
resource "azurerm_network_security_rule" "allow_rdp" {
  count                       = var.os_type == "Windows" && var.enable_public_ip ? 1 : 0
  name                        = "AllowRDP"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.vm_rg.name
  network_security_group_name = azurerm_network_security_group.vm_nsg.name
}

# NSG Association
resource "azurerm_network_interface_security_group_association" "vm_nsg_association" {
  network_interface_id      = azurerm_network_interface.vm_nic.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

# Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "vm" {
  count               = var.os_type == "Linux" ? 1 : 0
  name                = var.vm_name
  location            = azurerm_resource_group.vm_rg.location
  resource_group_name = azurerm_resource_group.vm_rg.name
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.vm_nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_storage_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  identity {
    type = "SystemAssigned"
  }

  priority        = var.enable_spot_instance ? "Spot" : "Regular"
  eviction_policy = var.enable_spot_instance ? var.spot_eviction_policy : null
  max_bid_price   = var.enable_spot_instance ? var.spot_max_bid_price : null

  disable_password_authentication = true

  tags = var.tags
}

# Windows Virtual Machine
resource "azurerm_windows_virtual_machine" "vm" {
  count               = var.os_type == "Windows" ? 1 : 0
  name                = var.vm_name
  location            = azurerm_resource_group.vm_rg.location
  resource_group_name = azurerm_resource_group.vm_rg.name
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.vm_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_storage_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  identity {
    type = "SystemAssigned"
  }

  priority        = var.enable_spot_instance ? "Spot" : "Regular"
  eviction_policy = var.enable_spot_instance ? var.spot_eviction_policy : null
  max_bid_price   = var.enable_spot_instance ? var.spot_max_bid_price : null

  tags = var.tags
}

# Managed Data Disk (optional)
resource "azurerm_managed_disk" "data_disk" {
  count                = var.data_disk_size_gb > 0 ? 1 : 0
  name                 = "${var.vm_name}-data-disk"
  location             = azurerm_resource_group.vm_rg.location
  resource_group_name  = azurerm_resource_group.vm_rg.name
  storage_account_type = var.data_disk_storage_type
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb

  tags = var.tags
}

# Attach Data Disk to Linux VM
resource "azurerm_virtual_machine_data_disk_attachment" "linux_data_disk_attachment" {
  count              = var.os_type == "Linux" && var.data_disk_size_gb > 0 ? 1 : 0
  managed_disk_id    = azurerm_managed_disk.data_disk[0].id
  virtual_machine_id = azurerm_linux_virtual_machine.vm[0].id
  lun                = 0
  caching            = "ReadWrite"
}

# Attach Data Disk to Windows VM
resource "azurerm_virtual_machine_data_disk_attachment" "windows_data_disk_attachment" {
  count              = var.os_type == "Windows" && var.data_disk_size_gb > 0 ? 1 : 0
  managed_disk_id    = azurerm_managed_disk.data_disk[0].id
  virtual_machine_id = azurerm_windows_virtual_machine.vm[0].id
  lun                = 0
  caching            = "ReadWrite"
}
