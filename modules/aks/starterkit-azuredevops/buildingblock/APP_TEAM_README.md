# Azure Kubernetes Service (AKS) Starter Kit - Azure DevOps

## What is it?

The **AKS Azure DevOps Starter Kit** provides application teams with a pre-configured Kubernetes environment integrated with Azure DevOps. It automates the creation of essential infrastructure, including an Azure DevOps project, Git repository, CI/CD pipelines, and secure Azure service connections using passwordless authentication.

## When to use it?

This building block is ideal for teams that:

- Want to deploy applications on Kubernetes without manual infrastructure setup
- Use Azure DevOps for version control and CI/CD workflows
- Need separate development and production environments with different deployment processes
- Prefer secure, passwordless authentication with Workload Identity Federation (OIDC)
- Want branch-based deployment automation (main → dev, release → prod)

## Usage Examples

1. **Deploying a microservice**: A developer creates a complete CI/CD pipeline for a new microservice with separate dev/prod pipelines and namespaces
2. **Team onboarding**: New teams get immediate access to a fully configured Azure DevOps project with AKS integration and role-based access
3. **Multi-stage deployment**: Deploy to dev on every commit to main, deploy to prod on release branch merges with additional safeguards

## Resources Created

This building block automates the creation of the following resources:

- **Azure DevOps Project**: A dedicated project for your application with role-based access control
  - **Git Repository**: Initialized with Dockerfile, Kubernetes manifests, and pipeline definitions
  - **Dev Pipeline**: Builds and deploys from `main` branch to development environment
  - **Prod Pipeline**: Builds and deploys from `release` branch to production environment

- **Development Project**: You, as the creator, will have Project Admin access
  - **AKS Namespace**: A dedicated Kubernetes namespace for development
  - **Azure Service Connection**: Connects the pipeline to Azure (auto-authorized for faster iteration)

- **Production Project**: You, as the creator, will have Project Admin access
  - **AKS Namespace**: A dedicated Kubernetes namespace for production
  - **Azure Service Connection**: Connects the pipeline to Azure (manual authorization for security)

## Shared Responsibilities

| Responsibility                               | Platform Team | Application Team |
| -------------------------------------------- | ------------- | ---------------- |
| Provision and manage AKS cluster             | ✅            | ❌               |
| Create Azure DevOps project                  | ✅            | ❌               |
| Set up CI/CD pipelines                       | ✅            | ❌               |
| Configure service connections                | ✅            | ❌               |
| Build and scan Docker images                 | ✅            | ❌               |
| Manage Kubernetes namespaces (dev/prod)      | ✅            | ❌               |
| Manage resources inside namespaces           | ❌            | ✅               |
| Develop and maintain application source code | ❌            | ✅               |
| Maintain pipeline YAML files                 | ❌            | ✅               |
| Merge to release branch for prod deployments | ❌            | ✅               |

---

## Getting Started

### 1. Access Your Azure DevOps Project

After the starter kit is deployed, you'll receive a summary with links to your Azure DevOps project. Navigate to:

```
https://dev.azure.com/<organization>/<project-name>
```

### 2. Clone Your Repository

Clone the Git repository to your local machine:

```bash
git clone https://dev.azure.com/<organization>/<project-name>/_git/<repo-name>
cd <repo-name>
```

### 3. Understand the Branch Strategy

- **main branch**: Development work happens here
  - Commits trigger the **Dev Pipeline**
  - Deploys automatically to the **dev AKS namespace**

- **release branch**: Production releases happen here
  - Commits trigger the **Prod Pipeline**
  - Deploys to the **prod AKS namespace**
  - Requires manual service connection authorization on first run

### 4. Make Your First Deployment

#### Deploy to Development

```bash
# Make changes to your code
git add .
git commit -m "My first change"
git push origin main
```

The Dev Pipeline will automatically:
1. Build your Docker image
2. Run security scans
3. Deploy to your dev AKS namespace
4. Make it available at `https://<app-name>-dev.likvid-k8s.msh.host`

#### Deploy to Production

```bash
# First, ensure your main branch is stable
git checkout release
git merge main
git push origin release
```

The Prod Pipeline will:
1. Pause for service connection authorization (first run only)
2. Build your Docker image
3. Run security scans
4. Deploy to your prod AKS namespace
5. Make it available at `https://<app-name>.likvid-k8s.msh.host`

**First Run Authorization**: When the prod pipeline runs for the first time, it will pause and ask you to authorize the service connection. Click **View** → **Permit** to continue.

---

## Repository Structure

Your repository includes the following files:

```
├── azure-pipelines-dev.yml      # Dev pipeline definition
├── azure-pipelines-prod.yml     # Prod pipeline definition
├── Dockerfile                    # Container image build instructions
├── k8s/
│   ├── deployment.yaml          # Kubernetes deployment manifest
│   ├── service.yaml             # Kubernetes service manifest
│   └── ingress.yaml             # Kubernetes ingress manifest
└── src/
    └── [your application code]
```

