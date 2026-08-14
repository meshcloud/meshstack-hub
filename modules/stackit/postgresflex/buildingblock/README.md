---
name: STACKIT PostgreSQL Flex
supportedPlatforms:
  - stackit
description: Provisions a managed STACKIT PostgreSQL Flex instance with a database and a database user, or only a database and a user inside an instance that already exists.
---

# STACKIT PostgreSQL Flex Building Block

This building block module creates a managed PostgreSQL Flex instance in an existing STACKIT
project, plus one database and one database user that owns it. It can also create only the database
and the user inside an instance that already exists, so several tenants share one instance. Either
way it returns the host, the port, the database name, the user, the generated password and a
ready-to-use connection string.

The module is used in two ways. A reference architecture sources it directly as a Terraform module,
which keeps STACKIT resources out of the architecture itself. An application team orders it as a
building block through meshStack, wired up by the `meshstack_integration.tf` at the module root.

## Two entry points, and they differ only in who configures the provider

`buildingblock/` is the root meshStack runs when an application team orders the building block. It
configures the `stackit` provider and calls `buildingblock/database` once.

`buildingblock/database` holds the instance, the database and the owner user, and declares no
provider configuration. A composition that creates one database per tenant sources this module. It
cannot source `buildingblock/`, because a module that carries its own provider configuration is a
legacy module and OpenTofu rejects `count`, `for_each` and `depends_on` on every call to it.

```hcl
provider "stackit" {
  default_region        = "eu01"
  service_account_email = var.stackit_service_account_email
  use_oidc              = true
}

module "tenant_database" {
  for_each = var.tenants
  source   = "github.com/meshcloud/meshstack-hub//modules/stackit/postgresflex/buildingblock/database?ref=main"

  project_id           = var.stackit_project_id
  existing_instance_id = var.shared_instance_id

  database_name       = "langfuse_${each.key}"
  database_username   = "langfuse_${each.key}"
  database_user_roles = ["login"]
}
```

Both entry points take the same inputs, apart from `service_account_email`, which only the root
needs for its provider. They return the same outputs, and the root passes every one of them
through. Building blocks ordered before the resources moved into the submodule keep their instance:
three `moved` blocks in the root carry every address across.

## Two modes: a whole instance, or a database inside one

`existing_instance_id` selects the mode, and exactly one of it and `instance_name` must be set.

Leave `existing_instance_id` unset and the module creates the instance, the database and the owner
user as one unit. This is what an ordered building block does, and it is the only mode the building
block definition exposes.

Set `existing_instance_id` to the UUID of an instance that already exists and the module creates
only the database and the owner user inside it. Several tenants then share one instance and stay
separated by database name, which is what the AI platform reference architecture does: one
PostgreSQL Flex instance carries one Langfuse database per tenant. A managed instance is expensive
and mostly idle for a single tenant, so sharing one is the difference between a platform that scales
to fifty tenants and one that does not.

```hcl
module "tenant_database" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/postgresflex/buildingblock?ref=main"

  project_id           = var.stackit_project_id
  existing_instance_id = var.shared_instance_id

  database_name       = "langfuse_${var.tenant}"
  database_username   = "langfuse_${var.tenant}"
  database_user_roles = ["login"]
}
```

One call creates one database and one user, so a caller that serves several tenants at once calls
the module once per tenant. Source `buildingblock/database` for that and drive it with `for_each`,
as the section above shows.

Database-only mode skips the instance resource, so every input describing the instance shape has no
effect: `instance_name`, `flavor_cpu`, `flavor_ram`, `replicas`, `storage_class`, `storage_size`,
`postgres_version`, `backup_schedule`, `retention_days`, `acl`, `allow_stackit_public_ip_ranges` and
`network_access_scope`. `project_id` must name the project the shared instance lives in and
`stackit_region` its region. The module cannot widen the ACL of an instance it does not own, so a
client that reaches the shared instance has to be covered by the ACL already.

The outputs are the same in both modes. `host`, `port` and the instance details the summary shows
come from the instance the module creates, or from a read of the existing one. `database_name`,
`username`, `password`, `connection_string` and `direct_connection_string` always describe the
database and the user this call created. `instance_id` is the created instance in the first mode and
the value of `existing_instance_id` in the second.

## Choosing the instance shape

STACKIT encodes CPU, RAM and node count in a single flavor ID. This module takes `flavor_cpu`,
`flavor_ram` and `replicas` as separate inputs and resolves the matching flavor through the
`stackit_postgresflex_flavors` data source, because `flavor_id` is the only field the provider still
supports. `replicas` is 1 for a single node or 3 for a replicated instance; STACKIT accepts no other
value. When no flavor matches, the module fails during plan and lists the flavors the project offers.

## How many connections one instance carries

The flavour decides `max_connections`, and STACKIT publishes the number for every flavour in
[Flavors and performance classes of PostgreSQL Flex][flavors]. These are the flavours this module
offers:

