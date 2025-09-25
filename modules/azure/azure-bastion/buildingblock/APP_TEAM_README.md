# Azure Bastion

## Beschreibung
Dieser Building Block stellt einen Azure Bastion Host für sichere RDP- und SSH-Konnektivität zu Virtual Machines in Ihrem Azure Virtual Network bereit. Er eliminiert die Notwendigkeit, VMs dem öffentlichen Internet auszusetzen und bietet gleichzeitig sicheren Remote-Zugriff über das Azure Portal.

## Nutzungsmotivation
Dieser Building Block ist für Anwendungsteams gedacht, die sicheren, zentralisierten Zugriff auf Virtual Machines benötigen, ohne diese dem öffentlichen Internet auszusetzen. Azure Bastion bietet eine sichere und nahtlose RDP/SSH-Erfahrung direkt über das Azure Portal und eliminiert die Notwendigkeit für VPN-Verbindungen oder Jump Boxes.

## Anwendungsbeispiele
- Ein Entwicklungsteam benötigt sicheren Zugriff auf Entwicklungs-VMs für Debugging und Wartung, ohne diese dem Internet auszusetzen.
- Ein Operations-Team benötigt sicheren administrativen Zugriff auf Produktions-VMs für Monitoring und Troubleshooting.
- Ein Sicherheitsteam möchte kontrollierten Zugriff auf sensitive Workloads bereitstellen und dabei Audit Trails und Compliance aufrechterhalten.

## Geteilte Verantwortung

| Verantwortlichkeit | Platform Team | Application Team |
|-------------------|---------------|------------------|
| Bereitstellung und Konfiguration von Azure Bastion | ✅ | ❌ |
| Verwaltung von Bastion Subnet und Network Security | ✅ | ❌ |
| Aufrechterhaltung der Bastion-Verfügbarkeit und Updates | ✅ | ❌ |
| Konfiguration von VM-Zugriffsberechtigungen | ❌ | ✅ |
| Verwaltung von VM-Benutzerkonten und Authentifizierung | ❌ | ✅ |
| Monitoring und Logging von VM-Zugriffssitzungen | ✅ | ⚠️ (Anwendungsspezifische Logs) |

## Empfehlungen für sichere und effiziente Bastion-Nutzung
- **Azure RBAC verwenden**: Gewähren Sie Least-Privilege-Zugriff auf VMs durch ordnungsgemäße Role Assignments
- **Session Recording aktivieren**: Konfigurieren Sie Diagnostic Settings, um Bastion-Sitzungen für Security Audits zu protokollieren
- **Access Patterns überwachen**: Verwenden Sie Azure Monitor, um ungewöhnliche Zugriffsmuster oder fehlgeschlagene Verbindungsversuche zu verfolgen
- **VM-Endpunkte sichern**: Stellen Sie sicher, dass VMs ordnungsgemäße Sicherheitskonfigurationen haben (Firewalls, aktualisierte Betriebssysteme, etc.)
- **Just-In-Time Access verwenden**: Erwägen Sie die Kombination mit Azure Security Centers JIT VM Access für zusätzliche Sicherheit

## Netzwerkanforderungen
- **Bastion Subnet**: Benötigt ein dediziertes Subnet namens "AzureBastionSubnet" mit mindestens /27 CIDR
- **Network Security Group**: Automatisch konfiguriert mit erforderlichen Regeln für Bastion-Funktionalität
- **Public IP**: Standard-SKU Public IP erforderlich für Bastion-Konnektivität
- **Virtual Network**: Muss in einem existierenden VNet mit verfügbarem Adressraum bereitgestellt werden