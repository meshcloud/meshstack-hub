# StackIt Project Building Block

This building block creates and manages StackIt projects with user access control.

## Features

- **Project Creation**: Creates new StackIt projects within specified parent containers
- **User Management**: Assigns users with admin, user, or reader permissions
- **Service Accounts**: Optional creation of service accounts for automation
- **Label Support**: Applies labels for organization and network area placement
- **Experimental IAM**: Uses StackIt's experimental IAM features for role assignments

## Requirements

- StackIt service account with project creation permissions
- Parent container ID (organization or folder)
- Valid user emails for role assignments

## Usage

```hcl
module "stackit_project" {
  source = "./modules/stackit/project/buildingblock"

  parent_container_id = "organization-abc123"
  project_name        = "my-application"
  owner_email         = "project-owner@company.com"

  labels = {
    environment = "production"
    team        = "platform"
    cost-center = "engineering"
  }

  users = [
    {
      email = "admin@company.com"
      role  = "admin"
    },
    {
      email = "developer@company.com"
      role  = "user"
    },
    {
      email = "auditor@company.com"
      role  = "reader"
    }
  ]

  create_service_account = true
  service_account_name   = "ci-cd-automation"
}
```

## Authentication

This building block requires authentication with StackIt. Configure the StackIt provider with:

```hcl
provider "stackit" {
  service_account_key_path = "/path/to/service-account-key.json"
  experiments             = ["iam"]
}
```

## Outputs

- `project_id`: UUID of the created project
- `container_id`: User-friendly container ID
- `project_name`: Project name
- `service_account_email`: Email of created service account (if applicable)

## Testing

Run the included Terraform tests:

```bash
terraform test
```

Tests include both full configuration and minimal setup scenarios.