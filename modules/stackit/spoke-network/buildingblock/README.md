---
name: STACKIT Spoke Network
supportedPlatforms:
  - stackit
description: Provisions a routed network in a STACKIT project and attaches it to the platform hub network area.
---

# STACKIT Spoke Network — Building Block

Provisions a routed network in a STACKIT project and attaches it to the platform hub network area. Optionally creates a custom routing table with a default route via a firewall next-hop.

## Inputs

| Name | Type | Description |
|------|------|-------------|
| `project_id` | string | Tenant STACKIT project ID (from PLATFORM_TENANT_ID) |
| `organization_id` | string | STACKIT organization ID |
| `network_area_id` | string | Hub network area ID |
| `service_account_key_json` | string (sensitive) | Backplane SA credentials |
| `network_prefix_length` | number | Subnet prefix length (24–28, default 25) |
| `firewall_next_hop_ip` | string | Next-hop IP for default route; null = no routing table |
| `ipv4_nameservers` | string | JSON-encoded nameserver list; null = STACKIT defaults |

## Outputs

| Name | Description |
|------|-------------|
| `network_id` | Spoke network ID |
| `network_cidr` | Allocated CIDR block |
| `routing_table_id` | Custom routing table ID (null if no firewall) |
| `summary` | Markdown summary rendered in meshStack |
