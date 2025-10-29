locals {
  azure_delay = "${var.azure_delay_seconds}s"
}

data "azurerm_client_config" "current" {}

# Create the resource group
resource "azurerm_resource_group" "bastion" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Create the POC VNet with 10.0.0.0/8 address space
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = azurerm_resource_group.bastion.name
  address_space       = ["10.0.0.0/8"]

  tags = var.tags
}

# Create additional subnets for workloads
resource "azurerm_subnet" "workload_subnet" {
  name                 = "workload-subnet"
  resource_group_name  = azurerm_resource_group.bastion.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.0.0/24"]
}

# Create subnet for Azure Bastion (must be named AzureBastionSubnet)
resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.bastion.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.bastion_subnet_cidr]
}

# Resource locks for VNet and workload subnets - applied after all subnets and associations are created
resource "azurerm_management_lock" "vnet_lock" {
  count = var.enable_resource_locks ? 1 : 0

  name       = "${var.name}-vnet-lock"
  scope      = azurerm_virtual_network.vnet.id
  lock_level = "ReadOnly"
  notes      = "Prevent accidental modification of VNet"

  # Ensure all subnets and NSG associations are created before applying the lock
  depends_on = [
    azurerm_subnet.workload_subnet,
    azurerm_subnet.bastion_subnet,
    azurerm_subnet_network_security_group_association.bastion_nsg_association
  ]
}

resource "azurerm_management_lock" "workload_subnet_lock" {
  count = var.enable_resource_locks ? 1 : 0

  name       = "${var.name}-workload-subnet-1-lock"
  scope      = azurerm_subnet.workload_subnet.id
  lock_level = "ReadOnly"
  notes      = "Prevent accidental modification of workload subnet 1"
}

