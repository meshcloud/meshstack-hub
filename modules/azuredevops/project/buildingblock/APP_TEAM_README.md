# Azure DevOps Project

This building block creates and manages Azure DevOps projects with automatic user licensing and role-based access control. Users are assigned to appropriate groups based on their roles from the authoritative system.

## 🚀 Usage Examples

- A development team requests a new Azure DevOps project to **manage their application's repositories, pipelines, and work items** in one place.
- A project lead configures user access by **assigning team members appropriate roles** (reader, contributor, administrator) through the authoritative system.
- An organization creates multiple projects to **separate different applications** or teams with independent access control.

## 🔄 Shared Responsibility

| Responsibility | Platform Team | Application Team |
|----------------|---------------|------------------|
| Create Azure DevOps project | ✅ | ❌ |
| Manage user licensing | ✅ | ❌ |
| Assign users to project groups | ✅ | ❌ |
| Define user roles in authoritative system | ❌ | ✅ |
| Use project for development work | ❌ | ✅ |
| Manage project content (repos, pipelines, boards) | ❌ | ✅ |
| Request access changes | ❌ | ✅ |

## 👥 User Roles Explained

| Role in Authoritative System | Azure DevOps Group | What They Can Do | Best For |
|------------------------------|-------------------|------------------|----------|
| **reader** | Readers | View project items, browse code | Stakeholders, managers, auditors |
| **user** | Contributors | Create work items, contribute code, run builds | Developers, testers, engineers |
| **admin** | Project Administrators | Full project control, manage settings | Project leads, DevOps engineers |

## 💡 Best Practices

### Project Setup

**Why**: Well-configured projects improve team collaboration and organization.

**Recommendations**:
- Use descriptive project names (e.g., `mobile-app-frontend` not `project1`)
- Start with `private` visibility for security
- Choose `Agile` work item template for flexibility (or your team's preferred methodology)

### User Management

**Why**: Proper access control protects sensitive code and maintains compliance.

**Best Practices**:
- Ensure users have appropriate roles in the authoritative system
- Review user access and roles quarterly
- Follow principle of least privilege (give minimum required access)
- Users are automatically assigned to Azure DevOps groups based on their roles

### Security

**Why**: Protect your codebase and development environment from unauthorized access.

**Recommendations**:
- PAT tokens should be rotated every 6 months minimum
- Monitor access logs for unusual activity
- Regular audits of user permissions
- Remove access for departing team members promptly

### Cost Optimization

**Why**: Azure DevOps licensing can add up, especially for large teams.

**Tips**:
- Use Stakeholder licenses (free) for users who only need to view/comment
- Ensure users only have necessary roles
- Coordinate with the authoritative system for license optimization
- Disable unused project features to reduce overhead

### Project Features

Common features you can enable or disable:
- **Boards**: Work item tracking, backlogs, sprints
- **Repos**: Git repositories
- **Pipelines**: CI/CD automation
- **Test Plans**: Manual and exploratory testing
- **Artifacts**: Package feeds (NuGet, npm, Maven, etc.)

## 🔐 License Management

User licenses are managed externally by the authoritative system. This building block focuses on assigning users to the appropriate Azure DevOps project groups based on their roles.

**Available License Types**:
- **Stakeholder** (Free): View and comment on work items, limited access
- **Basic**: Full access to repos, pipelines, boards
- **Basic + Test Plans**: Includes Test Plans feature

## 📝 Common Scenarios

### Scenario 1: Development Team

A team with a project lead, several developers, and a manager:
- Project lead: `administrator` role → Project Administrators group
- Developers: `user` role → Contributors group
- Manager: `reader` role → Readers group (Stakeholder license)

### Scenario 2: Mixed Team with Stakeholders

A team with developers and business stakeholders:
- Developers: `user` role with Basic license
- Stakeholders: `reader` role with Stakeholder license (free)
- DevOps engineer: `administrator` role

### Scenario 3: Minimal Features Project

A simple project that only needs repositories and pipelines:
- Disable Test Plans to save costs
- Disable Artifacts if not needed
- Keep Repos and Pipelines enabled

## ⚠️ Important Notes

- User accounts must exist in your Azure AD before assignment
- PAT token must have correct scopes:
  - Project & Team (Read, Write, & Manage)
  - Member Entitlement Management (Read & Write)
- Role changes in the authoritative system automatically update Azure DevOps group memberships
- Removing a user from the authoritative system removes their project access

## 🆘 Troubleshooting

### "User not found" Error

**Cause**: User doesn't exist in Azure AD or email address is incorrect

**Solution**:
1. Verify user exists in Azure AD
2. Check email address is correct
3. Ensure user is invited to Azure DevOps organization

### License Assignment Failed

**Cause**: Insufficient available licenses or missing permissions

**Solution**:
1. Verify PAT has Member Entitlement permissions
2. Check available licenses in organization
3. Confirm organization-level access rights

### Access Denied

**Cause**: PAT expired or insufficient scopes

**Solution**:
1. Verify PAT scopes are correct
2. Check Key Vault access permissions
3. Ensure PAT hasn't expired
4. Contact Platform Team for assistance

### User Has Wrong Permissions

**Cause**: Role mismatch between authoritative system and Azure DevOps

**Solution**:
1. Verify role assignment in authoritative system
2. Wait for synchronization (may take a few minutes)
3. Check Azure DevOps group memberships in project settings

## 🎉 Getting Started

Once your project is deployed:

1. **Access your project**: Navigate to `https://dev.azure.com/yourorg/yourproject`
2. **Verify access**: Ensure all team members can log in and see appropriate features
3. **Create repositories**: Start adding your code repositories
4. **Set up pipelines**: Configure CI/CD for your applications
5. **Configure boards**: Set up work item tracking for your team

## 📚 Related Documentation

- [Azure DevOps Projects Overview](https://learn.microsoft.com/en-us/azure/devops/organizations/projects/)
- [Project Permissions and Access](https://learn.microsoft.com/en-us/azure/devops/organizations/security/permissions)
- [Work with Projects](https://learn.microsoft.com/en-us/azure/devops/organizations/projects/about-projects)
