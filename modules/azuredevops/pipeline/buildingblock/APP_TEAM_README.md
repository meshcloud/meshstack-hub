# Azure DevOps Pipeline

Create and manage CI/CD pipelines in Azure DevOps to automate your build, test, and deployment processes.

## 🔄 Shared Responsibility Matrix

| Task | Platform Team | App Team |
|------|--------------|----------|
| Deploy backplane infrastructure | ✅ | ❌ |
| Store Azure DevOps PAT in Key Vault | ✅ | ❌ |
| Create Azure DevOps project | ✅ | ❌ |
| Create repository | ✅ | ❌ |
| Create pipeline (via Terraform) | ✅ | ❌ |
| Write YAML pipeline definition | ❌ | ✅ |
| Commit pipeline YAML to repository | ❌ | ✅ |
| Run pipelines | ❌ | ✅ |
| View pipeline results | ❌ | ✅ |
| Create variable groups | ✅ | ⚠️ (With permissions) |
| Modify pipeline settings | ⚠️ (Via Terraform) | ⚠️ (Limited) |
| Rotate Azure DevOps PAT | ✅ | ❌ |

## 💡 Best Practices

### Pipeline YAML Location

**Why**: Consistent YAML file location makes pipelines predictable and easy to find.

**Recommended Locations**:
- Root: `azure-pipelines.yml` (default)
- Dedicated folder: `ci/azure-pipelines.yml`
- Environment-specific: `pipelines/production.yml`

**Examples**:
- ✅ `azure-pipelines.yml`
- ✅ `ci/build-and-test.yml`
- ✅ `pipelines/deploy-prod.yml`
- ❌ `random/location/pipe.yml`

### Pipeline Naming

**Why**: Clear names help identify purpose and environment at a glance.

**Recommended Patterns**:
- Include app name: `myapp-ci-cd`
- Include environment: `myapp-production-deploy`
- Include purpose: `myapp-build-test`

**Examples**:
- ✅ `customer-portal-ci`
- ✅ `payment-api-production`
- ✅ `frontend-build-test`
- ❌ `pipeline1`
- ❌ `new-pipeline`

### Secret Management

**Why**: Protect sensitive data and credentials from exposure.

**Best Practices**:
- Use `is_secret = true` for sensitive variables
- Link variable groups for shared secrets
- Never commit secrets to YAML files
- Rotate secrets regularly

**Example**:
```hcl
pipeline_variables = [
  {
    name      = "api_key"
    value     = "secret-value"
    is_secret = true
  }
]
```

### Variable Groups

**Why**: Share common variables across multiple pipelines efficiently.

**When to Use Variable Groups**:
- Shared configuration (API endpoints, service URLs)
- Environment-specific settings
- Shared secrets (connection strings, credentials)

**Example**:
```hcl
variable_group_ids = [10, 20]  # Shared config + secrets
```

### Branch Configuration

**Default Branch Patterns**:
- Main branch: `refs/heads/main` (default)
- Development: `refs/heads/develop`
- Release: `refs/heads/release/*`

**Example**:
```hcl
branch_name = "refs/heads/main"
```

### Multi-Environment Setup

**Pattern**: Create separate pipelines for each environment

```hcl
module "dev_pipeline" {
  source        = "./buildingblock"
  pipeline_name = "myapp-dev"
  yaml_path     = "pipelines/dev.yml"
  # ... dev configuration
}

module "prod_pipeline" {
  source        = "./buildingblock"
  pipeline_name = "myapp-prod"
  yaml_path     = "pipelines/prod.yml"
  # ... prod configuration
}
```

## 📝 Creating Your Pipeline YAML

Your repository must contain a YAML file at the specified path. Here's a starter template:

### Basic Build Pipeline

```yaml
# azure-pipelines.yml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

steps:
  - task: NodeTool@0
    inputs:
      versionSpec: '18.x'
    displayName: 'Install Node.js'

  - script: npm install
    displayName: 'Install dependencies'

  - script: npm run build
    displayName: 'Build application'

  - script: npm test
    displayName: 'Run tests'
```

### Pipeline with Variables

```yaml
trigger:
  - main

variables:
  - name: buildConfiguration
    value: 'Release'

pool:
  vmImage: 'ubuntu-latest'

steps:
  - script: echo Building in $(buildConfiguration) mode
    displayName: 'Show configuration'

  - script: dotnet build --configuration $(buildConfiguration)
    displayName: 'Build project'
```

### Multi-Stage Pipeline

```yaml
trigger:
  - main

stages:
  - stage: Build
    jobs:
      - job: BuildJob
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - script: npm install
          - script: npm run build

  - stage: Test
    jobs:
      - job: TestJob
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - script: npm test

  - stage: Deploy
    jobs:
      - job: DeployJob
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - script: echo Deploying application
```

## 🔍 Using Pipeline Variables in YAML

Access Terraform-defined variables in your YAML:

```yaml
steps:
  - script: echo Environment is $(environment)
    displayName: 'Show environment'

  - script: echo Deploying to $(api_endpoint)
    displayName: 'Deploy to endpoint'
```

## 🏃 Running Your Pipeline

After pipeline creation:

1. **Automatic Triggers**: Pipeline runs automatically on commits to configured branch
2. **Manual Runs**: Trigger from Azure DevOps web UI
3. **View Results**: Check Azure DevOps Pipelines section

### Manual Pipeline Run

1. Navigate to Azure DevOps project
2. Go to **Pipelines**
3. Select your pipeline
4. Click **Run pipeline**
5. (Optional) Override variables
6. Click **Run**

## ⚠️ Important Notes

- YAML file must exist in repository before creating pipeline
- Pipeline triggers based on YAML configuration, not Terraform
- Deleting the Terraform resource deletes the pipeline (but not run history)
- Variable group IDs must reference existing variable groups
- Secret variables are masked in logs but can be accessed in pipeline tasks

## 🆘 Troubleshooting

### "YAML file not found" error

**Cause**: YAML file doesn't exist at specified path in repository

**Solution**: Commit YAML file to repository first, then create pipeline

```bash
# Create and commit YAML file
echo "trigger: [main]" > azure-pipelines.yml
git add azure-pipelines.yml
git commit -m "Add pipeline YAML"
git push
```

### Pipeline not triggering on commits

**Cause**: Trigger configuration in YAML file

**Solution**: Check YAML trigger configuration:

```yaml
trigger:
  - main  # Enable CI trigger
```

### "Variable group not found" error

**Cause**: Variable group ID doesn't exist or no permissions

**Solution**:
1. Verify variable group exists in project
2. Check variable group ID is correct
3. Ensure permissions to link variable groups

### Secret variables not working

**Cause**: Secrets must be explicitly mapped in YAML

**Solution**: Map secrets in your YAML:

```yaml
steps:
  - script: echo $(api_key)
    env:
      API_KEY: $(api_key)  # Map the secret variable
```

### GitHub repository authentication fails

**Cause**: Missing service connection

**Solution**: Create GitHub service connection in Azure DevOps first

## 📚 Related Documentation

- [Azure Pipelines YAML Schema](https://learn.microsoft.com/en-us/azure/devops/pipelines/yaml-schema/)
- [Pipeline Triggers](https://learn.microsoft.com/en-us/azure/devops/pipelines/build/triggers)
- [Variable Groups](https://learn.microsoft.com/en-us/azure/devops/pipelines/library/variable-groups)
- [Pipeline Variables](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/variables)
