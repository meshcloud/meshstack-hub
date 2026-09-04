# Enterprise-Scale Policies (foundation glue)

A trimmed port of collie-hub's [`kit/azure/util/azure-policies`](https://github.com/meshcloud/collie-hub/tree/main/kit/azure/util/azure-policies)
helper. It reads policy JSON files from `policy_path` and applies them to a single management group:

- `policy_definitions/*.json` → custom policy definitions
- `policy_assignments/*.tmpl.json` → management-group policy assignments (templated)

Policy set (initiative) support from the upstream helper is intentionally omitted here: azurerm v5
reworked `azurerm_policy_set_definition` and the shipped libs use built-in definitions only, so no
initiatives are needed.

`*.tmpl.json` files are expanded with `templatefile()` using `template_file_variables` (e.g.
`default_location`), so assignments can reference scopes and regions.

This is **foundation glue** for the Azure Landing Zone reference architecture — the caller
instantiates it once per archetype (Corp/Online/Sandbox), pointing `policy_path` at the archetype's
curated policy lib under [`../../policies/`](../../policies) and `management_group_id` at the
archetype's existing management group. The shipped libs use only built-in Azure policy definitions
(allowed locations; no public IPs on NICs for Corp), so no custom definitions are required.
