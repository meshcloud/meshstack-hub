This building block enables AWS regions that require explicit opt-in for your AWS account.

## Usage Motivation

This building block is designed for platform engineers and application teams who need to manage access to specific AWS regions, particularly newer regions or those with specific compliance requirements. It ensures that only approved regions are enabled for your AWS account, providing better control and security.

## Usage Examples

**Example 1: Enabling a new AWS Region**

To enable a new AWS region, simply configure the building block with the desired region code (e.g., `eu-south-2`). The building block will then enable the region for your AWS account.

### Shared Responsibility

| Responsibility          | Platform Team (Managed & Provided) | Application Team (Responsible) |
| ------------------------- | ------------------------------------ | -------------------------------- |
| Region Enablement         | ✅                                  | ❌                               |
| AWS Account Configuration | ✅                                  | ❌                               |
| Input Configuration       | ❌                                  | ✅                               |
| Compliance Verification   | ✅                                  | ❌                                 |