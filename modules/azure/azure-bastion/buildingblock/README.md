---
name: Azure Bastion Host
supportedPlatforms:
  - azure
description: Bietet sichere RDP- und SSH-Konnektivität zu Virtual Machines in Azure Virtual Networks, ohne diese dem öffentlichen Internet auszusetzen, mit umfassendem Monitoring und Alerting.
category: networking
---

# Azure Bastion Building Block mit umfassender Observability

Dieser Building Block stellt einen Azure Bastion Host bereit, um sichere RDP- und SSH-Konnektivität zu Virtual Machines in Ihrem Azure Virtual Network zu bieten, zusammen mit umfassendem Monitoring und Alerting für Ihr gesamtes Sandbox-Abonnement.

## Features

- **Sicherer VM-Zugriff**: Bietet sicheren RDP/SSH-Zugriff auf VMs, ohne diese dem öffentlichen Internet auszusetzen
- **Dediziertes Subnet**: Erstellt das erforderliche AzureBastionSubnet mit ordnungsgemäßen Network Security Group-Regeln
- **Ressourcenschutz**: Optionale Resource Locks zur Verhinderung versehentlicher Löschung oder Änderung
- **Standard-Compliance**: Implementiert alle erforderlichen NSG-Regeln für Azure Bastion-Funktionalität
- **Umfassende Observability**: Vollständige Monitoring-Lösung für Sandbox-Umgebungen
- **Zentralisiertes Alerting**: Action Group mit E-Mail-, Teams- und Webhook-Benachrichtigungen
- **Health Monitoring**: Service Health und Resource Health Alerts für alle Subscription-Ressourcen
- **Administrative Überwachung**: Alerts für Deployment-Fehler und kritische administrative Aktivitäten

## Architektur

Der Building Block erstellt:

**Bastion-Infrastruktur:**
- Azure Bastion Host
- AzureBastionSubnet (mindestens /27 erforderlich)
- Public IP Address für Bastion
- Network Security Group mit erforderlichen Regeln
- Optionale Resource Locks zum Schutz

**Observability-Infrastruktur:**
- Action Group für zentralisierte Benachrichtigungen (E-Mail, Teams, Webhooks)
- Service Health Alerts für Azure-Service-Probleme
- Resource Health Alerts für alle Subscription-Ressourcen
- Administrative Activity Alerts für Deployment-Fehler
- Bastion-spezifisches Resource Health Monitoring

## Verwendung

```hcl
module "azure_bastion_with_observability" {
  source = "./azure-bastion/buildingblock"

  name                     = "poc-bastion"
  location                 = "West Europe"
  resource_group_name      = "rg-poc-connectivity"
  vnet_name               = "vnet-poc"
  vnet_resource_group_name = "rg-poc-connectivity"
  bastion_subnet_cidr     = "10.0.1.0/27"

  bastion_sku            = "Basic"
  enable_resource_locks  = true

  # Observability-Konfiguration
  enable_observability = true
  alert_email_receivers = [
    {
      name  = "poc-team"
      email = "poc-team@company.com"
    },
    {
      name  = "ops-team"
      email = "operations@company.com"
    }
  ]
  alert_webhook_receivers = [
    {
      name = "teams-webhook"
      uri  = "https://company.webhook.office.com/webhookb2/..."
    }
  ]

  tags = {
    Environment = "POC"
    Purpose     = "Secure VM Access + Comprehensive Monitoring"
  }
}
```

## Variablen