| CPU / RAM | `max_connections` | Usable after the 15 STACKIT reserves |
|---|---|---|
| 2 / 4 | 95 | 80 |
| 4 / 8 | 195 | 180 |
| 2 / 16 | 385 | 370 |
| 8 / 16 | 385 | 370 |
| 4 / 32 | 785 | 770 |
| 16 / 32 | 785 | 770 |
| 16 / 128 | 3170 | 3155 |

Three properties of that table matter when several tenants share one instance.

The limit follows RAM, not CPU. 2/16 and 8/16 both give 385, and 4/32 and 16/32 both give 785, so
buying vCPUs buys no connections. Take 4/32 over 16/32 for a connection-bound workload.

STACKIT reserves 15 connections for backup, monitoring and its other internal processes, and counts
them against the limit. The table's second column is what your clients actually get.

The value is not tunable. The API, the SDK and the Terraform provider expose no parameter group and
no options for PostgreSQL settings, so the flavour is the only lever. STACKIT lists PgBouncer in its
[FAQ][faq] as a future feature, but no release note has ever announced it, so a pooler is something
you run yourself. STACKIT states that CPU and RAM are per node, so a three-node replicated instance
does not multiply the limit — the primary still caps at the table value. Confirm with
`SHOW max_connections;` on the instance you got.

### Budgeting the connections across tenants

A Langfuse instance opens `pods × connection_limit` connections, and the platform's budget is

```
tenants × pods_per_tenant × connection_limit + 15 ≤ max_connections
```

Leave roughly 10 % free for migrations, for a `psql` session and for a rolling deploy in which the
old and the new pods overlap. On 4/32 that leaves about 693 connections to spend.

| Pods per tenant | `connection_limit` | Connections per tenant | Tenants on 4/32 |
|---|---|---|---|
| 4 | 5 | 20 | ~34 |
| 4 | 10 | 40 | ~17 |
| 8 | 10 | 80 | ~8 |

Around 40 Langfuse pods at `connection_limit=5` come to 200 connections, which even 2/16 carries. The
same 40 pods at `connection_limit=20` come to 800 and exceed every flavour below 16/128.

**Pin `connection_limit` in the `DATABASE_URL` query string.** Prisma sizes its pool as
`num_physical_cpus * 2 + 1` when the parameter is absent, and it reads the physical cores of the
*node*, not the pod's CPU limit — see [prisma-engines#4341][prisma-bug], which a maintainer called an
oversight and which was closed without a fix. On 16-core nodes each unpinned pod therefore takes 33
connections, 40 pods take 1320, and the number changes silently when a pod is rescheduled onto a
larger node. Unpinned, the platform runs out of connections at five tenants; pinned at 5, it reaches
several dozen.

Both consumers pin the value themselves. `modules/ai/langfuse` appends `connection_limit` from
`postgres_connection_limit`, which defaults to 5, and gives the migration connection a limit of its
own. `modules/ai/litellm` writes the same parameter from `postgres_connection_limit`, which defaults
to 10 there because the gateway is deployed once for the whole platform rather than once per tenant.

Put a PgBouncer in transaction mode in front of the instance when the sum above passes 90 % of the
usable column, when you cannot guarantee that every pod pins its pool, or when the only reason to
move to 16/128 would be the connection count. A pooler that collapses 800 mostly idle client
connections onto a few dozen server connections is much cheaper than 128 GiB of RAM. Point
`DIRECT_URL` at the instance and not at the pooler in that case, which is what
`direct_connection_string` is for: `prisma migrate deploy` runs at every pod start and fails behind
a transaction-mode pooler.

[flavors]: https://docs.stackit.cloud/products/databases/postgresql-flex/reference/flavors-and-performance-classes-of-postgresql-flex/
[faq]: https://docs.stackit.cloud/products/databases/postgresql-flex/faq/
[prisma-bug]: https://github.com/prisma/prisma-engines/issues/4341

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

## Migrations, DIRECT_URL and the roles the user needs

`connection_string` is the value an application takes as its `DATABASE_URL`.
`direct_connection_string` is the same URL under a second name, meant for `DIRECT_URL`. Prisma reads
`DIRECT_URL` when it runs migrations and `DATABASE_URL` for everything else, so an operator can put
a connection pooler in front of the instance for the application traffic and keep migrations on a
direct connection with a longer timeout. This module places no pooler in front of the instance, so
the two values are equal today, and the second output gives a caller that later adds one a stable
name to wire `DIRECT_URL` to.

The owner user needs the `login` role and nothing else. A Prisma project that runs
`prisma migrate dev` needs a shadow database, and creating one needs `CREATEDB` — but `migrate dev`
is a development command. Langfuse runs `prisma migrate deploy` in its container, which applies the
migration files as they are, opens no shadow database and never issues `CREATE DATABASE`. Set
`database_user_roles = ["login"]` for such an application. The default is `["login", "createdb"]`,
which stays as it is so existing callers keep the roles their users already have.

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

