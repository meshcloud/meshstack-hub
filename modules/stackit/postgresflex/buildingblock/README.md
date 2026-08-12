---
name: STACKIT PostgreSQL Flex
supportedPlatforms:
  - stackit
description: Provisions a managed STACKIT PostgreSQL Flex instance with a database and a database user.
---

# STACKIT PostgreSQL Flex Building Block

This building block module creates a managed PostgreSQL Flex instance in an existing STACKIT
project, plus one database and one database user that owns it. It returns the host, the port, the
database name, the user, the generated password and a ready-to-use connection string.

The module is used in two ways. A reference architecture sources it directly as a Terraform module,
which keeps STACKIT resources out of the architecture itself. An application team orders it as a
building block through meshStack, wired up by the `meshstack_integration.tf` at the module root.

## Choosing the instance shape

STACKIT encodes CPU, RAM and node count in a single flavor ID. This module takes `flavor_cpu`,
`flavor_ram` and `replicas` as separate inputs and resolves the matching flavor through the
`stackit_postgresflex_flavors` data source, because `flavor_id` is the only field the provider still
supports. `replicas` is 1 for a single node or 3 for a replicated instance; STACKIT accepts no other
value. When no flavor matches, the module fails during plan and lists the flavors the project offers.

## Reaching the instance — the ACL

A PostgreSQL Flex instance rejects every connection whose source address is not covered by its ACL.
Getting this wrong is the usual reason a workload times out against a fresh instance.

The `acl` input defaults to `193.148.160.0/19`, `45.129.40.0/21` and `45.135.244.0/22`. These are the
STACKIT service ranges that STACKIT documents as the predefined ACL of its data services, so the
default lets other STACKIT services reach the instance. The default does **not** cover arbitrary
clients on the internet, and it does not cover a client in your office network.

An SKE cluster does not connect from a private address. All egress traffic of a cluster leaves
through a single router that applies NAT, so the instance sees the cluster's public egress IPv4
address. STACKIT picks that address from its pool when the cluster is created and it stays fixed for
the cluster's lifetime, but STACKIT does not document that it falls inside the ranges above. Read the
egress IP from the cluster's overview page in the STACKIT Portal and add it as a `/32` entry:

```hcl
acl = ["193.148.160.0/19", "45.129.40.0/21", "45.135.244.0/22", "203.0.113.17/32"]
```

Set `allow_stackit_public_ip_ranges = true` to add every public range STACKIT publishes, read live
from the `stackit_public_ip_ranges` data source. That list is the one STACKIT keeps current, at the
cost of a much wider allowlist.

The module rejects `0.0.0.0/0`, because STACKIT documents that entry as one to avoid.

`network_access_scope` selects `PUBLIC` or `SNA`. `SNA` is in private preview and STACKIT rejects the
request when the project is not enabled for it, so the input is unset by default.

## PostgreSQL version

STACKIT PostgreSQL Flex **version 14 reaches end of life on 12 November 2026**, and version 13 is
already past its end of life. The module therefore defaults to version 17 and refuses anything below
16. Version 16 is supported until November 2028.

## Backups