| Name | Beschreibung | Typ | Standard | Erforderlich |
|------|-------------|------|---------|--------------|
| name | Name des Azure Bastion Deployments | string | - | ja |
| location | Azure-Region, in der Ressourcen bereitgestellt werden | string | - | ja |
| resource_group_name | Name der Resource Group, in der Bastion bereitgestellt wird | string | - | ja |
| vnet_name | Name des Virtual Networks, in dem das Bastion Subnet erstellt wird | string | - | ja |
| vnet_resource_group_name | Name der Resource Group, die das Virtual Network enthält | string | - | ja |
| bastion_subnet_cidr | CIDR-Block für das AzureBastionSubnet (mindestens /27) | string | - | ja |
| bastion_sku | SKU des Azure Bastion Hosts (Basic oder Standard) | string | "Basic" | nein |
| enable_resource_locks | Resource Locks aktivieren zur Verhinderung versehentlicher Löschung/Änderung | bool | true | nein |
| azure_delay_seconds | Verzögerung in Sekunden, um auf Azure-Ressourcen zu warten | number | 30 | nein |
| tags | Tags, die auf alle Ressourcen angewendet werden | map(string) | {} | nein |

## Outputs

| Name | Beschreibung |
|------|-------------|
| bastion_host_id | Die ID des Azure Bastion Hosts |
| bastion_host_name | Der Name des Azure Bastion Hosts |
| bastion_host_fqdn | Der FQDN des Azure Bastion Hosts |
| bastion_public_ip | Die öffentliche IP-Adresse des Azure Bastion Hosts |
| bastion_subnet_id | Die ID des AzureBastionSubnets |
| bastion_nsg_id | Die ID der Bastion Network Security Group |

## Anforderungen

- Das Virtual Network muss bereits existieren
- Das Bastion Subnet CIDR muss mindestens /27 (32 IP-Adressen) betragen
- Das Subnet wird "AzureBastionSubnet" benannt, wie von Azure erforderlich

## Sicherheit

Dieser Building Block implementiert alle erforderlichen Network Security Group-Regeln für Azure Bastion:

**Eingehende Regeln:**
- HTTPS (443) vom Internet für Benutzerverbindungen
- HTTPS (443) vom GatewayManager für Azure-Management
- HTTPS (443) vom AzureLoadBalancer für Health Probes
- Ports 8080, 5701 vom VirtualNetwork für Bastion-Kommunikation

