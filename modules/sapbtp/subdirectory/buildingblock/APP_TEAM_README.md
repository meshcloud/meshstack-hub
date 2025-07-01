This building block creates a subdirectory within the root folder of SAP BTP or can be used to create account directories. It simplifies the management of directory structures, offering flexibility and control over the organization of subaccounts.

**Usage Motivation:**

This building block is specifically designed for platform teams and developers who need to organize SAP BTP subaccounts into a structured directory hierarchy. It's particularly useful when you want to ensure that all projects reside in separate, well-defined folders.

**Usage Examples:**

1.  A platform team uses this building block to create a dedicated directory for each new project within the SAP BTP root folder. This ensures clear separation and simplifies access control.
2.  When provisioning new subaccounts, the building block can be used to automatically create corresponding account directories, maintaining a consistent organizational structure.

**Shared Responsibility:**

| Responsibility          | Platform Team (Managed by Building Block) ✅ | Application Team ❌ |
| ------------------------- | ------------------------------------------- | -------------------- |
| Directory Creation        | ✅                                          | ❌                   |
| Directory Management      | ✅                                          | ❌                   |
| Permissions (initial)     | ✅                                          | ❌                   |
| Ongoing Maintenance       | ✅                                          | ❌                   |
