# Azure Kubernetes Service (AKS) Starterkit

## What is it?

The **AKS Starterkit** provides application teams with a pre-configured Kubernetes environment following the organization's best practices. It automates the creation of essential infrastructure, including a Git repository, a CI/CD pipeline using GitHub Actions, and a secure container registry integration.

## When to use it?

This building block is ideal for teams that:

- Want to deploy applications on Kubernetes without worrying about setting up infrastructure from scratch.
- Need a secure, best-practice-aligned environment for developing, testing, and deploying workloads.
- Prefer a streamlined CI/CD setup with built-in security and governance.

## Usage Examples

1. **Deploying a microservice**: A developer can use this building block to create a Git repository and CI/CD pipeline for a new microservice. The pipeline will build and scan container images before deploying them into separate Kubernetes namespaces for development and production.
2. **Setting up a new project**: A new project team can quickly get started with an opinionated AKS setup that ensures compliance with the organization's security and operational standards.

## Resources Created

This building block automates the creation of the following resources:

- **GitHub Repository**: A new repository to store your application code and Dockerfile.
- **Development Project**: You, as the creator, will have access to this project and AKS namespace.
  - **AKS Namespace**: A dedicated Kubernetes namespace for development.
    - **GitHub Actions Connector**: Connects the GitHub repository to the development AKS namespace via GitHub Actions and deploys after every commit to the main branch.
- **Production Project**: You, as the creator, will have access to this project and AKS namespace.
  - **AKS Namespace**: A dedicated Kubernetes namespace for production.
    - **GitHub Actions Connector**: Connects the GitHub repository to the production AKS namespace via GitHub Actions and deploys after every commit to the release branch.

## Shared Responsibilities

| Responsibility                               | Platform Team | Application Team |
| -------------------------------------------- | --------------------------- | ------------------ |
| Provision and manage AKS cluster             | ✅                         | ❌                |
| Create and manage Git repository             | ✅                         | ❌                |
| Set up GitHub Actions CI/CD pipeline        | ✅                         | ❌                |
| Build and scan Docker images                 | ✅                         | ❌                |
| Manage Kubernetes namespaces (dev/prod)      | ✅                         | ❌                |
| Manage resources inside namespaces            | ❌                         | ✅                |
| Develop and maintain application source code | ❌                         | ✅                |
| Maintain application configurations          | ❌                         | ✅                |
| Merge to release branch for prod deployments to AKS          | ❌                         | ✅                |

---
