# Azure Key Vault

## Description
This building block provides an Azure Key Vault for secure storage and management of secrets, keys, and certificates. It helps application teams protect sensitive data, manage access control, and integrate securely with their applications.

## Usage Motivation
This building block is for application teams that need a secure and scalable solution to store and manage secrets, encryption keys, and certificates. Azure Key Vault ensures compliance with security best practices and helps prevent accidental exposure of sensitive credentials.

## Usage Examples
- A development team stores API keys and database credentials in Azure Key Vault instead of hardcoding them in application code.
- A DevOps team manages TLS certificates in Key Vault and integrates them with Azure Application Gateway for secure HTTPS communication.

## Shared Responsibility

| Responsibility          | Platform Team | Application Team |
|------------------------|--------------|----------------|
| Provisioning and configuring Key Vault | ✅ | ❌ |
| Enforcing security policies (e.g., access control, logging) | ✅ | ❌ |
| Managing access policies and permissions | ❌ | ✅ |
| Storing and retrieving secrets, keys, and certificates | ❌ | ✅ |
| Rotating and managing secrets lifecycle | ❌ | ✅ |
| Integrating Key Vault with applications and services | ❌ | ✅ |

## Recommendations for Secure and Efficient Key Vault Usage
- **Use Azure RBAC or Key Vault access policies**: Grant least-privilege access to teams and services.
- **Enable logging and monitoring**: Use Azure Monitor and diagnostic logs to track access and modifications.
- **Automate secret rotation**: Regularly update secrets to enhance security and avoid expiration risks.
- **Restrict network access**: Use private endpoints or service endpoints to limit exposure.
- **Use managed identities**: Integrate with Azure services securely without exposing credentials.