**Ausgehende Regeln:**
- SSH (22) und RDP (3389) zum VirtualNetwork für VM-Verbindungen
- HTTPS (443) zu AzureCloud für Azure-Services
- Ports 8080, 5701 zum VirtualNetwork für Bastion-Kommunikation
- HTTP (80) zum Internet für Session-Informationen
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 3.116.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.11.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_bastion_host.bastion](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/bastion_host) | resource |
| [azurerm_management_lock.bastion_lock](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) | resource |
| [azurerm_management_lock.subnet_lock](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) | resource |
| [azurerm_management_lock.vnet_lock](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) | resource |
| [azurerm_management_lock.workload_subnet_lock](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) | resource |
| [azurerm_monitor_action_group.sandbox_alerts](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_action_group) | resource |
| [azurerm_monitor_activity_log_alert.admin_activity](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_activity_log_alert) | resource |
| [azurerm_monitor_activity_log_alert.bastion_resource_health](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_activity_log_alert) | resource |
| [azurerm_monitor_activity_log_alert.service_health](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_activity_log_alert) | resource |
| [azurerm_monitor_activity_log_alert.subscription_resource_health](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_activity_log_alert) | resource |
| [azurerm_network_security_group.bastion_nsg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_public_ip.bastion_pip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_resource_group.bastion](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_subnet.bastion_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet.workload_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet_network_security_group_association.bastion_nsg_association](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_virtual_network.vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [time_sleep.wait_for_subnet](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alert_email_receivers"></a> [alert\_email\_receivers](#input\_alert\_email\_receivers) | List of email receivers for alerts provided by meshStack | <pre>list(object(<br>    {<br>      meshIdentifier = string<br>      username       = string<br>      firstName      = string<br>      lastName       = string<br>      email          = string<br>      euid           = string<br>      roles          = list(string)<br>    }<br>  ))</pre> | `[]` | no |
| <a name="input_alert_webhook_receivers"></a> [alert\_webhook\_receivers](#input\_alert\_webhook\_receivers) | List of webhook receivers for alerts (Teams, Slack, etc.) | <pre>list(object({<br>    name = string<br>    uri  = string<br>  }))</pre> | `[]` | no |
| <a name="input_azure_delay_seconds"></a> [azure\_delay\_seconds](#input\_azure\_delay\_seconds) | Delay in seconds to wait for Azure resources to be ready | `number` | `30` | no |
| <a name="input_bastion_sku"></a> [bastion\_sku](#input\_bastion\_sku) | SKU of the Azure Bastion Host | `string` | `"Basic"` | no |
| <a name="input_bastion_subnet_cidr"></a> [bastion\_subnet\_cidr](#input\_bastion\_subnet\_cidr) | CIDR block for the AzureBastionSubnet (minimum /27) | `string` | n/a | yes |
| <a name="input_enable_observability"></a> [enable\_observability](#input\_enable\_observability) | Enable comprehensive observability (alerts, monitoring) | `bool` | `true` | no |
| <a name="input_enable_resource_locks"></a> [enable\_resource\_locks](#input\_enable\_resource\_locks) | Enable resource locks to prevent accidental deletion/modification | `bool` | `true` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region where resources will be deployed | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the Azure Bastion deployment | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group where Bastion will be deployed | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vnet_name"></a> [vnet\_name](#input\_vnet\_name) | Name of the virtual network where Bastion subnet will be created | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_action_group_id"></a> [action\_group\_id](#output\_action\_group\_id) | The ID of the central action group for notifications |
| <a name="output_action_group_name"></a> [action\_group\_name](#output\_action\_group\_name) | The name of the central action group for notifications |
| <a name="output_bastion_host_fqdn"></a> [bastion\_host\_fqdn](#output\_bastion\_host\_fqdn) | The FQDN of the Azure Bastion Host |
| <a name="output_bastion_host_id"></a> [bastion\_host\_id](#output\_bastion\_host\_id) | The ID of the Azure Bastion Host |
| <a name="output_bastion_host_name"></a> [bastion\_host\_name](#output\_bastion\_host\_name) | The name of the Azure Bastion Host |
| <a name="output_bastion_nsg_id"></a> [bastion\_nsg\_id](#output\_bastion\_nsg\_id) | The ID of the Bastion Network Security Group |
| <a name="output_bastion_public_ip"></a> [bastion\_public\_ip](#output\_bastion\_public\_ip) | The public IP address of the Azure Bastion Host |
| <a name="output_bastion_resource_health_alert_id"></a> [bastion\_resource\_health\_alert\_id](#output\_bastion\_resource\_health\_alert\_id) | The ID of the Bastion resource health alert |
| <a name="output_bastion_subnet_id"></a> [bastion\_subnet\_id](#output\_bastion\_subnet\_id) | The ID of the AzureBastionSubnet |
| <a name="output_service_health_alert_id"></a> [service\_health\_alert\_id](#output\_service\_health\_alert\_id) | The ID of the service health alert |
| <a name="output_subscription_resource_health_alert_id"></a> [subscription\_resource\_health\_alert\_id](#output\_subscription\_resource\_health\_alert\_id) | The ID of the subscription resource health alert |
| <a name="output_vnet_address_space"></a> [vnet\_address\_space](#output\_vnet\_address\_space) | The address space of the POC Virtual Network |
| <a name="output_vnet_id"></a> [vnet\_id](#output\_vnet\_id) | The ID of the POC Virtual Network |
| <a name="output_vnet_name"></a> [vnet\_name](#output\_vnet\_name) | The name of the POC Virtual Network |
| <a name="output_workload_subnet_id"></a> [workload\_subnet\_id](#output\_workload\_subnet\_id) | The ID of workload subnet |
<!-- END_TF_DOCS -->