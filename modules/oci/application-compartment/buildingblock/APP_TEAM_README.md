# OCI Application Compartment

## Description
This building block creates a new Oracle Cloud Infrastructure (OCI) compartment and manages user access permissions. It provides application teams with a secure, isolated environment for deploying their workloads while ensuring proper access controls through IAM groups and policies.

## Usage Motivation
This building block is designed for application teams that need to:
- Create isolated OCI compartments for their applications
- Manage team access with appropriate permission levels
- Ensure compliance with organizational security policies
- Automate compartment setup and user onboarding
- Deploy workloads in the correct organizational structure based on landing zone and environment

## Usage Examples
- A development team creates a compartment for their microservices architecture with different access levels for developers, operators, and auditors.
- A platform team provisions compartments for multiple application teams with consistent access patterns across different landing zones.
- An organization sets up compartments for different environments (development, QA, test, production) within their cloud-native landing zone.
- A sandbox project gets provisioned with a simplified single-compartment setup for rapid prototyping.

## Shared Responsibility

| Responsibility          | Platform Team | Application Team |
|------------------------|--------------|----------------|
| Provisioning and configuring compartments | ✅ | ❌ |
| Managing user access and permissions | ❌ | ✅ |
| Defining compartment naming conventions | ✅ | ❌ |
| Monitoring compartment usage and costs | ✅ | ❌ |
| Configuring landing zones and parent compartments | ✅ | ❌ |
| Managing resources within the compartment | ❌ | ✅ |

## Recommendations for Secure and Efficient Compartment Usage
- **Follow naming conventions**: Compartment names are automatically generated following organizational patterns.
- **Use appropriate landing zones**: Select the correct landing zone based on your application's security and compliance requirements.
- **Choose the right environment**: Properly tag your project with the correct environment (dev, qa, test, prod) for proper compartment placement.
- **Grant least privilege access**: Assign users the minimum permissions they need (reader < user < admin).
- **Regular access reviews**: Periodically review and update user permissions as team composition changes.
- **Resource organization**: Use the compartment to logically organize your cloud resources.
- **Cost tracking**: Leverage compartments for cost allocation and budgeting.

## Configuration Options

### How Compartment Placement Works

The building block automatically determines where to create your application compartment based on **meshStack project tags**:

1. **Landing Zone Tag**: Determines the overall security/compliance level
2. **Environment Tag**: Determines which environment-specific compartment to use (if applicable)

#### Landing Zone Types

##### Sandbox Landing Zone
- **Purpose**: For experimentation, learning, and rapid prototyping
- **Behavior**: All environments (dev, qa, test, prod) use the **same parent compartment**
- **Use Case**: Quick setup for non-production workloads

##### Cloud-Native Landing Zone
- **Purpose**: For production-ready applications with proper environment separation
- **Behavior**: Each environment gets its **own parent compartment**
  - `dev` → Cloud-Native Dev compartment
  - `qa` → Cloud-Native QA compartment
  - `test` → Cloud-Native Test compartment
  - `prod` → Cloud-Native Prod compartment
- **Use Case**: Production workloads requiring environment isolation

##### Fallback
- If no landing zone tags match, a default parent compartment is used

### User Roles and Permissions

Users can be assigned one or more roles from the authoritative system:

#### Reader Role
- **OCI Permissions**: Read-only access to all resources in the compartment
- **Use Case**: Auditors, stakeholders who need visibility but not modification rights

#### User Role
- **OCI Permissions**: Can manage:
  - Compute instances (instance-family)
  - Virtual networks (virtual-network-family)
  - Block and boot volumes (volume-family)
  - Object storage (object-family)
  - Load balancers
  - Read all resources
- **Use Case**: Developers and operators who need to deploy and manage applications

#### Admin Role
- **OCI Permissions**: Full management access to all resources in the compartment
- **Use Case**: Team leads, DevOps engineers who need complete control

**Note**: If a user has multiple roles, the highest privilege role takes precedence (admin > user > reader).

#### Example Scenarios

| Landing Zone Tag | Environment Tag | Result |
|-----------------|----------------|--------|
| `sandbox` | `dev` | Parent: Sandbox compartment (ignores environment) |
| `sandbox` | `prod` | Parent: Sandbox compartment (ignores environment) |
| `cloud-native` | `dev` | Parent: Cloud-Native Dev compartment |
| `cloud-native` | `prod` | Parent: Cloud-Native Prod compartment |
| No tags | Any | Parent: Default fallback Sandbox compartment |

### Automatic Compartment Naming

Compartments are automatically named following this pattern:
```
{foundation}-{workspace_id}-{project_id}
```

Example: `mycompany-platform-team-ecommerce-api`

The compartment description includes helpful context:
```
Application compartment for {workspace_id}/{project_id} [landing_zone/environment]
```

Example: `Application compartment for platform-team/ecommerce-api [cloud-native/prod]`

## What Gets Created

When you provision this building block, the following resources are created in OCI:

1. **Application Compartment**: A new compartment under the appropriate parent compartment
2. **Three IAM Groups**:
   - `{compartment-name}-readers`: Read-only access group
   - `{compartment-name}-users`: Standard user access group
   - `{compartment-name}-admins`: Administrator access group
3. **Group Memberships**: Automatic assignment of users to groups based on their roles
4. **IAM Policy**: Access policies defining permissions for each group

## Outputs and Access

After provisioning, you'll receive:
- **Compartment OCID**: The unique identifier for your compartment
- **Console URL**: Direct link to access your compartment in the OCI Console
- **Group Information**: Names and OCIDs of the created IAM groups
