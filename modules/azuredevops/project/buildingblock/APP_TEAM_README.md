# 🚀 Azure DevOps Project Building Block

Create and manage Azure DevOps projects with automatic user licensing and role-based access control.

## ✨ What You Get

- **New Azure DevOps Project** with your chosen configuration
- **Automatic User Licensing** with Stakeholder licenses for cost-effective access
- **Role-Based Groups** organizing users by their responsibilities
- **Secure Authentication** through Azure Key Vault managed credentials

## 🎯 Quick Start

```hcl
module "my_devops_project" {
  source = "path/to/azuredevops/project/buildingblock"
  
  # Basic project setup
  project_name = "amazing-product"
  
  # Add your team members
  users = [
    {
      principal_name = "developer@company.com"
      role          = "contributor"
      license_type  = "stakeholder"  # Cost-effective!
    },
    {
      principal_name = "manager@company.com"
      role          = "administrator" 
      license_type  = "basic"
    }
  ]
}
```

## 👥 User Roles Explained

| Role | What They Can Do | Best For |
|------|-----------------|----------|
| **Reader** | View project items, browse code | Stakeholders, managers |
| **Contributor** | Create work items, contribute code, run builds | Developers, testers |
| **Administrator** | Full project control, manage users | Project leads, DevOps engineers |

## 💰 License Types

| License | Cost | Features | Recommended For |
|---------|------|----------|----------------|
| **Stakeholder** | FREE | Basic work item access, limited features | Most users, viewers, managers |
| **Basic** | Paid | Full development features | Active developers |
| **Advanced** | Premium | Testing tools, advanced analytics | Test managers, analysts |

💡 **Tip**: Start with Stakeholder licenses for most users - you can always upgrade later!

## 🔄 Shared Responsibility Matrix

| Task | Your Responsibility | Building Block Handles |
|------|-------------------|----------------------|
| **User Accounts** | Create users in Azure AD | Assign licenses & project access |
| **PAT Token** | Create & store in Key Vault | Retrieve & use for authentication |
| **Project Config** | Define requirements | Create project with settings |
| **Team Structure** | Define user roles | Organize into appropriate groups |
| **Ongoing Management** | Update user lists | Apply changes automatically |

## 💡 Best Practices

### 🏗️ Project Setup
- Use descriptive project names (e.g., `mobile-app-frontend` not `project1`)
- Start with `private` visibility for security
- Choose `Agile` work item template for flexibility

### 👤 User Management
- **Start Small**: Begin with Stakeholder licenses for most users
- **Review Regularly**: Audit user access quarterly
- **Use Groups**: Leverage role-based groups instead of individual permissions

### 🔐 Security
- **Rotate PAT Tokens**: Update tokens every 6 months minimum
- **Principle of Least Privilege**: Give users minimum required access
- **Monitor Access**: Regular review of user permissions

### 💸 Cost Optimization
- **Stakeholder First**: Use free Stakeholder licenses when possible
- **License Hygiene**: Remove unused user entitlements
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