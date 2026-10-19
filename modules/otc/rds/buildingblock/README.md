---
name: T Cloud Public Relational Database
supportedPlatforms:
  - otc
description: |
  Provisions a managed MySQL, PostgreSQL or SQL Server database (RDS) in a T Cloud Public project, on the network the T Cloud Public Network building block created.
# The building block authenticates with the platform's backplane user, which the composing
# integration passes in; it provisions no cloud-side identity of its own.
requiresBackplane: false
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

The provider reads `OS_AUTH_URL`, `OS_DOMAIN_NAME`, `OS_ACCESS_KEY` and `OS_SECRET_KEY` from the
environment, which the meshStack integration sets. `tenant_id` is the building block's tenant, the
application team's project.
