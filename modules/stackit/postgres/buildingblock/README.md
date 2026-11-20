---
name: STACKIT PostgreSQL
supportedPlatforms:
  - stackit
description: Provisions a managed STACKIT PostgreSQL Flex instance, or a database and its owner user on an existing one.
---

# STACKIT PostgreSQL Building Block

This building block module creates a STACKIT PostgreSQL Flex instance, or a database and its owner
user on an existing instance.

## Two modes

- **Instance mode** (`existing_instance_id` null): creates an instance and nothing else. Takes
  about three minutes. Outputs `instance_id`, `host` and `port`.
- **Database mode** (`existing_instance_id` set): creates a database and its owner user on that
  instance, both named `<workspace>_<project>`. Takes a few seconds. Adds the outputs `database`,
  `username`, `jdbc_url` and `uri`, none of which holds the password.

`meshstack_integration.tf` registers one variant per deployment: `database_only = true` with
`stackit_existing_instance_id` registers "STACKIT PostgreSQL Database", the default registers
"STACKIT PostgreSQL". Deploy it twice to offer both.

### A shared instance per stage

1. Order the instance variant once per stage, for example a single node for dev and three nodes
   for prod. Its `instance_id` output is the ID to share.
2. Deploy the database variant once per stage, each with the instance of that stage and
   `meshstack.supported_platforms` set to the landing zone of that stage.
3. To hand the credentials to workloads, publish a connector instead of step 2: a building block
   of your own that wraps `buildingblock/modules/database`, see
   [Credentials and connectors](#credentials-and-connectors).

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

## Credentials and connectors

No building block output holds the password, so the database variant on its own hands out none. It
is the base for connector definitions; without one, a project member resets the user's password in
the STACKIT portal.

A connector is a building block of your own that wraps `buildingblock/modules/database`. That
module configures no provider and, unlike the building block, has a `password` output, which the
connector passes on inside its own run, for example into a Kubernetes Secret a Spring Boot pod
reads with `envFrom`:

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

  project_id    = var.stackit_project_id
  instance_id   = var.existing_instance_id
  database_name = local.name
  username      = local.name
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
      instance_name = { value = jsonencode("shared-prod") }
      flavor        = { value = jsonencode("4.8") }
      replicas      = { value = jsonencode("3") }
      storage_size  = { value = jsonencode(20) }
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

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_database"></a> [database](#module\_database) | ./modules/database | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [stackit_postgresflex_instance.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/postgresflex_instance) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_acl"></a> [acl](#input\_acl) | IPv4 CIDR ranges allowed to connect. The instance has a public endpoint and accepts no other source. Workloads on an SKE cluster connect from the cluster's egress address. | `list(string)` | `null` | no |
| <a name="input_backup_retention_days"></a> [backup\_retention\_days](#input\_backup\_retention\_days) | Number of days STACKIT keeps backups. | `number` | `null` | no |
| <a name="input_backup_schedule"></a> [backup\_schedule](#input\_backup\_schedule) | Cron expression in UTC for the backup, with numeric minute and hour, for example `0 2 * * *`. | `string` | `null` | no |
| <a name="input_existing_instance_id"></a> [existing\_instance\_id](#input\_existing\_instance\_id) | ID of a PostgreSQL Flex instance in `project_id`. The building block then creates a database and its owner user on it. Null creates an instance and nothing else. | `string` | `null` | no |
| <a name="input_flavor"></a> [flavor](#input\_flavor) | Size of each node as `<vCPU>.<RAM in GB>`, for example `2.4`. | `string` | `null` | no |
| <a name="input_instance_name"></a> [instance\_name](#input\_instance\_name) | Name of the PostgreSQL Flex instance. This and the other instance settings are required without `existing_instance_id` and ignored with it. | `string` | `null` | no |
| <a name="input_postgres_version"></a> [postgres\_version](#input\_postgres\_version) | PostgreSQL major version. | `string` | `null` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID of the instance. | `string` | n/a | yes |
| <a name="input_project_identifier"></a> [project\_identifier](#input\_project\_identifier) | meshStack project of the building block. Database and user are named `<workspace>_<project>`. | `string` | `null` | no |
| <a name="input_replicas"></a> [replicas](#input\_replicas) | Number of nodes: 1 for a single node, 3 for a highly available replica set. | `number` | `null` | no |
| <a name="input_storage_class"></a> [storage\_class](#input\_storage\_class) | Storage performance class, from `premium-perf2-stackit` (1000 IOPS) to `premium-perf12-stackit` (20000 IOPS). Cannot change after creation. | `string` | `null` | no |
| <a name="input_storage_size"></a> [storage\_size](#input\_storage\_size) | Storage size in GB. Can grow, never shrink. | `number` | `null` | no |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | meshStack workspace of the building block. Database and user are named `<workspace>_<project>`. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_database"></a> [database](#output\_database) | Name of the database. Only with `existing_instance_id`. |
| <a name="output_host"></a> [host](#output\_host) | DNS name of the instance's write endpoint. |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | ID of the PostgreSQL Flex instance: the one created, or the one the database is on. |
| <a name="output_jdbc_url"></a> [jdbc\_url](#output\_jdbc\_url) | JDBC URL of the database, without credentials. Only with `existing_instance_id`. |
| <a name="output_port"></a> [port](#output\_port) | TCP port of the instance's write endpoint. |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown in meshPanel after the run. |
| <a name="output_uri"></a> [uri](#output\_uri) | Connection URI of the database, without the password. Only with `existing_instance_id`. |
| <a name="output_username"></a> [username](#output\_username) | Name of the database user that owns the database. Only with `existing_instance_id`. |
<!-- END_TF_DOCS -->