---

## Pipeline Variables

Both pipelines have the following variables pre-configured:

| Variable | Description | Example |
|----------|-------------|---------|
| `AKS_NAMESPACE` | Your dedicated Kubernetes namespace | `myapp-dev-abc123` |
| `ENVIRONMENT` | Environment name (development or production) | `development` |
| `SERVICE_CONNECTION` | Azure service connection name | `Azure-AKS-Dev` |
| `DOMAIN_NAME` | Application subdomain | `myapp-dev` |

You can reference these in your pipeline YAML:

```yaml
- script: |
    echo "Deploying to $(AKS_NAMESPACE)"
    echo "Environment: $(ENVIRONMENT)"
```

---

## Customizing Your Pipelines

### Modify Pipeline Steps

Edit `azure-pipelines-dev.yml` or `azure-pipelines-prod.yml` to customize the build and deployment process:

```yaml
trigger:
  branches:
    include:
      - main  # or 'release' for prod

pool:
  vmImage: 'ubuntu-latest'

variables:
  - name: DOCKER_REGISTRY
    value: 'myregistry.azurecr.io'

steps:
  - task: Docker@2
    displayName: 'Build Docker Image'
    inputs:
      command: build
      dockerfile: 'Dockerfile'
      tags: |
        $(Build.BuildId)
        latest

  - task: AzureCLI@2
    displayName: 'Deploy to AKS'
    inputs:
      azureSubscription: $(SERVICE_CONNECTION)
      scriptType: 'bash'
      scriptLocation: 'inlineScript'
      inlineScript: |
        kubectl apply -f k8s/ --namespace=$(AKS_NAMESPACE)
```

### Add Environment Secrets

Store sensitive values in Azure Key Vault and reference them in your pipeline:

1. Go to **Pipelines** → **Library**
2. Create a **Variable Group** linked to Azure Key Vault
3. Reference in pipeline:

```yaml
variables:
  - group: my-secrets

steps:
  - script: |
      echo "Database connection: $(DB_CONNECTION_STRING)"
```

---

## Monitoring Your Deployments

### View Pipeline Runs

Navigate to **Pipelines** in your Azure DevOps project:

- **Dev Pipeline**: Shows all deployments to development
- **Prod Pipeline**: Shows all deployments to production

Each run shows:
- Build logs
- Test results
- Deployment status
- Security scan results

### Access Your Applications

Once deployed, your applications are available at:

- **Dev**: `https://<app-name>-dev.likvid-k8s.msh.host`
- **Prod**: `https://<app-name>.likvid-k8s.msh.host`

### View AKS Namespace Resources

Access your Kubernetes namespaces via meshStack:

1. Navigate to your **Dev Project** or **Prod Project**
2. Click on the **AKS Tenant**
3. Use `kubectl` or the Azure portal to inspect resources

---

## Security Features

### Workload Identity Federation (Passwordless Authentication)

Your service connections use **Workload Identity Federation (OIDC)** for authentication:

✅ **No secrets to manage** - authentication uses short-lived tokens
✅ **Automatic token rotation** - tokens expire quickly and are refreshed automatically
✅ **Zero maintenance** - no manual credential rotation needed
✅ **Better security** - no long-lived credentials that can leak

### Branch Policies

The main branch has policies enforced:

- **Minimum reviewers**: At least 1 reviewer required for PRs
- **Work item linking**: Encourages linking code changes to work items
- **No direct commits**: All changes go through pull requests

### Manual Authorization for Production

Production deployments require explicit authorization:

- First time a pipeline runs, you must approve the service connection
- Prevents accidental or unauthorized deployments to production
- Can be authorized permanently for trusted pipelines

---

## Team Collaboration

### Inviting Team Members

Add team members via meshStack:

1. Navigate to your **Dev Project** or **Prod Project**
2. Go to **Access Management** → **Role Mapping**
3. Invite users with appropriate roles:
   - **Project Admin**: Full control over the project
   - **Project User**: Can view and manage resources
   - **Project Reader**: Read-only access

### Azure DevOps Roles

Team members are automatically assigned Azure DevOps roles based on their meshStack roles:

| meshStack Role | Azure DevOps Role |
|----------------|------------------|
| Workspace Owner | Project Administrator |
| Workspace Manager | Contributor |
| Workspace Member | Reader |

---

## Best Practices

### Branch Strategy

**Recommended Workflow**:

1. Create feature branches from `main`
2. Develop and test locally
3. Open PR to `main` for code review
4. Merge to `main` → triggers dev deployment
5. Test in dev environment
6. When ready for release, merge `main` to `release` → triggers prod deployment

