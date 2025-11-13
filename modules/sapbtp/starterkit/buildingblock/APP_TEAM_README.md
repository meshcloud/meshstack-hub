# SAP BTP Starterkit

## What is it?

The **SAP BTP Starterkit** provides application teams with pre-configured SAP BTP subaccounts for development and production environments. It automates the creation of subaccounts with the necessary entitlements and optional Cloud Foundry configuration, following your organization's best practices.

## When to use it?

This building block is ideal for teams that:

- Want to quickly start developing on SAP BTP without manual setup
- Need separate development and production environments
- Want pre-configured entitlements for common SAP BTP services
- Prefer a streamlined setup with built-in governance and cost separation

## Usage Examples

1. **New Application Development**: A development team can use this starterkit to quickly provision SAP BTP subaccounts with Cloud Foundry, allowing them to deploy Node.js or Java applications immediately with proper dev/prod separation.

2. **Microservices Platform**: A team building microservices can get separate dev/prod environments with the necessary service entitlements (databases, messaging, etc.) already configured and ready to use.

3. **Enterprise Application**: An enterprise team can leverage this to set up compliant SAP BTP environments with proper project isolation, cost tracking, and access management.

## Resources Created

This building block automates the creation of the following resources:

- **Development Project**: You, as the creator, will have Project Admin access
  - **SAP BTP Subaccount (Dev)**: Dedicated development subaccount
    - **Entitlements**: Pre-configured service entitlements
    - **Cloud Foundry** (optional): Cloud Foundry environment with services

- **Production Project**: You, as the creator, will have Project Admin access
  - **SAP BTP Subaccount (Prod)**: Dedicated production subaccount
    - **Entitlements**: Pre-configured service entitlements
    - **Cloud Foundry** (optional): Cloud Foundry environment with services

## Shared Responsibilities

| Responsibility                                      | Platform Team | Application Team |
| --------------------------------------------------- | ------------- | ---------------- |
| Provision SAP BTP global account                    | ✅            | ❌               |
| Create and configure landing zones                  | ✅            | ❌               |
| Set up subaccounts (dev/prod)                       | ✅            | ❌               |
| Assign base entitlements                            | ✅            | ❌               |
| Configure Cloud Foundry environments                | ✅            | ❌               |
| Develop and deploy applications                     | ❌            | ✅               |
| Manage application-specific services                | ❌            | ✅               |
| Request additional entitlements                     | ❌            | ✅               |
| Manage application users and security               | ❌            | ✅               |
| Monitor application performance and costs           | ❌            | ✅               |
| Promote code from dev to prod                       | ❌            | ✅               |

---
