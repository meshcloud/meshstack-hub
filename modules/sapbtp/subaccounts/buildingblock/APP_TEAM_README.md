This building block provisions a SAP BTP subaccount with optional application subscriptions, entitlements, Cloud Foundry environment, and custom identity provider configuration. It provides a self-service way for application teams to create fully configured isolated environments within SAP BTP.

**Usage Motivation**

This building block is designed for application teams that need to develop and deploy applications on the SAP Business Technology Platform (BTP). It allows developers to quickly provision and manage their own isolated BTP subaccounts with pre-configured applications, services, and authentication without requiring manual intervention from the platform team. Use this building block when you need a new, isolated environment for your SAP BTP project with additional services and applications enabled.

**Usage Examples**

*   A developer wants to create a new subaccount for a proof-of-concept project with SAP Build Code and Process Automation enabled. They use this building block to quickly provision a subaccount with the required subscriptions.
*   An application team wants to create a dedicated subaccount for their production application with Cloud Foundry enabled for deployment and SAP IAS configured for single sign-on.
*   A development team needs a sandbox environment with multiple SAP applications subscribed and proper entitlements allocated for testing purposes.

**Features**

**Application Subscriptions**: Subscribe to SAP BTP applications like SAP Build Code, SAP Process Automation, or Cloud Transport within the subaccount.

**Entitlements Management**: Automatically configure service entitlements required for application subscriptions and service usage.

**Cloud Foundry Environment**: Optionally provision a Cloud Foundry space for application deployment and development.

**Custom Identity Provider**: Configure external identity providers like SAP IAS for single sign-on authentication.

**Shared Responsibility**

| Responsibility                    | Platform Team ✅/❌ | Application Team ✅/❌ |
| --------------------------------- | ------------------- | ---------------------- |
| Subaccount Creation               | ✅                  | ❌                     |
| Entitlements Configuration        | ✅                  | ❌                     |
| Application Subscriptions         | ✅                  | ❌                     |
| Cloud Foundry Environment Setup   | ✅                  | ❌                     |
| Trust Configuration (IDP)         | ✅                  | ❌                     |
| Using the subaccount              | ❌                  | ✅                     |
| Application Development           | ❌                  | ✅                     |
| Cost Management                   | ❌                  | ✅                     |
| Security & Compliance             | ❌                  | ✅                     |
| Updates                           | ❌                  | ✅                     |
