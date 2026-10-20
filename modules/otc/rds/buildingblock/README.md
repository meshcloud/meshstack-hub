---
name: T Cloud Public Relational Database
supportedPlatforms:
  - otc
description: |
  Provisions a managed MySQL, PostgreSQL or SQL Server database (RDS) in a T Cloud Public project, on the network the T Cloud Public Network building block created.
requiresBackplane: true
---

# T Cloud Public Relational Database Building Block

Creates a managed RDS instance in the application team's project by wrapping the
[iits-consulting RDS module](https://github.com/iits-consulting/terraform-opentelekomcloud-rds). The
instance gets its own security group, which admits the subnet's CIDR on the engine's port, and its
volumes are encrypted with a KMS key of its own. It has no public address.

The database is placed in the VPC and subnet both named `network_name` (default `app`), which the
T Cloud Public Network building block creates. Order that one first.

Without `db_version`, the newest version the region offers for the engine is used, for SQL Server
its Standard Edition. `size` maps to a flavor of 2, 4 or 8 vCPUs with 2 GB of memory per vCPU.

## Authentication

The building block holds no access key. Its runs sign in through workload identity federation: the
pre-run script from [`otc/workload-identity`](../../workload-identity) exchanges the run token at
the identity provider in `OTC_IDENTITY_PROVIDER`, which the [backplane](../backplane) federates, for
a temporary access key valid for one hour. The provider reads it from the file the script writes.
Without that file, as outside meshStack, it reads `OS_ACCESS_KEY` and `OS_SECRET_KEY` from the
environment.
