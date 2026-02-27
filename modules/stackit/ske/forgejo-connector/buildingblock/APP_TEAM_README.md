# Forgejo Actions Integration with SKE

## Description

This building block connects your Forgejo (STACKIT Git) repository to a STACKIT Kubernetes
Engine (SKE) namespace via Forgejo Actions. It provides your CI/CD workflows with secure
access to deploy applications into your Kubernetes namespace.

## Usage Motivation

Use this building block when you want to automate deployments from your STACKIT Git repository
to SKE using Forgejo Actions workflows, similar to GitHub Actions.

## Usage Examples

- Push code to your repository and have Forgejo Actions automatically build and deploy your
  application to the connected SKE namespace.
- Set up a workflow that runs tests and deploys on merge to the main branch.

## Prerequisites

- A Forgejo repository (created via the STACKIT Git Repository building block)
- An SKE namespace (created via the STACKIT Starterkit or manually)

## Shared Responsibility

| Responsibility                                    | Platform Team | Application Team |
|---------------------------------------------------|---------------|------------------|
| Setting up Forgejo Actions connector and secrets  | ✅           | ❌              |
| Managing SKE cluster and namespace                | ✅           | ❌              |
| Writing Forgejo Actions workflow files            | ❌           | ✅              |
| Writing and maintaining Kubernetes manifests      | ❌           | ✅              |
| Monitoring deployments and troubleshooting        | ❌           | ✅              |

## Recommendations

- **Use namespace-scoped resources**: The service account only has `edit` access within your
  namespace — do not attempt to create cluster-scoped resources.
- **Keep secrets secure**: The `KUBECONFIG` secret is automatically managed. Do not expose it
  in workflow logs.
- **Use deployment strategies**: Implement rolling updates for minimal downtime.
