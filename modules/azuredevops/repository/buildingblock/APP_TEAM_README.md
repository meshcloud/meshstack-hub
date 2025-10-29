# Azure DevOps Git Repository

Create and manage your team's Git repositories in Azure DevOps with built-in best practices for code review and collaboration.

## 🚀 Usage Examples

### Basic Repository

```hcl
module "my_app_repo" {
  source = "./buildingblock"

  azure_devops_organization_url = "https://dev.azure.com/myorg"
  key_vault_name                = "kv-azdo-prod"
  resource_group_name           = "rg-azdo-prod"

  project_id      = "12345678-1234-1234-1234-123456789012"
  repository_name = "my-application"
}
```

### Repository with Custom Branch Policies

```hcl
module "my_app_repo" {
  source = "./buildingblock"

  azure_devops_organization_url = "https://dev.azure.com/myorg"
  key_vault_name                = "kv-azdo-prod"
  resource_group_name           = "rg-azdo-prod"

  project_id      = "12345678-1234-1234-1234-123456789012"
  repository_name = "production-app"

  enable_branch_policies = true
  minimum_reviewers      = 3
}
```

### Uninitialized Repository

```hcl
module "empty_repo" {
  source = "./buildingblock"

  azure_devops_organization_url = "https://dev.azure.com/myorg"
  key_vault_name                = "kv-azdo-prod"
  resource_group_name           = "rg-azdo-prod"

  project_id      = "12345678-1234-1234-1234-123456789012"
  repository_name = "new-project"

  init_type              = "Uninitialized"
  enable_branch_policies = false
}
```

## 🔄 Shared Responsibility Matrix

| Task | Platform Team | App Team |
|------|--------------|----------|
| Deploy backplane infrastructure | ✅ | ❌ |
| Store Azure DevOps PAT in Key Vault | ✅ | ❌ |
| Create Azure DevOps project | ✅ | ❌ |
| Create repository | ✅ (via Terraform) | ❌ |
| Configure branch policies | ✅ (via Terraform) | ❌ |
| Push code to repository | ❌ | ✅ |
| Create branches | ❌ | ✅ |
| Submit pull requests | ❌ | ✅ |
| Review code | ❌ | ✅ |
| Manage repository settings | ✅ | ⚠️ (Limited) |
| Rotate Azure DevOps PAT | ✅ | ❌ |

## 💡 Best Practices

### Branch Protection

**Why**: Branch protection policies ensure code quality and prevent accidental changes to critical branches.

**Recommended Settings**:
- Enable branch policies for production repositories
- Require at least 2 reviewers for critical applications
- Ensure work items are linked to track changes

**Example**:
```hcl
enable_branch_policies = true
minimum_reviewers      = 2
```

### Repository Naming

**Why**: Consistent naming makes repositories easy to find and understand.

**Recommended Patterns**:
- Use lowercase with hyphens: `my-app-name`
- Include component type: `frontend-webapp`, `backend-api`
- Avoid special characters and spaces

**Examples**:
- ✅ `customer-portal-frontend`
- ✅ `payment-service-api`
- ❌ `CustomerPortal_Frontend`
- ❌ `Payment Service`

### Repository Initialization

**When to Use Clean**:
- Starting a new project from scratch
- Want an initial commit with README

**When to Use Uninitialized**:
- Migrating code from another repository manually
- Need complete control over the initial commit
- Using external tools for repository setup

### Clone URLs

After repository creation, you'll receive multiple URLs:

**HTTPS URL** (Recommended for CI/CD):
```bash
git clone https://dev.azure.com/myorg/myproject/_git/my-repo
```

**SSH URL** (Recommended for developers):
```bash
git clone git@ssh.dev.azure.com:v3/myorg/myproject/my-repo
```

### Working with Branch Policies

If branch policies are enabled:

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/my-new-feature
   ```

2. **Make changes and commit**:
   ```bash
   git add .
   git commit -m "Add new feature"
   git push origin feature/my-new-feature
   ```

3. **Create a pull request** via Azure DevOps web UI

4. **Wait for reviews** from the required number of reviewers

5. **Link work items** to satisfy policy requirements

6. **Complete PR** once all policies are satisfied

### Common Configuration Patterns

**Development Repositories** (Less strict):
```hcl
enable_branch_policies = false
```

**Staging/UAT Repositories** (Moderate):
```hcl
enable_branch_policies = true
minimum_reviewers      = 1
```

**Production Repositories** (Strict):
```hcl
enable_branch_policies = true
minimum_reviewers      = 2
```

## 🔍 Getting Repository Information

After deployment, access repository information via outputs:

```hcl
output "clone_url" {
  value = module.my_app_repo.repository_url
}

output "web_interface" {
  value = module.my_app_repo.web_url
}
```

## ⚠️ Important Notes

- Repository names must be unique within a project
- Branch policies apply only to the default branch
- Changing initialization type after creation has no effect
- Deleting the Terraform resource will delete the repository and all its contents
- Repository deletion cannot be undone - ensure backups exist

## 🆘 Troubleshooting

### Cannot push to repository

**Cause**: Branch policies are enabled and you're pushing to the default branch

**Solution**: Create a feature branch and submit a pull request instead

### "Repository already exists" error

**Cause**: Repository name conflicts with existing repository in the project

**Solution**: Choose a different repository name or delete the existing repository

### Access denied when cloning

**Cause**: Missing permissions or expired PAT

**Solution**: Verify you have at least Reader access to the project and PAT is valid

## 📚 Related Documentation

- [Azure DevOps Git Documentation](https://learn.microsoft.com/en-us/azure/devops/repos/git/)
- [Branch Policies Overview](https://learn.microsoft.com/en-us/azure/devops/repos/git/branch-policies)
- [Pull Request Best Practices](https://learn.microsoft.com/en-us/azure/devops/repos/git/pull-requests)
