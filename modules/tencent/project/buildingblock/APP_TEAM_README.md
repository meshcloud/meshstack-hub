# Tencent Cloud Project

## Description
This building block creates a new Tencent Cloud project and manages user access permissions. It provides application teams with a secure, isolated environment for deploying their workloads while ensuring proper access controls through CAM (Cloud Access Management).

## Usage Motivation
This building block is designed for application teams that need to:
- Create isolated Tencent Cloud projects for their applications
- Manage team access with appropriate permission levels
- Ensure compliance with organizational security policies
- Automate project setup and user onboarding

## Usage Examples
- A development team creates a project for their microservices architecture with different access levels for developers, operators, and auditors.
- A platform team provisions projects for multiple application teams with consistent access patterns.

## Shared Responsibility

| Responsibility          | Platform Team | Application Team |
|------------------------|--------------|----------------|
| Provisioning and configuring projects | Yes | No |
| Managing user access and permissions | No | Yes |
| Defining project naming conventions | Yes | No |
| Monitoring project usage and costs | Yes | No |

## Recommendations for Secure and Efficient Project Usage
- **Use descriptive project names**: Follow organizational naming conventions for easy identification.
- **Grant least privilege access**: Assign users the minimum permissions they need (reader < user < admin).
- **Regular access reviews**: Periodically review and update user permissions as team composition changes.

## Configuration Options

### Required Parameters
- `project_name`: Human-readable name for the project

### Optional Parameters
- `users`: List of users from the authoritative system with their roles

### User Roles
- **admin**: Full project access (all actions on all resources in the project)
- **user**: Operational access (manage CVM, VPC, CLB, COS, CBS, CDB, Redis, TKE, SCF, monitoring, tags)
- **reader**: Read-only access (Describe/Get/List actions only)

**Note**: If a user has multiple roles, the highest privilege role takes precedence (admin > user > reader).
