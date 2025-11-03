# Azure DevOps Git Repository

This building block creates and manages Git repositories in Azure DevOps with built-in best practices for code review and collaboration. Repositories are configured via meshStack with optional branch protection policies.

## 🚀 Usage Examples

- A development team creates a repository to **host their application source code** with automatic branch protection on the main branch.
- A team sets up a repository with **strict code review requirements** (minimum 2 reviewers) for production applications.
- An organization creates multiple repositories to **separate microservices** or components with independent versioning.

## 🔄 Shared Responsibility

| Responsibility | Platform Team | Application Team |
|----------------|---------------|------------------|
| Create Azure DevOps project | ✅ | ❌ |
| Create repository | ✅ | ❌ |
| Configure branch policies | ✅ | ❌ |
| Push code to repository | ❌ | ✅ |
| Create branches | ❌ | ✅ |
| Submit pull requests | ❌ | ✅ |
| Review code | ❌ | ✅ |
| Merge pull requests | ❌ | ✅ |
| Manage repository settings | ⚠️ | ⚠️ |

## 💡 Best Practices

### Repository Naming

**Why**: Consistent naming makes repositories easy to find and understand.

**Recommended Patterns**:
- Use lowercase with hyphens: `my-app-name`
- Include component type: `frontend-webapp`, `backend-api`
- Avoid special characters and spaces

**Examples**:
- ✅ `customer-portal-frontend`
- ✅ `payment-service-api`
- ✅ `shared-components`
- ❌ `CustomerPortal_Frontend`
- ❌ `Payment Service`
- ❌ `repo1`

### Branch Protection

**Why**: Branch protection policies ensure code quality and prevent accidental changes to critical branches.

**When to Enable Branch Policies**:
- ✅ Production repositories
- ✅ Shared libraries and components
- ✅ Any code deployed to customers
- ❌ Personal experimentation repositories
- ❌ Documentation-only repositories

**Recommended Reviewer Settings**:
- Development repositories: No branch policies or 1 reviewer
- Staging/UAT repositories: 1 reviewer minimum
- Production repositories: 2 reviewers minimum

### Repository Initialization

**Clean Init** (Recommended):
- Creates repository with an initial commit and README
- Ready to clone and start working immediately
- Good for new projects starting from scratch

**Uninitialized**:
- Creates empty repository with no initial commit
- Useful when migrating code from another repository
- Requires manual initialization after creation

### Working with Branch Policies

When branch policies are enabled, you cannot push directly to the default branch (usually `main`). Instead:

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

5. **Link work items** to satisfy policy requirements (if configured)

6. **Complete PR** once all policies are satisfied and reviewers approve

### Clone URLs

After repository creation, you'll receive multiple clone URLs:

**HTTPS URL** (Recommended for CI/CD):
```bash
git clone https://dev.azure.com/myorg/myproject/_git/my-repo
```

**SSH URL** (Recommended for developers):
```bash
git clone git@ssh.dev.azure.com:v3/myorg/myproject/my-repo
```

## 🔍 Repository Configuration Patterns

### Development/Sandbox Repository

**Use Case**: Experimentation, learning, proof-of-concepts

**Configuration**:
- No branch policies
- Any team member can push directly
- Fast iteration, minimal process

### Team Collaboration Repository

**Use Case**: Standard application development

**Configuration**:
- Branch policies enabled
- Minimum 1-2 reviewers required
- Work item linking recommended
- Balance between quality and velocity

### Production-Critical Repository

**Use Case**: Customer-facing applications, shared libraries

**Configuration**:
- Branch policies enabled
- Minimum 2 reviewers required
- Work item linking enforced
- Build validation policies
- Maximum code quality standards

## 📝 Getting Started with Your Repository

After repository creation:

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd <repository-name>
   ```

2. **Configure your identity** (if not already done):
   ```bash
   git config user.name "Your Name"
   git config user.email "your.email@company.com"
   ```

3. **Create a feature branch**:
   ```bash
   git checkout -b feature/initial-setup
   ```

4. **Add your code and commit**:
   ```bash
   git add .
   git commit -m "Initial project setup"
   git push origin feature/initial-setup
   ```

5. **Create a pull request** if branch policies are enabled, or push to main if not:
   ```bash
   # If no branch policies:
   git checkout main
   git merge feature/initial-setup
   git push origin main
   ```

## ⚠️ Important Notes

- Repository names must be unique within a project
- Branch policies apply only to the default branch (usually `main`)
- Changing initialization type after creation has no effect
- Repository content is not automatically backed up (use branch policies and review processes for protection)

## 🆘 Troubleshooting

### Cannot push to repository

**Cause**: Branch policies are enabled and you're pushing to the default branch

**Solution**: Create a feature branch and submit a pull request instead

```bash
git checkout -b feature/my-changes
git push origin feature/my-changes
```

### "Repository already exists" error

**Cause**: Repository name conflicts with existing repository in the project

**Solution**: Choose a different repository name or delete the existing repository

### Access denied when cloning

**Cause**: Missing permissions or expired credentials

**Solution**:
1. Verify you have at least Reader access to the project
2. For HTTPS: Check your PAT is valid and has Code (Read) permissions
3. For SSH: Verify your SSH key is added to Azure DevOps

### Pull request cannot be completed

**Cause**: Branch policies not satisfied

**Solution**:
1. Ensure required number of reviewers have approved
2. Link work items if policy requires it
3. Resolve all merge conflicts
4. Wait for any required build validations to pass

### "Branch policy prevents direct push"

**Cause**: Attempting to push directly to protected branch

**Solution**: This is expected behavior. Use feature branches and pull requests:

```bash
# Create and switch to a feature branch
git checkout -b feature/my-work

# Make your changes and push
git add .
git commit -m "My changes"
git push origin feature/my-work

# Then create a PR in Azure DevOps UI
```

## 🎯 Next Steps

After your repository is set up:

1. **Add a README.md** with project information
2. **Set up .gitignore** for your language/framework
3. **Configure branch policies** if needed for quality gates
4. **Create a pipeline** to automate builds and deployments
5. **Invite team members** and assign appropriate permissions
6. **Link work items** to track features and bugs

## 📚 Related Documentation

- [Azure DevOps Git Documentation](https://learn.microsoft.com/en-us/azure/devops/repos/git/)
- [Branch Policies Overview](https://learn.microsoft.com/en-us/azure/devops/repos/git/branch-policies)
- [Pull Request Best Practices](https://learn.microsoft.com/en-us/azure/devops/repos/git/pull-requests)
- [Git Authentication](https://learn.microsoft.com/en-us/azure/devops/repos/git/auth-overview)
