# Azure Bastion Building Block

Diese Dokumentation dient als Referenzdokumentation für Plattform-Engineers, die dieses Modul verwenden.

## Berechtigungen

Dieser Building Block benötigt Berechtigungen zur Bereitstellung von Azure Bastion-Ressourcen, einschließlich:
- Bastion Host-Erstellung und -Verwaltung
- Public IP Address-Bereitstellung
- Virtual Network Subnet-Erstellung und -Änderung
- Network Security Group-Verwaltung
- Resource Locking-Funktionen

Die Backplane etabliert die notwendigen Role Definitions und Assignments für eine sichere Bereitstellung.

## Architektur

Der Building Block erstellt:
- **Azure Bastion Host**: Bietet sichere RDP/SSH-Konnektivität
- **AzureBastionSubnet**: Dediziertes Subnet mit mindestens /27 CIDR-Anforderung
- **Public IP Address**: Standard-SKU für Bastion-Konnektivität
- **Network Security Group**: Vorkonfiguriert mit allen erforderlichen Bastion-Regeln
- **Resource Locks**: Optionaler Schutz vor versehentlicher Löschung/Änderung

## Sicherheitsimplementierung

### Network Security Group-Regeln
**Eingehend:**
- HTTPS (443) vom Internet für Benutzerverbindungen
- HTTPS (443) vom GatewayManager für Azure-Kontrollebene
- HTTPS (443) vom AzureLoadBalancer für Health Probes
- Ports 8080, 5701 vom VirtualNetwork für Inter-Bastion-Kommunikation

**Ausgehend:**
- SSH (22) und RDP (3389) zum VirtualNetwork für VM-Verbindungen
- HTTPS (443) zu AzureCloud für Azure-Dienste
- Ports 8080, 5701 zum VirtualNetwork für Bastion-Kommunikation
- HTTP (80) zum Internet für Session-Metadaten

### Ressourcenschutz
- Management Locks verhindern versehentliche Löschung des Bastion Hosts
- Subnet Locks verhindern Änderungen an kritischen Netzwerkkonfigurationen
- RBAC-Integration gewährleistet ordnungsgemäße Zugriffskontrolle

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_role_assignment.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_definition.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | Name of the building block | `string` | n/a | yes |
| <a name="input_principal_ids"></a> [principal\_ids](#input\_principal\_ids) | Principal IDs to assign the role to | `set(string)` | n/a | yes |
| <a name="input_scope"></a> [scope](#input\_scope) | Scope for the role assignment | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_role_definition_id"></a> [role\_definition\_id](#output\_role\_definition\_id) | The ID of the created role definition |
<!-- END_TF_DOCS -->
