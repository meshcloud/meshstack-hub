---
name: Forgejo Actions Integration with SKE
supportedPlatforms:
  - stackit
description: |
  CI/CD pipeline using Forgejo Actions for deploying to STACKIT Kubernetes Engine (SKE).
---

# Forgejo Actions Integration with SKE

This Terraform module provisions the necessary resources to integrate Forgejo Actions
with an SKE cluster namespace. It creates a Kubernetes service account with deployment
permissions and stores the kubeconfig as a Forgejo Actions secret.

## Features

- Secure authentication using Kubernetes service accounts
- Kubeconfig automatically stored as a Forgejo Actions repository secret
- Namespace-scoped RBAC (edit role) for least-privilege deployments
