# STACKIT SKE Starterkit — Application Team Guide

## What does this building block do?

The STACKIT SKE Starterkit provisions a complete development environment for your team:

- **Git Repository** on STACKIT Git (Forgejo/Gitea) for your application source code
- **Dev Namespace** on STACKIT Kubernetes Engine for development workloads
- **Prod Namespace** on STACKIT Kubernetes Engine for production workloads

## When to use it

Use this starterkit when your team needs to deploy containerized applications on a sovereign
European Kubernetes platform with separate dev and prod environments.

## Usage

1. Request the starterkit from the meshStack marketplace
2. Provide a project name — this will be used for naming all resources
3. Once provisioned, clone the Git repository and start developing
4. Set up your own CI/CD pipeline to deploy to the dev and prod namespaces

## Shared Responsibility Matrix

| Responsibility                          | Platform Team | Application Team |
| --------------------------------------- | ------------- | ---------------- |
| Provision and manage SKE cluster        | ✅           | ❌              |
| Create Git repository                   | ✅           | ❌              |
| Create Kubernetes namespaces            | ✅           | ❌              |
| Manage access to projects               | ✅           | ✅              |
| Deploy applications to namespaces       | ❌           | ✅              |
| Develop and maintain application code   | ❌           | ✅              |
| Set up CI/CD pipelines                  | ❌           | ✅              |
| Monitor application health              | ❌           | ✅              |

## Best Practices

- Use the **dev** namespace for testing before promoting to **prod**
- Set up branch protection rules in the Git repository
- Configure resource limits in your Kubernetes deployments
- Use Kubernetes Secrets for sensitive configuration
