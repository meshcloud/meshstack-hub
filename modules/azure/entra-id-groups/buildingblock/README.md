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

Set `target_type = "WORKSPACE_LEVEL"` in the integration to offer it as a workspace building block instead: it then creates a single group `<prefix>.<workspace>` holding every workspace member, whatever their workspace role.

## Purpose-specific groups

Set `groups` in the integration when every workspace or project needs groups of your own design. One building block then creates all of them, and each group only takes the members holding one of its roles:

```hcl
target_type = "WORKSPACE_LEVEL"
groups = {
  finops_admin  = { name = "{workspace}.cldy-finops.admin", roles = ["Workspace Owner", "Workspace Manager"] }
  service_admin = { name = "{workspace}.service.admin", roles = ["Workspace Owner"] }
}
```

- `{workspace}` and `{project}` in a name are replaced by the identifiers of the building block's workspace and project. Every name must contain `{workspace}`, and with `TENANT_LEVEL` also `{project}`.
- `roles` are workspace role names (`Workspace Owner`, `Workspace Manager`, `Workspace Member`) or project role identifiers (such as `admin`). Leave `roles` out to add every member.
- Application teams no longer set a prefix or project roles: the platform team owns the names.
- Adding a group creates a new definition version. Existing building blocks get the group when they are upgraded to it.
- The key, such as `finops_admin`, identifies the group. Change `name` to rename a group in place. Changing the key deletes the group and creates a new one with another object ID, which loses every role assignment made to the old one.

## Usage examples

**Default meshStack roles (admin / user / reader):**

A project `my-project` in workspace `my-workspace` with prefix `plat` produces three groups:
- `plat.my-workspace.my-project.admin`
- `plat.my-workspace.my-project.user`
- `plat.my-workspace.my-project.reader`

**Custom roles:**

Set *Project Roles* to `devops,qa,readonly` to create:
- `plat.my-workspace.my-project.devops`
- `plat.my-workspace.my-project.qa`
- `plat.my-workspace.my-project.readonly`

**With Administrative Unit:**

Provide the object ID of an existing Entra Administrative Unit. All generated groups are added as members of that AU, restricting who can manage them in the directory.

## Members that cannot be resolved

Project members are matched to directory users by the attribute your platform team configured — the SMTP address by default. A member with no object in the directory, such as an external collaborator or a service account, is skipped rather than failing the deployment: the groups are still created and every other member is still assigned. The run summary names anyone who was skipped, and the *Unresolved Members* output lists them so you can act on it.

Such a member keeps their meshStack project roles, but they will not inherit any access granted through these groups until they exist in the directory.

## Shared Responsibilities

| Responsibility | Platform Team | Application Team |
|---|:---:|:---:|
| Deploy and configure the backplane identity | ✅ | ❌ |
| Define the group naming convention | ✅ | ❌ |
| Create and delete Entra groups | ✅ | ❌ |
| Add the Administrative Unit (optional) | ✅ | ❌ |
| Choose which project roles get groups | ❌ | ✅ |
| Assign users to the generated groups | ❌ | ✅ |
| Use group IDs in downstream RBAC assignments | ❌ | ✅ |
