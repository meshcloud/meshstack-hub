This building block provisions a SAP BTP subaccount. It provides a self-service way for application teams to create isolated environments within SAP BTP.

**Usage Motivation**

This building block is designed for application teams that need to develop and deploy applications on the SAP Business Technology Platform (BTP). It allows developers to quickly provision and manage their own isolated BTP subaccounts without requiring manual intervention from the platform team. Use this building block when you need a new, isolated environment for your SAP BTP project.

**Usage Examples**

*   A developer wants to create a new subaccount for a proof-of-concept project. They use this building block to quickly provision a subaccount named "poc-project".
*   An application team wants to create a dedicated subaccount for their production application. They use this building block to provision a subaccount with a specific name that aligns with their project.

**Shared Responsibility**

| Responsibility          | Platform Team ✅/❌ | Application Team ✅/❌ |
| ------------------------- | ------------------- | ---------------------- |
| Subaccount Creation       | ✅                  | ❌                     |
| Using the subaccount      | ❌                  | ✅                     |
| Cost Management           | ❌                  | ✅                     |
| Security                  | ❌                  | ✅                     |
| Updates                   | ❌                  | ✅                     |
