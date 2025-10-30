# Azure DevOps Pipeline

This building block provides automated CI/CD pipelines in Azure DevOps to streamline your build, test, and deployment processes. Pipelines are configured via meshStack and run based on YAML definitions in your repository.

## 🚀 Usage Examples

- A development team sets up a pipeline to **automatically build and test** their application on every commit to the main branch.
- A DevOps engineer configures a multi-stage pipeline to **deploy to staging and production** environments with approval gates.
- A team creates separate pipelines for different environments (dev, staging, production) with environment-specific variables.

## 🔄 Shared Responsibility

| Responsibility | Platform Team | Application Team |
|----------------|---------------|------------------|
| Create Azure DevOps project | ✅ | ❌ |
| Create repository | ✅ | ❌ |
| Create pipeline configuration | ✅ | ❌ |
| Write YAML pipeline definition | ❌ | ✅ |
| Commit pipeline YAML to repository | ❌ | ✅ |
| Run and monitor pipelines | ❌ | ✅ |
| Manage pipeline variables | ⚠️ | ✅ |
| Troubleshoot pipeline failures | ❌ | ✅ |

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
- Use secret variables for sensitive data
- Link variable groups for shared secrets
- Never commit secrets to YAML files
- Rotate secrets regularly

### Variable Groups

**Why**: Share common variables across multiple pipelines efficiently.

**When to Use Variable Groups**:
- Shared configuration (API endpoints, service URLs)
- Environment-specific settings
- Shared secrets (connection strings, credentials)

### Branch Configuration

**Default Branch Patterns**:
- Main branch: `refs/heads/main` (default)
- Development: `refs/heads/develop`
- Release: `refs/heads/release/*`

## 📝 Creating Your Pipeline YAML

Your repository must contain a YAML file at the specified path. Here's a starter template:

### Basic Build Pipeline

```yaml
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

## 🔍 Using Pipeline Variables

Access configured variables in your YAML:

```yaml
steps:
  - script: echo Environment is $(environment)
    displayName: 'Show environment'

  - script: echo Deploying to $(api_endpoint)
    displayName: 'Deploy to endpoint'
```

For secret variables, map them explicitly:

```yaml
steps:
  - script: echo $(api_key)
    env:
      API_KEY: $(api_key)
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

- YAML file must exist in repository before pipeline is configured
- Pipeline triggers based on YAML configuration
- Variable group IDs must reference existing variable groups
- Secret variables are masked in logs but can be accessed in pipeline tasks

## 🆘 Troubleshooting

### "YAML file not found" error

**Cause**: YAML file doesn't exist at specified path in repository

**Solution**: Commit YAML file to repository first

```bash
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
  - main
```

### Secret variables not working

**Cause**: Secrets must be explicitly mapped in YAML

**Solution**: Map secrets in your YAML:

```yaml
steps:
  - script: echo $(api_key)
    env:
      API_KEY: $(api_key)
```

## 📚 Related Documentation

- [Azure Pipelines YAML Schema](https://learn.microsoft.com/en-us/azure/devops/pipelines/yaml-schema/)
- [Pipeline Triggers](https://learn.microsoft.com/en-us/azure/devops/pipelines/build/triggers)
- [Variable Groups](https://learn.microsoft.com/en-us/azure/devops/pipelines/library/variable-groups)
- [Pipeline Variables](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/variables)
