# StackIt Project

## Description
This building block creates a new STACKIT project and manages user access permissions with configurable role mapping. It also performs best-effort STACKIT organization onboarding for all assigned users before project permissions are applied. It provides application teams with a secure, isolated environment for deploying their workloads while ensuring proper access controls.

## Usage Motivation
This building block is designed for application teams that need to:
- Create isolated StackIt projects for their applications
- Manage team access with appropriate permission levels
- Ensure compliance with organizational security policies
- Automate project setup and user onboarding

## Usage Examples
- A development team creates a project for their microservices architecture with different access levels for developers, operators, and auditors.
- A platform team provisions projects for multiple application teams with consistent access patterns.
- An organization sets up projects for different environments (development, staging, production) with appropriate user access.

## Shared Responsibility

| Responsibility          | Platform Team | Application Team |
|------------------------|--------------|----------------|
| Provisioning and configuring projects | ✅ | ❌ |
| Managing user access and permissions | ❌ | ✅ |
| Defining project naming conventions | ✅ | ❌ |
| Monitoring project usage and costs | ✅ | ❌ |
| Setting up network areas and labels | ✅ | ❌ |


## Recommendations for Secure and Efficient Project Usage
- **Use descriptive project names**: Follow organizational naming conventions for easy identification.
- **Apply appropriate labels**: Use labels for cost tracking, environment identification, and network area placement.
- **Grant least privilege access**: Assign users the minimum permissions they need by mapping meshStack roles to appropriate STACKIT project roles.
- **Regular access reviews**: Periodically review and update user permissions as team composition changes.

- **Network area planning**: Choose appropriate network areas based on compliance and connectivity requirements.

## Configuration Options

### Required Parameters
- `parent_container_id`: Organization or folder ID where the project will be created (used as default if no environment is specified)
- `project_name`: Human-readable name for the project
- `service_account_email`: Email of the service account that will own this project

### Optional Parameters
- `environment`: Environment type (production, staging, development) to automatically select the appropriate parent container
- `parent_container_ids`: Map of environment names to their corresponding parent container IDs
- `labels`: Key-value pairs for project organization and filtering
- `users`: List of users from the authoritative system with their meshStack roles
- `role_mapping`: Mapping from meshStack roles to STACKIT project roles

### User Structure
Users are provided from the authoritative system with the following structure:
```hcl
users = [
  {
    meshIdentifier = "unique-user-id"
    username       = "user-login"
    firstName      = "John"
    lastName       = "Doe"
    email          = "john.doe@company.com"
    euid           = "john.doe@company.com"
    roles          = ["admin"]  # MeshStack roles used as keys in role_mapping
  }
]
```

### User Roles
Users can be assigned one or more meshStack roles from the authoritative system. The building block maps each meshStack role to one or more STACKIT project roles through `role_mapping`.

Default mapping:
- **admin** → `owner`
- **user** → `editor`
- **reader** → `reader`

Custom mapping example:

```hcl
role_mapping = {
  admin   = ["owner"]
  user    = ["editor", "network.admin"]
  reader  = ["reader"]
  auditor = ["reader", "audit-log.viewer"]
}
```

Unknown meshStack roles are ignored. If a user has multiple meshStack roles, all mapped STACKIT roles are assigned once.

### STACKIT Organization Membership

Before applying project-level role assignments, the building block runs a best-effort pre-run step that adds all assigned meshStack users to the STACKIT organization with the organization role configured by the platform team. The default organization role is `organization.viewer`. The platform team can disable this step entirely; in that case, organization membership must be managed outside this building block.

This onboarding step is apply-only and does not remove organization memberships during destroy because organization membership can be shared by multiple projects. If the onboarding request fails, the building block logs a warning and continues; project-level role assignment remains authoritative and may still fail if STACKIT rejects a user that is not an organization member.

The building block summary lists each user with a status: a checkmark if the required organization role is assigned, or details about what went wrong otherwise (e.g. a failed add request or a role that is still missing). If any user's status is not a checkmark, the summary includes remediation guidance for the platform team.

### Environment-Based Parent Container Selection

The building block supports automatic parent container selection based on environment type:

```hcl
# Example configuration
environment = "production"
parent_container_ids = {
  production  = "organization-prod-123"
  staging     = "organization-staging-456"
  development = "organization-dev-789"
}
```

- If `environment` is set, the corresponding container ID from `parent_container_ids` will be used
- If `environment` is not set or the environment key doesn't exist in `parent_container_ids`, it falls back to `parent_container_id`
- This allows for automatic placement of projects in the correct organizational structure based on environment

### Service Account Owner

The `service_account_email` parameter must be set to the email address of a StackIt service account, not a human user. This service account will be the technical owner of the project and should have the necessary permissions to manage project resources.

**Important**: Service account emails in StackIt typically follow the format: `service-account-name@sa.stackit.cloud`