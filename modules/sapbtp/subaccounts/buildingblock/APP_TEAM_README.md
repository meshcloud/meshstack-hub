This building block provisions a SAP BTP subaccount with optional application subscriptions, entitlements, Cloud Foundry environment, and custom identity provider configuration. It provides a self-service way for application teams to create fully configured isolated environments within SAP BTP.

**Usage Motivation**

This building block is designed for application teams that need to develop and deploy applications on the SAP Business Technology Platform (BTP). It allows developers to quickly provision and manage their own isolated BTP subaccounts with pre-configured applications, services, and authentication without requiring manual intervention from the platform team. Use this building block when you need a new, isolated environment for your SAP BTP project with additional services and applications enabled.

**Usage Examples**

*   Create a proof-of-concept project with SAP Build Code and Process Automation
*   Create a production subaccount with Cloud Foundry, PostgreSQL, Redis, and SAP IAS SSO
*   Set up a sandbox with multiple SAP applications and Cloud Foundry services for testing
*   Quickly configure an Integration Suite environment with connectivity services
*   Provision a development environment with Build Work Zone, Build Code, and supporting services

**Features**

**Application Subscriptions**: Subscribe to SAP BTP applications like SAP Build Code, SAP Process Automation, SAP Build Work Zone, Integration Suite, or Cloud Transport within the subaccount.

**Entitlements Management**: Automatically configure service entitlements required for application subscriptions and service usage.

**Cloud Foundry Environment**: Optionally provision a Cloud Foundry space for application deployment and development.

**Cloud Foundry Services**: Provision commonly used Cloud Foundry service instances such as PostgreSQL, Redis, Destination service, XSUAA, Application Logging, HTML5 Repository, Job Scheduler, Credential Store, and more.

**Trust Configuration**: Configure external identity providers like SAP IAS for single sign-on authentication.

**Most Popular SAP BTP Services Available**:
- SAP Build Work Zone (central launchpad)
- SAP Build Code (low-code development)
- SAP Build Apps (no-code app builder)
- SAP Build Process Automation
- SAP Integration Suite
- SAP HANA Cloud
- SAP Business Application Studio
- PostgreSQL and Redis databases
- Destination and Connectivity services
- XSUAA (Authentication & Authorization)

**Shared Responsibility**

| Responsibility                    | Platform Team ✅/❌ | Application Team ✅/❌ |
| --------------------------------- | ------------------- | ---------------------- |
| Subaccount Creation               | ✅                  | ❌                     |
| Entitlements Configuration        | ✅                  | ❌                     |
| Application Subscriptions         | ✅                  | ❌                     |
| Cloud Foundry Environment Setup   | ✅                  | ❌                     |
| Cloud Foundry Service Provisioning| ✅                  | ❌                     |
| Trust Configuration (IDP)         | ✅                  | ❌                     |
| Using the subaccount              | ❌                  | ✅                     |
| Application Development           | ❌                  | ✅                     |
| Cost Management                   | ❌                  | ✅                     |
| Security & Compliance             | ❌                  | ✅                     |
| Service Bindings & Keys           | ❌                  | ✅                     |
| Updates                           | ❌                  | ✅                     |
