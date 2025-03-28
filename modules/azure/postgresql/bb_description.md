# Azure PostgreSQL

## Description
This building block provides an Azure Database for PostgreSQL instance, offering a fully managed, scalable, and secure relational database service. It supports enterprise-grade PostgreSQL workloads with automated maintenance, high availability, and built-in security features.

## Usage Motivation
This building block is for application teams that need a reliable and managed PostgreSQL database without the operational overhead of self-hosting. It is ideal for applications that require structured data storage, transaction consistency, and seamless integration with Azure services.

## Usage Examples
- A web application stores user data and transactional records in an Azure PostgreSQL database.
- A data analytics team uses Azure PostgreSQL as a backend for reporting and business intelligence queries.

## Shared Responsibility

| Responsibility          | Platform Team | Application Team |
|------------------------|--------------|----------------|
| Provisioning and configuring the PostgreSQL instance | ✅ | ❌ |
| Enforcing security policies (e.g., encryption, firewall rules) | ✅ | ❌ |
| Managing database backups and disaster recovery | ✅ | ❌ |
| Monitoring database performance and availability | ✅ | ❌ |
| Creating and managing database schemas and tables | ❌ | ✅ |
| Managing application-level database performance tuning | ❌ | ✅ |
| Handling database queries and indexing optimization | ❌ | ✅ |

## Recommendations for Secure and Efficient PostgreSQL Usage
- **Use private endpoints**: Restrict access to authorized Azure services via VNET integration.
- **Enable automated backups**: Configure point-in-time recovery (PITR) for data protection.
- **Enforce role-based access control**: Manage database permissions using PostgreSQL roles.
- **Optimize performance**: Use Query Performance Insights and connection pooling.
- **Choose the right pricing tier**: Select between Single Server, Flexible Server, or Hyperscale based on workload needs.
