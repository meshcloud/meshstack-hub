# STACKIT Project – Backplane

This module sets up the shared backplane configuration for the STACKIT Project building block.
It creates a dedicated service account with the permissions required to create and manage
STACKIT projects under a given organization:

- **`resourcemanager.admin`** — allows creating and managing projects within the organization.
- **`authorization.admin`** — allows managing role assignments on created projects (owner, editor, viewer).

## Prerequisites

- A STACKIT project where the service account will be created.
- A STACKIT service account with permissions to manage service accounts and organization-level role assignments.
- The STACKIT organization ID under which projects will be created.

## Usage

```hcl
module "project_backplane" {
  source = "./backplane"

  project_id      = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  organization_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
