This building block sets up a GitHub repository to run GitHub Actions with access to your Azure Subscription. It's part of the Azure Starterkit, designed to provide application teams with a pre-configured environment for learning and experimentation.

## Usage Motivation

This building block is for developers and application teams who want to:

*   Quickly bootstrap a new project with a ready-to-use CI/CD pipeline.
*   Experiment with Azure deployments using GitHub Actions without manual configuration.
*   Learn how to integrate Terraform with GitHub Actions for infrastructure automation.

## Usage Examples

1.  **Deploying a simple web application:** Use the building block to create a repository with a basic web application template and a GitHub Actions workflow that deploys it to Azure App Service.
2.  **Provisioning Azure resources:**  Leverage the building block to set up a repository containing Terraform code to provision resources like virtual machines, databases, or storage accounts in your Azure subscription, using GitHub Actions for automation.

## Shared Responsibility

| Feature            | Platform Engineer (Managed & Provided) ✅ | Application Team ❌ |
|---------------------|------------------------------------------|---------------------|
| GitHub Actions Setup | ✅                                      | ❌                  |
| Azure Managed Identity  | ✅                                   | ❌                  |
| Terraform Automation | ✅                                      | ❌                  |
| Input Configuration   | ❌                                     | ✅                  |
| Application Code     | ❌                                      | ✅                  |
| Resource Management  | ✅                                      | ❌                  |