| Name | Source | Version |
|------|--------|---------|
| <a name="module_database"></a> [database](#module\_database) | ./database | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acl"></a> [acl](#input\_acl) | Source IPv4 CIDR ranges allowed to open a connection to the instance. The default is the set of<br/>STACKIT service ranges that STACKIT documents as the predefined ACL for its data services, so<br/>other STACKIT services can reach the instance.<br/><br/>An SKE cluster leaves its network through a router that applies NAT, so the instance sees the<br/>cluster's public egress IP and not a private address. Add that egress IP as a /32 entry when the<br/>cluster's range is not already covered here. Never add 0.0.0.0/0 — STACKIT documents that as<br/>something to avoid, because it opens the instance to every address on the internet. | `list(string)` | <pre>[<br/>  "193.148.160.0/19",<br/>  "45.129.40.0/21",<br/>  "45.135.244.0/22"<br/>]</pre> | no |
| <a name="input_allow_stackit_public_ip_ranges"></a> [allow\_stackit\_public\_ip\_ranges](#input\_allow\_stackit\_public\_ip\_ranges) | Add every public IP range STACKIT publishes to the ACL, on top of `acl`. This reads the `stackit_public_ip_ranges` data source, which is the machine-readable list STACKIT keeps current. Turn it on when the hardcoded default in `acl` goes stale, at the cost of a much wider allowlist. | `bool` | `false` | no |
| <a name="input_backup_schedule"></a> [backup\_schedule](#input\_backup\_schedule) | Cron expression that decides when STACKIT takes the daily backup. Minute and hour must be numeric, for example '0 2 * * *' for 02:00 UTC. | `string` | `"0 2 * * *"` | no |
| <a name="input_database_name"></a> [database\_name](#input\_database\_name) | Name of the database created on the instance. | `string` | `"app"` | no |
| <a name="input_database_user_roles"></a> [database\_user\_roles](#input\_database\_user\_roles) | Roles granted to the database user. STACKIT supports `login` and `createdb`. Applications that run their migrations with `prisma migrate deploy`, Langfuse among them, need only `login`. | `list(string)` | <pre>[<br/>  "login",<br/>  "createdb"<br/>]</pre> | no |
| <a name="input_database_username"></a> [database\_username](#input\_database\_username) | Name of the database user that owns the database. STACKIT generates the password and this module returns it as a sensitive output. | `string` | `"app"` | no |
| <a name="input_existing_instance_id"></a> [existing\_instance\_id](#input\_existing\_instance\_id) | UUID of a PostgreSQL Flex instance that already exists. Leave it unset and the module creates the<br/>instance, the database and the owner user as one unit. Set it and the module creates only the<br/>database and the owner user inside that instance, so several tenants can share one instance and<br/>stay separated by database name.<br/><br/>Database-only mode skips the instance resource, so every input describing the instance shape has<br/>no effect: `instance_name`, `flavor_cpu`, `flavor_ram`, `replicas`, `storage_class`,<br/>`storage_size`, `postgres_version`, `backup_schedule`, `retention_days`, `acl`,<br/>`allow_stackit_public_ip_ranges` and `network_access_scope`. `project_id` must name the project<br/>the shared instance lives in and `stackit_region` its region. | `string` | `null` | no |
| <a name="input_flavor_cpu"></a> [flavor\_cpu](#input\_flavor\_cpu) | Number of vCPUs of the instance flavor. Together with `flavor_ram` and `replicas` this selects a STACKIT flavor. STACKIT offers 2/4, 4/8, 16/32, 2/16, 4/32, 16/128 and 8/16 as CPU/RAM pairs. | `number` | `2` | no |
| <a name="input_flavor_ram"></a> [flavor\_ram](#input\_flavor\_ram) | Memory of the instance flavor in GiB. Must form a valid pair with `flavor_cpu`. Memory also decides `max_connections`: 4 GiB gives 95, 8 GiB gives 195, 16 GiB gives 385, 32 GiB gives 785 and 128 GiB gives 3170, of which STACKIT reserves 15 for itself. The vCPU count has no effect on the limit. | `number` | `4` | no |
| <a name="input_instance_name"></a> [instance\_name](#input\_instance\_name) | Name of the PostgreSQL Flex instance the module creates. Leave it unset in database-only mode, where `existing_instance_id` selects the instance instead. | `string` | `null` | no |
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
| <a name="output_direct_connection_string"></a> [direct\_connection\_string](#output\_direct\_connection\_string) | Connection string that addresses the instance's write endpoint directly, never a connection pooler placed in front of it. Langfuse takes it as DIRECT\_URL and runs its Prisma migrations over it. This module places no pooler in front of the instance, so the value equals `connection_string` today, and the separate output gives a caller that later adds one a stable name to wire DIRECT\_URL to. |
| <a name="output_host"></a> [host](#output\_host) | DNS name of the instance's write endpoint. |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | UUID of the PostgreSQL Flex instance. In database-only mode this is the `existing_instance_id` the caller passed in. |
| <a name="output_password"></a> [password](#output\_password) | Password of the database user. STACKIT generates it and shows it only once. |
| <a name="output_port"></a> [port](#output\_port) | TCP port of the instance's write endpoint. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary with instance details and database credentials. |
| <a name="output_username"></a> [username](#output\_username) | Name of the database user that owns the database. |
<!-- END_TF_DOCS -->
