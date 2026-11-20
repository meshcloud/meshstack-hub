---
name: STACKIT PostgreSQL
supportedPlatforms:
  - stackit
description: Provisions a managed PostgreSQL database on STACKIT PostgreSQL Flex, with a database and its owner user.
---

# STACKIT PostgreSQL Building Block

This building block module creates a STACKIT PostgreSQL Flex instance, one database and the user
that owns it.

## Two modes

- **Instance mode** (`existing_instance_id` null): creates an instance, one database and its owner
  user. Takes about three minutes.
- **Database mode** (`existing_instance_id` set): creates only a database and its owner user on
  that instance. Takes a few seconds. The instance settings are ignored, host and port come from the
  existing instance, and database and user are named `<workspace>_<project>` unless
  `database_name` and `username` are set.

`meshstack_integration.tf` registers one variant per deployment: `database_only = true` with
`stackit_existing_instance_id` registers "STACKIT PostgreSQL Database", the default registers
"STACKIT PostgreSQL". Deploy it twice to offer both.

### A shared instance per stage

1. Order the instance variant once per stage, for example a single node for dev and three nodes
   for prod. Its `instance_id` output is the ID to share.
2. Deploy the database variant once per stage, each with the instance of that stage and
   `meshstack.supported_platforms` set to the landing zone of that stage.
