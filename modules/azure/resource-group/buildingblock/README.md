---
name: Azure Resource Group
supportedPlatforms:
  - azure
description: Creates an empty Azure Resource Group for a project with a consistent naming convention enforced across all landing zones.
---

# Azure Resource Group

This building block provisions an empty **Azure Resource Group** in a target Azure subscription.
The resource group name is automatically derived from the meshStack context following the schema:

```
rg-<workspaceIdentifier>-<projectIdentifier>
```

## Inputs

| Name | Description | Default |
| ---- | ----------- | ------- |
| `subscription_id` | The Azure subscription ID where the resource group will be created. | — |
| `workspace_identifier` | The meshStack workspace identifier. Used to generate the resource group name. | — |
| `project_identifier` | The meshStack project identifier. Used to generate the resource group name. | — |
| `location` | The Azure region where the resource group will be created (e.g. `westeurope`, `eastus`). | `westeurope` |

## Outputs

| Name | Description |
| ---- | ----------- |
| `resource_group_name` | The name of the created resource group (e.g. `rg-myworkspace-myproject`). |
| `resource_group_id` | The Azure resource ID of the created resource group. |

## Shared Responsibilities

| Responsibility | Platform Team | Application Team |
| -------------- | :-----------: | :--------------: |
| Set up backplane service principal | ✅ | ❌ |
| Define management group scope | ✅ | ❌ |
| Choose Azure region (location) | ❌ | ✅ |
| Deploy resources into the group | ❌ | ✅ |
