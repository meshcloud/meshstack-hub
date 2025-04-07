# Azure Postgresql Integration with AKS

## Description
This building block provides an Azure Database for PostgreSQL instance integrated with Azure Kubernetes Service (AKS). It enables application teams to use a fully managed PostgreSQL database while ensuring seamless connectivity and security with their AKS workloads.

## Usage Motivation
This building block is for application teams deploying containerized applications on AKS that require a reliable, scalable, and managed PostgreSQL database. The integration ensures secure communication between AKS workloads and the database, reducing operational overhead.

## Usage Examples
- A development team deploys a microservice-based application on AKS that uses Azure PostgreSQL as the primary database.
- A data analytics team runs scheduled jobs in AKS that query PostgreSQL for reporting and processing.

## Shared Responsibility

| Responsibility          | Platform Team | Application Team |
|------------------------|--------------|----------------|
| Provisioning and configuring the PostgreSQL instance | ✅ | ❌ |
| Enforcing security policies (e.g., network restrictions, encryption) | ✅ | ❌ |
| Managing database backups and availability settings | ✅ | ❌ |
| Configuring AKS-to-PostgreSQL connectivity (private endpoints, VNET integration) | ✅ | ❌ |
| Creating and managing database schemas and tables | ❌ | ✅ |
| Managing application-level database performance tuning | ❌ | ✅ |
| Handling database queries and workload optimization | ❌ | ✅ |

## Recommendations for Secure and Efficient PostgreSQL Usage
- **Use private endpoints**: Ensure secure and private communication between AKS and PostgreSQL.
- **Enable automated backups**: Configure point-in-time recovery (PITR) for disaster recovery.
- **Use managed identities**: Avoid storing database credentials in application code by leveraging Azure Managed Identities for authentication.
- **Monitor and optimize performance**: Use Azure Monitor and Query Performance Insights to track database health.
- **Scale appropriately**: Choose the right tier (Single Server, Flexible Server, or Hyperscale) based on workload needs.