STACKIT takes one backup per day at the time given by `backup_schedule`, a cron expression whose
minute and hour must be numeric. `retention_days` decides how long STACKIT keeps them and must be
between 32 and 90.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.110.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [stackit_postgresflex_database.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/postgresflex_database) | resource |
| [stackit_postgresflex_instance.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/postgresflex_instance) | resource |
| [stackit_postgresflex_user.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/postgresflex_user) | resource |
| [stackit_postgresflex_flavors.available](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/data-sources/postgresflex_flavors) | data source |
| [stackit_public_ip_ranges.stackit](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/data-sources/public_ip_ranges) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acl"></a> [acl](#input\_acl) | Source IPv4 CIDR ranges allowed to open a connection to the instance. The default is the set of<br/>STACKIT service ranges that STACKIT documents as the predefined ACL for its data services, so<br/>other STACKIT services can reach the instance.<br/><br/>An SKE cluster leaves its network through a router that applies NAT, so the instance sees the<br/>cluster's public egress IP and not a private address. Add that egress IP as a /32 entry when the<br/>cluster's range is not already covered here. Never add 0.0.0.0/0 — STACKIT documents that as<br/>something to avoid, because it opens the instance to every address on the internet. | `list(string)` | <pre>[<br/>  "193.148.160.0/19",<br/>  "45.129.40.0/21",<br/>  "45.135.244.0/22"<br/>]</pre> | no |
| <a name="input_allow_stackit_public_ip_ranges"></a> [allow\_stackit\_public\_ip\_ranges](#input\_allow\_stackit\_public\_ip\_ranges) | Add every public IP range STACKIT publishes to the ACL, on top of `acl`. This reads the `stackit_public_ip_ranges` data source, which is the machine-readable list STACKIT keeps current. Turn it on when the hardcoded default in `acl` goes stale, at the cost of a much wider allowlist. | `bool` | `false` | no |
| <a name="input_backup_schedule"></a> [backup\_schedule](#input\_backup\_schedule) | Cron expression that decides when STACKIT takes the daily backup. Minute and hour must be numeric, for example '0 2 * * *' for 02:00 UTC. | `string` | `"0 2 * * *"` | no |
| <a name="input_database_name"></a> [database\_name](#input\_database\_name) | Name of the database created on the instance. | `string` | `"app"` | no |
| <a name="input_database_user_roles"></a> [database\_user\_roles](#input\_database\_user\_roles) | Roles granted to the database user. STACKIT supports `login` and `createdb`. | `list(string)` | <pre>[<br/>  "login",<br/>  "createdb"<br/>]</pre> | no |
| <a name="input_database_username"></a> [database\_username](#input\_database\_username) | Name of the database user that owns the database. STACKIT generates the password and this module returns it as a sensitive output. | `string` | `"app"` | no |
| <a name="input_flavor_cpu"></a> [flavor\_cpu](#input\_flavor\_cpu) | Number of vCPUs of the instance flavor. Together with `flavor_ram` and `replicas` this selects a STACKIT flavor. STACKIT offers 2/4, 4/8, 16/32, 2/16, 4/32, 16/128 and 8/16 as CPU/RAM pairs. | `number` | `2` | no |
| <a name="input_flavor_ram"></a> [flavor\_ram](#input\_flavor\_ram) | Memory of the instance flavor in GiB. Must form a valid pair with `flavor_cpu`. | `number` | `4` | no |
| <a name="input_instance_name"></a> [instance\_name](#input\_instance\_name) | Name of the PostgreSQL Flex instance. | `string` | n/a | yes |
| <a name="input_network_access_scope"></a> [network\_access\_scope](#input\_network\_access\_scope) | Network access scope of the instance, either `PUBLIC` or `SNA`. Leave unset to get the STACKIT default. `SNA` is in private preview and STACKIT rejects the request when the project is not enabled for it. | `string` | `null` | no |
| <a name="input_postgres_version"></a> [postgres\_version](#input\_postgres\_version) | PostgreSQL major version. Version 14 reaches end of life on 12 November 2026, so pick 16 or newer. | `string` | `"17"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID the PostgreSQL Flex instance is created in. | `string` | n/a | yes |
| <a name="input_replicas"></a> [replicas](#input\_replicas) | Number of nodes. 1 creates a single-node instance, 3 creates a replicated instance. STACKIT supports no other value. | `number` | `1` | no |
| <a name="input_retention_days"></a> [retention\_days](#input\_retention\_days) | Number of days STACKIT keeps backups. STACKIT accepts 32 to 90. | `number` | `32` | no |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | Email of the STACKIT service account the provider authenticates as via workload identity federation. Leave unset when the caller supplies its own provider configuration. | `string` | `null` | no |
| <a name="input_stackit_region"></a> [stackit\_region](#input\_stackit\_region) | STACKIT region the instance is created in. Ignored when the caller supplies its own provider configuration. | `string` | `"eu01"` | no |
| <a name="input_storage_class"></a> [storage\_class](#input\_storage\_class) | Storage performance class. STACKIT offers premium-perf2-stackit through premium-perf12-stackit, with higher numbers giving more IOPS and throughput. | `string` | `"premium-perf2-stackit"` | no |
| <a name="input_storage_size"></a> [storage\_size](#input\_storage\_size) | Storage size of the instance in GB. | `number` | `20` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_connection_string"></a> [connection\_string](#output\_connection\_string) | Ready-to-use libpq connection string including the password. Applications such as LiteLLM and Langfuse take this as their DATABASE\_URL. |
| <a name="output_database_name"></a> [database\_name](#output\_database\_name) | Name of the database created on the instance. |
| <a name="output_host"></a> [host](#output\_host) | DNS name of the instance's write endpoint. |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | UUID of the PostgreSQL Flex instance. |
| <a name="output_password"></a> [password](#output\_password) | Password of the database user. STACKIT generates it and shows it only once. |
| <a name="output_port"></a> [port](#output\_port) | TCP port of the instance's write endpoint. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary with instance details and database credentials. |
| <a name="output_username"></a> [username](#output\_username) | Name of the database user that owns the database. |
<!-- END_TF_DOCS -->