**Example**:

```bash
# Create feature branch
git checkout -b feature/new-api
# ... make changes ...
git commit -m "Add new API endpoint"
git push origin feature/new-api

# Open PR to main (via Azure DevOps UI)
# After merge, dev deployment happens automatically

# When ready for production
git checkout release
git merge main
git push origin release
# Prod deployment happens after authorization
```

### Service Connection Authorization

**Development**:
- Auto-authorized for convenience
- Faster iteration and testing

**Production**:
- Manual authorization required on first use
- Adds security checkpoint
- Can be permanently authorized for specific pipelines after initial approval

### Resource Management

**Inside Your Namespace**:
- ✅ Deploy applications
- ✅ Create services, config maps, secrets
- ✅ Manage resource quotas and limits

**Outside Your Namespace**:
- ❌ Cannot modify cluster-wide resources
- ❌ Cannot access other teams' namespaces
- ❌ Cannot change network policies

### Cost Optimization

- Use resource requests and limits in Kubernetes manifests
- Clean up unused resources regularly
- Monitor resource usage via meshStack project tags

---

## Troubleshooting

### Pipeline Fails: "Service connection not found"

**Cause**: Service connection name mismatch or not authorized

**Solution**:
1. Verify service connection name in pipeline YAML matches exactly (case-sensitive)
2. Check if manual authorization is required (go to pipeline run and click "Permit")
3. Ensure service connection exists in **Project Settings** → **Service connections**

### Pipeline Fails: "Insufficient permissions"

**Cause**: Service principal lacks required permissions

**Solution**: Contact the Platform Team to verify service principal role assignment. Required roles:
- **Contributor**: For resource deployment
- **Reader**: For read-only operations

### Service Connection Shows as Invalid

**Cause**: Service principal or federated credential configuration issue

**Solution**: Contact the Platform Team to verify:
- Service principal exists and is active
- Federated identity credential is configured correctly
- Azure AD application is properly set up

### Cannot Access AKS Namespace

**Cause**: Missing Kubernetes RBAC permissions

**Solution**:
1. Verify you have Project Admin or Project User role in meshStack
2. Ensure the tenant (AKS namespace) is fully provisioned
3. Check with Platform Team if custom RBAC policies are in place

### Application Not Accessible

**Cause**: Ingress or service misconfiguration

**Solution**:
1. Check ingress manifest for correct hostname
2. Verify service is targeting correct pods (label selectors)
3. Ensure pods are running: `kubectl get pods -n <namespace>`
4. Check ingress controller logs

### First Production Deployment Stuck

**Cause**: Service connection requires manual authorization

**Solution**: This is expected behavior. Go to the pipeline run and:
1. Click **View** next to the authorization request
2. Click **Permit** to authorize the service connection
3. Pipeline will continue automatically

---

## Advanced Configuration

### Adding Stages and Environments

Modify your pipeline to add approval gates:

```yaml
stages:
  - stage: Build
    jobs:
      - job: BuildJob
        steps:
          - script: docker build -t myapp .

  - stage: DeployDev
    dependsOn: Build
    jobs:
      - deployment: DeployDevJob
        environment: development
        strategy:
          runOnce:
            deploy:
              steps:
                - script: kubectl apply -f k8s/

  - stage: DeployProd
    dependsOn: DeployDev
    jobs:
      - deployment: DeployProdJob
        environment: production  # Requires manual approval
        strategy:
          runOnce:
            deploy:
              steps:
                - script: kubectl apply -f k8s/
```

### Integrating with Azure Container Registry

Update your pipeline to use ACR:

```yaml
variables:
  - name: ACR_NAME
    value: 'myregistry.azurecr.io'

steps:
  - task: Docker@2
    displayName: 'Build and Push to ACR'
    inputs:
      command: buildAndPush
      repository: 'myapp'
      containerRegistry: 'Azure-ACR-Connection'
      tags: |
        $(Build.BuildId)
```

### Running Tests Before Deployment

Add test stages to your pipeline:

```yaml
steps:
  - script: |
      npm install
      npm test
    displayName: 'Run Unit Tests'

  - task: PublishTestResults@2
    inputs:
      testResultsFormat: 'JUnit'
      testResultsFiles: '**/test-results.xml'
```

---

## Related Documentation

- [Azure DevOps Pipelines](https://learn.microsoft.com/en-us/azure/devops/pipelines/)
- [Workload Identity Federation](https://learn.microsoft.com/en-us/azure/devops/pipelines/library/connect-to-azure)
- [AKS Best Practices](https://learn.microsoft.com/en-us/azure/aks/best-practices)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [meshStack Documentation](https://docs.meshcloud.io/)

---

🎉 **Happy coding!** Your AKS Azure DevOps environment is ready for production workloads.
