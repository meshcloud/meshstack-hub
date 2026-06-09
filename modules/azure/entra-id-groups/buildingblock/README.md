---
name: Azure Entra ID Groups
supportedPlatforms:
  - azure
description: Creates Entra security groups for meshStack project roles, with optional Administrative Unit membership.
---

Automatically provision Entra ID security groups for every role in a meshStack project. Groups are named consistently using the workspace identifier, project identifier, an optional prefix, and the role name as suffix — giving your teams a predictable, auditable group structure in Azure Active Directory.

## When to use it

Use this building block when you want to:
- Map meshStack project roles (admin, user, reader, or custom roles) to Entra security groups for RBAC assignments in Azure.
- Enforce a standard naming scheme across all projects in your platform.
- Optionally scope groups inside a dedicated Entra Administrative Unit to isolate tenant-level identities from the rest of the directory.

## Usage examples

**Default meshStack roles (admin / user / reader):**

A project `my-project` in workspace `my-workspace` with prefix `plat` produces three groups:
- `plat-my-workspace-my-project-admin`
- `plat-my-workspace-my-project-user`
- `plat-my-workspace-my-project-reader`

**Custom roles:**

Set *Project Roles* to `devops,qa,readonly` to create:
- `plat-my-workspace-my-project-devops`
- `plat-my-workspace-my-project-qa`
- `plat-my-workspace-my-project-readonly`

**With Administrative Unit:**

Provide the object ID of an existing Entra Administrative Unit. All generated groups are added as members of that AU, restricting who can manage them in the directory.

## Shared Responsibilities

| Responsibility | Platform Team | Application Team |
|---|:---:|:---:|
| Deploy and configure the backplane identity | ✅ | ❌ |
| Define the group naming prefix | ✅ | ❌ |
| Create and delete Entra groups | ✅ | ❌ |
| Add the Administrative Unit (optional) | ✅ | ❌ |
| Choose which project roles get groups | ❌ | ✅ |
| Assign users to the generated groups | ❌ | ✅ |
| Use group IDs in downstream RBAC assignments | ❌ | ✅ |
