# Azure PostgreSQL Database

## Description
This building block provisions a managed Azure PostgreSQL server and database via Terraform. It enables application teams to create secure, scalable relational databases with configurable performance settings, high availability, and built-in encryption.

## Usage Motivation
This building block is ideal for teams needing a fully managed PostgreSQL database within their Azure subscription. Use cases include:

- Hosting application databases (e.g., for web apps or microservices)
- Running analytics workloads
- Powering content management systems, e-commerce platforms, etc.

## Usage Examples

- A team deploys a PostgreSQL server with high availability for production workloads.
- A SaaS team provisions a developer database for testing.
- An analytics platform sets up a read-only reporting database.

## Shared Responsibility

| Responsibility                                                       | Platform Team | Application Team |
|----------------------------------------------------------------------|---------------|------------------|
| Provisioning and maintaining the PostgreSQL building block automation | ✅            | ❌               |
| Securing server (network, encryption, authentication)               | ✅            | ❌               |
| Configuring performance (compute tier, storage size, HA)            | ✅¹           | ✅               |
| Managing connection strings and credentials                         | ❌            | ✅               |
| Designing and maintaining database schema                           | ❌            | ✅               |
| Data seeding, migration, backups, and disaster recovery             | ❌            | ✅               |

¹ Databases are created using recommended defaults; teams should adjust via variable overrides.

## Configuration Recommendations

- **Enable high-availability** for production workloads.
- **Use private endpoint** to restrict network access.
- **Configure PostgreSQL version** and compute tier based on workload demands.
- **Use Azure Key Vault** or managed identities for secure credential storage.
- **Apply retention and backup policies** via Terraform flags (`backup_retention_days`).
- **Tag resources** properly for cost center, environment, and project traceability.