3. To hand the credentials to workloads, wrap `buildingblock/modules/database` in a building block
   of your own, see [Wrapping the database module](#wrapping-the-database-module).

### Isolation on a shared instance

STACKIT offers the user roles `login` and `createdb`. A user in database mode gets `login` only. It
owns its database, and tested against a live instance:

| User A on database B | Result |
|---|---|
| Connect | allowed, PostgreSQL grants `CONNECT` to everyone |
| List table names | allowed |
| Read or write a table | denied |
| Create a table or a schema | denied |
| Create a temporary table | allowed |
| Create a database | denied |

The owner closes its database to other users with `REVOKE CONNECT ON DATABASE <name> FROM PUBLIC`.
The building block cannot do that, because the STACKIT API runs no SQL.

## Identity

The building block authenticates as a STACKIT service account via workload identity federation.
The module creates none by default. Use the account of your platform, as the STACKIT Kubernetes
reference architecture does with the `stackit/service-account` and
`stackit/service-account-federation` building blocks:

- The account holds **`postgres-flex.admin`** on the project of the instances, or on the folder of
  the tenant projects. STACKIT offers the role at project and folder scope only. The project role
  `editor` has the same permissions except `postgres-flex.instance.force-delete`.
- The account federates the definition: list the definition's uuid in
  `federated_building_block_definitions` of a `stackit/service-account-federation` building block.

`meshstack_integration.tf` then takes the account in one of two ways:

| `stackit_service_account_email` | Who names the account | For |
|---|---|---|
| null | each order, in the input `STACKIT_SERVICE_ACCOUNT_EMAIL` | a composition that orders the building block |
| set | the platform team, once | a definition application teams order from the marketplace |

`create_backplane = true` creates a service account of the definition's own instead, see
[backplane](../backplane/README.md).

## Where the instance lives

`stackit_project_id` in `meshstack_integration.tf` chooses the placement:

- **Set:** every instance is created in that project of the platform team. The definition then
  needs no STACKIT tenant. Set `meshstack.supported_platforms` to offer it on another platform, for
  example on Kubernetes namespace tenants whose workloads use the database.
- **Null:** each instance is created in the STACKIT project of the tenant the building block is
  ordered for.

## Network access

An instance has a public endpoint and accepts connections only from the CIDR ranges in `acl`.
Workloads on an SKE cluster leave through the cluster's egress address, which
`stackit ske cluster describe <name> -o json` reports as `status.egressAddressRanges`. Set it as
`stackit_acl`, the default of the input.

## Credentials

The building block has no output that holds the password. With the inputs `output_to_vault` and
`output_to_vault_password` it writes one secret to a Vault KV v2 store, such as a STACKIT Secrets
Manager instance, at `<path_prefix>stackit/postgres/<instance id>`, in database mode at
`<path_prefix>stackit/postgres/<instance id>/<database>`. The object under its key
`kubernetes-secret` has the entries `host`, `port`, `database`, `username`, `password`, `jdbc_url`
and `uri`. The `vault_secret` output names the path, so a composing building block can read the
secret and create a Kubernetes Secret from it; `ske/forgejo-connector` does so for every path in
its `additional_kubernetes_secrets`.

Without these inputs nobody gets the password, and a project member resets it in the STACKIT portal.

## Wrapping the database module

`buildingblock/modules/database` holds the resources and configures no provider. Unlike the
building block, it has a `password` output, so a wrapping building block can pass the password on
inside its own run, for example into a Kubernetes Secret a Spring Boot pod reads with `envFrom`:

```hcl
provider "stackit" {
  default_region = "eu01"
}

locals {
  # A STATIC FILE input, as in modules/kubernetes/manifest.
  kubeconfig = yamldecode(file("${path.module}/kubeconfig.yaml"))
  name       = replace("${var.workspace_identifier}_${var.project_identifier}", "-", "_")
}

provider "kubernetes" {
  host                   = one(local.kubeconfig.clusters).cluster.server
  cluster_ca_certificate = base64decode(one(local.kubeconfig.clusters).cluster["certificate-authority-data"])
  token                  = one(local.kubeconfig.users).user.token
}

module "database" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/postgres/buildingblock/modules/database?ref=main"

  project_id           = var.stackit_project_id
  existing_instance_id = var.existing_instance_id
  database_name        = local.name
  username             = local.name
}

resource "kubernetes_secret_v1" "datasource" {
  metadata {
    name      = "postgres"
    namespace = var.namespace
  }

  data = {
    SPRING_DATASOURCE_URL      = module.database.jdbc_url
    SPRING_DATASOURCE_USERNAME = module.database.username
    SPRING_DATASOURCE_PASSWORD = module.database.password
  }
}
```

Its definition assigns `namespace` from `PLATFORM_TENANT_ID`, the two identifiers from
`WORKSPACE_IDENTIFIER` and `PROJECT_IDENTIFIER`, and the rest as `STATIC` inputs. Its service
account needs `postgres-flex.admin` on the project, see [Identity](#identity).

## Ordering from another building block

Every instance setting is an input, so a composing building block sets it per landing zone:

```hcl
resource "meshstack_building_block" "postgres" {
  spec = {
    building_block_definition_version_ref = var.postgres_definition_version_ref
    display_name                          = "postgres"
    target_ref                            = { kind = "meshTenant", uuid = var.tenant_uuid }

    inputs = {
      instance_name = { value = jsonencode("petclinic-prod") }
      flavor        = { value = jsonencode("4.8") }
      replicas      = { value = jsonencode("3") }
      storage_size  = { value = jsonencode(20) }

      output_to_vault          = { value = jsonencode(jsonencode(var.output_to_vault)) }
      output_to_vault_password = { sensitive = { secret_value = var.output_to_vault_password, secret_version = nonsensitive(sha256(var.output_to_vault_password)) } }
    }
  }

  lifecycle {
    postcondition {
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.110.0, < 1.0.0 |
| <a name="requirement_vault"></a> [vault](#requirement\_vault) | >= 5.12.0, < 6.0.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_database"></a> [database](#module\_database) | ./modules/database | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [vault_kv_secret_v2.this](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/kv_secret_v2) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_acl"></a> [acl](#input\_acl) | IPv4 CIDR ranges allowed to connect. The instance has a public endpoint and accepts no other source. Workloads on an SKE cluster connect from the cluster's egress address. | `list(string)` | `null` | no |
| <a name="input_backup_retention_days"></a> [backup\_retention\_days](#input\_backup\_retention\_days) | Number of days STACKIT keeps backups. | `number` | `null` | no |
| <a name="input_backup_schedule"></a> [backup\_schedule](#input\_backup\_schedule) | Cron expression in UTC for the backup, with numeric minute and hour, for example `0 2 * * *`. | `string` | `null` | no |
| <a name="input_database_name"></a> [database\_name](#input\_database\_name) | Name of the database. Null derives it from `workspace_identifier` and `project_identifier`. | `string` | `null` | no |
| <a name="input_existing_instance_id"></a> [existing\_instance\_id](#input\_existing\_instance\_id) | ID of a PostgreSQL Flex instance in `project_id`. The building block then creates only a database and its owner user on it. Null creates an instance. | `string` | `null` | no |
| <a name="input_flavor"></a> [flavor](#input\_flavor) | Size of each node as `<vCPU>.<RAM in GB>`, for example `2.4`. | `string` | `null` | no |
| <a name="input_instance_name"></a> [instance\_name](#input\_instance\_name) | Name of the PostgreSQL Flex instance. This and the other instance settings are ignored with `existing_instance_id`. | `string` | `null` | no |
| <a name="input_output_to_vault"></a> [output\_to\_vault](#input\_output\_to\_vault) | Vault KV v2 userpass login that writes the connection data, password included, to `<path_prefix>stackit/postgres/<instance id>`, with `existing_instance_id` to `<path_prefix>stackit/postgres/<instance id>/<database>`. Null hands out no password. | <pre>object({<br/>    address     = string<br/>    mount       = string<br/>    username    = string<br/>    path_prefix = optional(string, "")<br/>  })</pre> | `null` | no |
| <a name="input_output_to_vault_password"></a> [output\_to\_vault\_password](#input\_output\_to\_vault\_password) | Password of the `output_to_vault` user. | `string` | `null` | no |
| <a name="input_postgres_version"></a> [postgres\_version](#input\_postgres\_version) | PostgreSQL major version. | `string` | `null` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID the instance is created in. | `string` | n/a | yes |
| <a name="input_project_identifier"></a> [project\_identifier](#input\_project\_identifier) | meshStack project of the building block, for the derived database name. | `string` | `null` | no |
| <a name="input_replicas"></a> [replicas](#input\_replicas) | Number of nodes: 1 for a single node, 3 for a highly available replica set. | `number` | `null` | no |
| <a name="input_storage_class"></a> [storage\_class](#input\_storage\_class) | Storage performance class, from `premium-perf2-stackit` (1000 IOPS) to `premium-perf12-stackit` (20000 IOPS). Cannot change after creation. | `string` | `null` | no |
| <a name="input_storage_size"></a> [storage\_size](#input\_storage\_size) | Storage size in GB. Can grow, never shrink. | `number` | `null` | no |
| <a name="input_username"></a> [username](#input\_username) | Name of the database user that owns the database. Null derives it like `database_name`. | `string` | `null` | no |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | meshStack workspace of the building block, for the derived database name. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_database"></a> [database](#output\_database) | Name of the database. |
| <a name="output_host"></a> [host](#output\_host) | DNS name of the instance's write endpoint. |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | ID of the PostgreSQL Flex instance the database is on. |
| <a name="output_jdbc_url"></a> [jdbc\_url](#output\_jdbc\_url) | JDBC URL of the database, without credentials. |
| <a name="output_port"></a> [port](#output\_port) | TCP port of the instance's write endpoint. |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown in meshPanel after the run. |
| <a name="output_uri"></a> [uri](#output\_uri) | Connection URI of the database, without the password. |
| <a name="output_username"></a> [username](#output\_username) | Name of the database user that owns the database. |
| <a name="output_vault_secret"></a> [vault\_secret](#output\_vault\_secret) | `{path, secret_hash}` of the secret in Vault, where `secret_hash` changes with its content; `{}` without `output_to_vault`. Its key `kubernetes-secret` holds `host`, `port`, `database`, `username`, `password`, `jdbc_url` and `uri` with the password. |
<!-- END_TF_DOCS -->
