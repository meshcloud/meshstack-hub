# SAP BTP Subaccount - User Guide

This building block provisions the foundation for your SAP BTP workspace: a subaccount with user role assignments. This is the **core building block** that all other SAP BTP services depend on.

## 🚀 Usage Motivation

This building block creates an isolated SAP BTP subaccount where you and your team can deploy applications and services. It automatically assigns appropriate permissions to team members based on their roles. Think of it as creating a new "workspace" or "project environment" within SAP BTP.

**Important**: This building block only creates the subaccount itself. To add services, applications, or Cloud Foundry environments, use the companion building blocks:
- **Entitlements**: Assign service quotas
- **Subscriptions**: Subscribe to SAP applications
- **Cloud Foundry**: Provision CF environment and service instances
- **Trust Configuration**: Configure custom identity providers

## 💡 Usage Examples

- Create a new project workspace for your development team
- Set up an isolated production environment
- Provision a sandbox environment for experimentation
- Create department-specific subaccounts with proper access controls

## 🎯 Features

**Subaccount Provisioning**: Creates an isolated SAP BTP subaccount in your specified region and optional directory/folder.

**User Role Management**: Automatically assigns users to appropriate role collections:
- **Subaccount Administrator** (for users with `admin` role): Full subaccount management
- **Subaccount Service Administrator** (for users with `user` role): Service instance management
- **Subaccount Viewer** (for users with `reader` role): Read-only access

**Regional Deployment**: Choose from multiple SAP BTP regions (eu10, us10, ap21, etc.)

**Directory Organization**: Optionally place the subaccount in a specific BTP directory/folder for better organization

## 🔄 Shared Responsibility Matrix

| Responsibility                    | Platform Team ✅/❌ | Application Team ✅/❌ |
| --------------------------------- | ------------------- | ---------------------- |
| Subaccount Creation               | ✅                  | ❌                     |
| User Role Assignments             | ✅                  | ❌                     |
| Using the subaccount              | ❌                  | ✅                     |
| Adding services/subscriptions     | ❌                  | ✅ (via other building blocks) |
| Application Development           | ❌                  | ✅                     |
| Cost Management                   | ❌                  | ✅                     |
| Security & Compliance             | ❌                  | ✅                     |

## 🏗️ What's Next?

After your subaccount is created, you can add additional capabilities using these building blocks:

1. **Entitlements** - Assign service quotas for databases, messaging, etc.
2. **Subscriptions** - Subscribe to SAP applications (Build Code, Integration Suite, etc.)
3. **Cloud Foundry** - Set up Cloud Foundry environment with service instances
4. **Trust Configuration** - Integrate custom identity providers (SAP IAS, etc.)

## 📋 Best Practices

- **Naming**: Use clear, descriptive names for your subaccount (this is set via `project_identifier`)
- **Regions**: Choose a region close to your users for better performance
- **Organization**: Use directories/folders to organize subaccounts by environment (dev/test/prod) or department
- **Role Assignment**: Ensure team members have appropriate roles (admin/user/reader) based on their responsibilities