# Create public IP for Azure Bastion
resource "azurerm_public_ip" "bastion_pip" {
  name                = "${var.name}-bastion-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.bastion.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# Create Network Security Group for Bastion subnet
resource "azurerm_network_security_group" "bastion_nsg" {
  name                = "${var.name}-bastion-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.bastion.name

  # Inbound rules for Azure Bastion
  security_rule {
    name                       = "AllowHttpsInbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowGatewayManagerInbound"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAzureLoadBalancerInbound"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowBastionHostCommunication"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  # Outbound rules for Azure Bastion
  security_rule {
    name                       = "AllowSshRdpOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowAzureCloudOutbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }

  security_rule {
    name                       = "AllowBastionCommunication"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowGetSessionInformation"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  tags = var.tags
}

# Associate NSG with Bastion subnet
resource "azurerm_subnet_network_security_group_association" "bastion_nsg_association" {
  subnet_id                 = azurerm_subnet.bastion_subnet.id
  network_security_group_id = azurerm_network_security_group.bastion_nsg.id
}

# Wait for subnet and NSG to be ready
resource "time_sleep" "wait_for_subnet" {
  depends_on      = [azurerm_subnet_network_security_group_association.bastion_nsg_association]
  create_duration = local.azure_delay
}

# Create Azure Bastion Host
resource "azurerm_bastion_host" "bastion" {
  depends_on = [time_sleep.wait_for_subnet]

  name                = "${var.name}-bastion"
  location            = var.location
  resource_group_name = azurerm_resource_group.bastion.name
  sku                 = var.bastion_sku

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }

  tags = var.tags
}

# Create resource locks if enabled
resource "azurerm_management_lock" "bastion_lock" {
  count = var.enable_resource_locks ? 1 : 0

  name       = "${var.name}-bastion-lock"
  scope      = azurerm_bastion_host.bastion.id
  lock_level = "CanNotDelete"
  notes      = "Prevent accidental deletion of Azure Bastion Host"
}

resource "azurerm_management_lock" "subnet_lock" {
  count = var.enable_resource_locks ? 1 : 0

  name       = "${var.name}-bastion-subnet-lock"
  scope      = azurerm_subnet.bastion_subnet.id
  lock_level = "ReadOnly"
  notes      = "Prevent accidental modification of Bastion subnet"
}

#
# Observability Components
#

# Action Group for centralized notifications
resource "azurerm_monitor_action_group" "sandbox_alerts" {
  count = var.enable_observability ? 1 : 0

  name                = "${var.name}-sandbox-alerts"
  resource_group_name = azurerm_resource_group.bastion.name
  short_name          = substr("${var.name}-alerts", 0, 12)

  dynamic "email_receiver" {
    for_each = var.alert_email_receivers
    content {
      name          = "${email_receiver.value.firstName} ${email_receiver.value.lastName}"
      email_address = email_receiver.value.email
    }
  }

  dynamic "webhook_receiver" {
    for_each = var.alert_webhook_receivers
    content {
      name                    = webhook_receiver.value.name
      service_uri             = webhook_receiver.value.uri
      use_common_alert_schema = true
    }
  }

  tags = var.tags
}

# Service Health Alerts for subscription-wide issues
resource "azurerm_monitor_activity_log_alert" "service_health" {
  count = var.enable_observability ? 1 : 0

  name                = "${var.name}-service-health-alert"
  resource_group_name = var.resource_group_name
  scopes              = ["/subscriptions/${data.azurerm_client_config.current.subscription_id}"]
  description         = "Service Health issues affecting the sandbox subscription"

  criteria {
    category = "ServiceHealth"

    service_health {
      events    = ["Incident", "Maintenance", "Informational", "ActionRequired"]
      locations = ["Global", var.location]
      services  = ["Virtual Machines", "Virtual Network", "Storage", "Azure Bastion"]
    }
  }

  action {
    action_group_id    = azurerm_monitor_action_group.sandbox_alerts[0].id
    webhook_properties = {}
  }

  tags = var.tags
}

# Resource Health Alert for Bastion Host
resource "azurerm_monitor_activity_log_alert" "bastion_resource_health" {
  count = var.enable_observability ? 1 : 0

  name                = "${var.name}-bastion-resource-health"
  resource_group_name = azurerm_resource_group.bastion.name
  scopes              = [azurerm_bastion_host.bastion.id]
  description         = "Resource health issues with Azure Bastion Host"

  criteria {
    category = "ResourceHealth"

    resource_health {
      current  = ["Unavailable", "Degraded"]
      previous = ["Available"]
      reason   = ["PlatformInitiated", "UserInitiated", "Unknown"]
    }
  }

  action {
    action_group_id    = azurerm_monitor_action_group.sandbox_alerts[0].id
    webhook_properties = {}
  }

  tags = var.tags
}

# Generic Resource Health Alert for all subscription resources
resource "azurerm_monitor_activity_log_alert" "subscription_resource_health" {
  count = var.enable_observability ? 1 : 0

  name                = "${var.name}-subscription-resource-health"
  resource_group_name = azurerm_resource_group.bastion.name
  scopes              = ["/subscriptions/${data.azurerm_client_config.current.subscription_id}"]
  description         = "Resource health issues for any resource in the sandbox subscription"

  criteria {
    category = "ResourceHealth"

    resource_health {
      current  = ["Unavailable", "Degraded"]
      previous = ["Available"]
      reason   = ["PlatformInitiated", "UserInitiated"]
    }
  }

  action {
    action_group_id    = azurerm_monitor_action_group.sandbox_alerts[0].id
    webhook_properties = {}
  }

  tags = var.tags
}

# Administrative Activity Alert for deployment failures
resource "azurerm_monitor_activity_log_alert" "admin_activity" {
  count = var.enable_observability ? 1 : 0

  name                = "${var.name}-admin-activity-alert"
  resource_group_name = azurerm_resource_group.bastion.name
  scopes              = ["/subscriptions/${data.azurerm_client_config.current.subscription_id}"]
  description         = "Administrative activities and failures in the sandbox subscription"

  criteria {
    category = "Administrative"

    operation_name = "Microsoft.Resources/deployments/write"
    level          = "Error"
  }

  action {
    action_group_id    = azurerm_monitor_action_group.sandbox_alerts[0].id
    webhook_properties = {}
  }

  tags = var.tags
}
