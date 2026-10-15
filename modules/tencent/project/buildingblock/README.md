---
name: Tencent Cloud Project
supportedPlatforms:
  - tencentcloud
description: Creates a new Tencent Cloud project and manages user access permissions with role-based access control via CAM.
---

# Tencent Cloud Project Building Block

This Terraform module provisions a Tencent Cloud project with CAM-based user access control.

## Features

- **Project Creation**: Creates a Tencent Cloud project as a billing and resource boundary
- **CAM Groups**: Three groups with different access levels (readers, users, admins)
- **CAM Policies**: Granular permissions scoped to the project for each group
- **User Management**: Assigns users to groups based on their meshStack roles

## Access Levels

### Admins
- Full access to all resources in the project

### Users
- Manage CVM, VPC, CLB, COS, CBS, CDB, Redis, TKE, SCF instances
- Full monitoring and tag access

### Readers
- Read-only (Describe/Get/List) access to all resources in the project

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| tencentcloud | >= 1.81.0 |

## Resources

| Name | Type |
|------|------|
| tencentcloud_project.project | resource |
| tencentcloud_cam_group.admins | resource |
| tencentcloud_cam_group.users | resource |
| tencentcloud_cam_group.readers | resource |
| tencentcloud_cam_policy.admin_policy | resource |
| tencentcloud_cam_policy.user_policy | resource |
| tencentcloud_cam_policy.reader_policy | resource |
| tencentcloud_cam_group_policy_attachment.admin_policy | resource |
| tencentcloud_cam_group_policy_attachment.user_policy | resource |
| tencentcloud_cam_group_policy_attachment.reader_policy | resource |
| tencentcloud_cam_group_membership.admins | resource |
| tencentcloud_cam_group_membership.users | resource |
| tencentcloud_cam_group_membership.readers | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | The name of the Tencent Cloud project to create | `string` | n/a | yes |
| users | List of users from authoritative system | `list(object)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| project_id | The ID of the created Tencent Cloud project |
| project_name | The name of the created Tencent Cloud project |
| console_url | Deep link URL to the project in the Tencent Cloud console |
| admin_group_id | The ID of the admin CAM group |
| user_group_id | The ID of the user CAM group |
| reader_group_id | The ID of the reader CAM group |
