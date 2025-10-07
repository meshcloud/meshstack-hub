# StackIt Project

## Description
This building block creates a new StackIt project and manages user access permissions. It provides application teams with a secure, isolated environment for deploying their workloads while ensuring proper access controls.

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
| Managing service accounts | ❌ | ✅ |

## Recommendations for Secure and Efficient Project Usage
- **Use descriptive project names**: Follow organizational naming conventions for easy identification.
- **Apply appropriate labels**: Use labels for cost tracking, environment identification, and network area placement.
- **Grant least privilege access**: Assign users the minimum permissions they need (reader < user < admin).
- **Regular access reviews**: Periodically review and update user permissions as team composition changes.
- **Service account management**: Create service accounts only when needed for automation and CI/CD pipelines.
- **Network area planning**: Choose appropriate network areas based on compliance and connectivity requirements.

## Configuration Options

### Required Parameters
- `parent_container_id`: Organization or folder ID where the project will be created (used as default if no environment is specified)
- `project_name`: Human-readable name for the project
- `owner_email`: Email of the project owner

### Optional Parameters
- `environment`: Environment type (production, staging, development) to automatically select the appropriate parent container
- `parent_container_ids`: Map of environment names to their corresponding parent container IDs
- `labels`: Key-value pairs for project organization and filtering
- `users`: List of users from the authoritative system with their roles
- `create_service_account`: Whether to create an automation service account
- `service_account_name`: Name for the service account (if created)

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
    roles          = ["admin"]  # Can be ["admin"], ["user"], or ["reader"]
  }
]
```

### User Roles
Users can be assigned one or more roles from the authoritative system:
- **admin**: Full project access (equivalent to StackIt owner role)
- **user**: Can modify resources (equivalent to StackIt editor role)
- **reader**: Read-only access (equivalent to StackIt viewer role)

**Note**: If a user has multiple roles, the highest privilege role takes precedence (admin > user > reader).

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