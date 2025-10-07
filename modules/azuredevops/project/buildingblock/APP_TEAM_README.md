# 🚀 Azure DevOps Project Building Block

Create and manage Azure DevOps projects with automatic user licensing and role-based access control.

## ✨ What You Get

- **New Azure DevOps Project** with your chosen configuration
- **User Assignment** from authoritative system to appropriate groups
- **Role-Based Groups** mapping user roles to Azure DevOps project groups
- **Secure Authentication** through Azure Key Vault managed credentials

## 🎯 Quick Start

```hcl
module "my_devops_project" {
  source = "path/to/azuredevops/project/buildingblock"

  # Basic project setup
  project_name = "amazing-product"

   # Users provided by authoritative system
   users = [
     {
       meshIdentifier = "dev-001"
       username       = "developer"
       firstName      = "John"
       lastName       = "Developer"
       email          = "developer@company.com"
       euid           = "john.developer"
       roles          = ["user"]
     },
     {
       meshIdentifier = "mgr-001"
       username       = "manager"
       firstName      = "Jane"
       lastName       = "Manager"
       email          = "manager@company.com"
       euid           = "jane.manager"
       roles          = ["admin", "reader"]
     }
   ]
}
```

## 👥 User Roles Explained

| Role in User.roles | Azure DevOps Group | What They Can Do | Best For |
|--------------------|------------------|-----------------|----------|
| **reader** | Readers | View project items, browse code | Stakeholders, managers |
| **user** | Contributors | Create work items, contribute code, run builds | Developers, testers |
| **admin** | Project Administrators | Full project control, manage users | Project leads, DevOps engineers |

## 🔐 License Management

User licenses are managed externally by the authoritative system. This module focuses on assigning users to the appropriate Azure DevOps project groups based on their roles.

## 🔄 Shared Responsibility Matrix

| Task | Your Responsibility | Building Block Handles |
|------|-------------------|----------------------|
| **User Accounts** | Create users in Azure AD | ✅ Authoritative system manages | - |
| **User Licenses** | - | ✅ Authoritative system assigns | - |
| **User Roles** | - | ✅ Authoritative system defines | Map roles to Azure DevOps groups |
| **PAT Token** | Create & store in Key Vault | - | Retrieve & use for authentication |
| **Project Config** | Define requirements | - | Create project with settings |
| **Team Structure** | - | Provide user data with roles | Apply group memberships |
| **Ongoing Management** | Update user lists | Update user data | Apply changes automatically |

## 💡 Best Practices

### 🏗️ Project Setup
- Use descriptive project names (e.g., `mobile-app-frontend` not `project1`)
- Start with `private` visibility for security
- Choose `Agile` work item template for flexibility

### 👤 User Management
- **Role Assignment**: Ensure users have appropriate roles in the authoritative system
- **Review Regularly**: Audit user access and roles quarterly
- **Group Mapping**: Users are automatically assigned to Azure DevOps groups based on their roles

### 🔐 Security
- **Rotate PAT Tokens**: Update tokens every 6 months minimum
- **Principle of Least Privilege**: Give users minimum required access
- **Monitor Access**: Regular review of user permissions

### 💸 Cost Optimization
- **License Management**: Coordinate with authoritative system for license optimization
- **Role Hygiene**: Ensure users only have necessary roles
- **Feature Control**: Disable unused project features

## 🚨 Important Notes

⚠️ **User Accounts Required**: Users must exist in your Azure AD before running this module.

⚠️ **Organization Permissions**: You need organization-level permissions to assign licenses.

⚠️ **PAT Scopes**: Ensure your Personal Access Token has the required scopes:
- Project & Team (Read, Write, & Manage)
- Member Entitlement Management (Read & Write)

## 📝 Common Scenarios

### Scenario 1: Development Team
```hcl
users = [
  {
    principal_name = "lead@company.com"
    role          = "administrator"
    license_type  = "basic"
  },
  {
    principal_name = "dev1@company.com"
    role          = "contributor"
    license_type  = "basic"
  },
  {
    principal_name = "dev2@company.com"
    role          = "contributor"
    license_type  = "basic"
  }
]
```

### Scenario 2: Mixed Team with Stakeholders
```hcl
users = [
  {
    principal_name = "manager@company.com"
    role          = "reader"
    license_type  = "stakeholder"  # Free!
  },
  {
    principal_name = "developer@company.com"
    role          = "contributor"
    license_type  = "basic"
  },
  {
    principal_name = "stakeholder@company.com"
    role          = "reader"
    license_type  = "stakeholder"  # Free!
  }
]
```

### Scenario 3: Minimal Features Project
```hcl
project_features = {
  testplans = "disabled"  # Save costs
  artifacts = "disabled"  # Not needed yet
}
```

## 🔧 Troubleshooting

### "User not found" Error
1. ✅ Check user exists in Azure AD
2. ✅ Verify email address is correct
3. ✅ Ensure user is invited to Azure DevOps org

### License Assignment Failed
1. ✅ Verify PAT has Member Entitlement permissions
2. ✅ Check available licenses in organization
3. ✅ Confirm organization-level access rights

### Access Denied
1. ✅ Verify PAT scopes are correct
2. ✅ Check Key Vault access permissions
3. ✅ Ensure PAT hasn't expired

## 🎉 Success!

Once deployed, your team will have:
- ✅ A fully configured Azure DevOps project
- ✅ Users with appropriate licenses and access
- ✅ Organized role-based security groups
- ✅ Ready-to-use development environment

Visit your project at: `https://dev.azure.com/yourorg/yourproject`