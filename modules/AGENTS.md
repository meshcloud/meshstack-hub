# AGENTS.md - Building Block Module Patterns and Conventions

## Module Structure Overview

Each building block follows a consistent two-tier architecture:

1. **Backplane** - Infrastructure provisioning and permission setup
2. **Building Block** - The actual service/resource implementation

## Directory Structure Pattern

```
<cloud-provider>/
  <service-name>/
    backplane/
      main.tf
      outputs.tf
      variables.tf
      versions.tf
      README.md                    # Technical documentation for engineers
      [provider-specific files like iam.tf, documentation.tf]
    buildingblock/
      main.tf
      outputs.tf
      variables.tf
      versions.tf
      provider.tf
      README.md                    # Technical documentation for engineers
      APP_TEAM_README.md          # User-facing documentation for app teams
      logo.png
      [test files like *.tftest.hcl]
```

## Reference Example: AWS Budget Alert

```
aws/
  budget-alert/
    backplane/
      main.tf           # IAM user, CloudFormation StackSet for cross-account roles
      outputs.tf        # Backplane user ARN, access keys
      variables.tf      # backplane_user_name, target_ou_ids
      versions.tf       # AWS provider ~> 5.0
      README.md
    buildingblock/
      main.tf           # aws_budgets_budget resource
      outputs.tf        # budget ARN, name
      variables.tf      # budget_name, monthly_budget_amount, contact_emails
      versions.tf       # AWS ~> 5.0, time ~> 0.11.1
      provider.tf       # Assume role configuration
      APP_TEAM_README.md # Usage examples, best practices
      logo.png
      budget-alert.tftest.hcl # Test scenarios
```

## Provider Version Strategy

**Provider versions are module-specific, not repository-wide.** Each module should declare the minimum provider version it requires based on testing and feature needs.

**Version Selection Criteria:**

When choosing a provider version for a module, consider:

1. **Feature Requirements** - Does the module need specific APIs/resources from newer versions?
2. **Testing Validation** - Which version has been tested with this module?
3. **Breaking Changes** - Are there known breaking changes to avoid?
4. **Stability** - Prefer versions with `~>` for patch updates unless there's a specific reason
5. **Backwards Compatibility** - Will this work with existing deployments?

**Version Constraint Best Practices:**

- **Use `~> X.Y.Z`** to allow patch updates (recommended for most cases)
- **Use exact versions** (`X.Y.Z`) only for providers with frequent breaking changes
- **Document in the module's README** why a specific version is required
- **Test against specific versions** - Each module should be validated with the provider version it declares
- **Review provider versions quarterly** to stay current with security patches and new features

## Terraform Version Requirements

**Standard Baseline:** `>= 1.3.0` (unless provider requires higher)
- Provides stable feature set
- Good performance improvements
- Consistent across all modules

## Architecture Flow

```
┌─────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  Backplane  │───▶│ Roles/Permissions│───▶│ Building Block  │
│             │    │                  │    │                 │
│ • IAM Users │    │ • Cross-account  │    │ • Actual        │
│ • StackSets │    │   roles          │    │   resources     │
│ • Role Defs │    │ • Assume roles   │    │ • Service logic │
└─────────────┘    └──────────────────┘    └─────────────────┘
```

## Backplane Patterns by Provider

**AWS Backplane Pattern:**
- Creates IAM users and access keys for building block deployment
- Uses CloudFormation StackSets for cross-account role deployment
- Implements assume role patterns for target account access
- Uses organizational unit targeting for permissions

**Azure Backplane Pattern:**
- Creates custom role definitions with specific permissions
- Uses role assignments for principal access
- Scoped to subscription or management group level
- **Service Principal Creation (Optional):**
  - Can create Azure AD application and service principal
  - Supports **Workload Identity Federation (WIF)** for passwordless authentication
  - Falls back to application password if WIF not configured
  - Automatically assigns created principals to role definitions
- **Two-tier permissions for networking:**
  - `buildingblock_deploy` role: Main deployment permissions
  - `buildingblock_deploy_hub` role: Hub-specific permissions for VNet peering (e.g., ACR, Key Vault)

**GCP Backplane Pattern:** *TBD - To be documented*

**SAP BTP Backplane Pattern:** *TBD - To be documented*

## Building Block Patterns

**Common Files:**
- `main.tf` - Core resource definitions
- `variables.tf` - Input parameters with descriptions and defaults
- `outputs.tf` - Return values
- `versions.tf` - Provider version constraints
- `provider.tf` - Provider configuration
- `README.md` - Technical documentation for engineers/infra teams
- `APP_TEAM_README.md` - User-facing documentation for app/product teams
- `logo.png` - Visual identifier
- Test files (`.tftest.hcl`) for validation

## Variable Naming Convention

**Standard:** Use `snake_case` consistently across all providers
- ✅ `monthly_budget_amount`
- ✅ `contact_emails`
- ✅ `subscription_id`
- ❌ `monthlyBudgetAmount` (avoid camelCase)

## Testing Patterns

**Test File Requirements (`.tftest.hcl`):**
- **Positive scenarios:** Valid configurations that should succeed
- **Negative scenarios:** Invalid inputs that should fail gracefully
- **Naming collision tests:** Prevent resource conflicts
- **Cross-provider consistency:** Similar test patterns across clouds
- **Test Users:** Use the following test users:
  - **User Tom:**
    ```json
          {
            meshIdentifier = "likvid-tom-user"
            username       = "likvid-tom@meshcloud.io"
            firstName      = "Tom"
            lastName       = "Livkid"
            email          = "likvid-tom@meshcloud.io"
            euid           = "likvid-tom@meshcloud.io"
            roles          = ["admin", "Workspace Owner"]
          }
    ```
    - **User Daniela:**
    ```json
          {
            meshIdentifier = "likvid-daniela-user"
            username       = "likvid-daniela@meshcloud.io"
            firstName      = "Daniela"
            lastName       = "Livkid"
            email          = "likvid-daniela@meshcloud.io"
            euid           = "likvid-daniela@meshcloud.io"
            roles          = ["user", "Workspace Manager"]
          }
    ```
    - **User Anna:**
    ```json
          {
            meshIdentifier = "likvid-anna-user"
            username       = "likvid-anna@meshcloud.io"
            firstName      = "Anna"
            lastName       = "Livkid"
            email          = "likvid-anna@meshcloud.io"
            euid           = "likvid-anna@meshcloud.io"
            roles          = ["reader", "Workspace Member"]
          }
    ```

**Example Test Structure:**
```hcl
# budget-alert.tftest.hcl
run "valid_budget_configuration" {
  # Test successful budget creation
}

run "invalid_budget_amount" {
  # Test validation of negative budget amounts
}

run "naming_collision_prevention" {
  # Test resource naming uniqueness
}
```

## Documentation Patterns

**buildingblock/README.md (Technical):**
```yaml
---
name: Service Name Building Block
supportedPlatforms:
  - aws|azure|gcp|btp
description: Brief description for catalog explaining what this building block provides
category: "cost-management|security|networking|storage"
---
```

**Example for AWS S3 Bucket:**
```yaml
---
name: AWS S3 Bucket
supportedPlatforms:
  - aws
description: Provides an AWS S3 bucket for object storage with access controls, lifecycle policies, and encryption.
category: storage
---
```

- Provider configuration details
- Resource dependencies
- Advanced configuration options
- Troubleshooting guide

**backplane/README.md (Technical):**
- Backplane-specific setup instructions
- IAM/permission requirements
- Cross-account configuration details

**APP_TEAM_README.md (User-facing):**

**Required Sections:**
- 🚀 Usage Examples
- 🔄 Shared Responsibility Matrix
- 💡 Best Practices
- Configuration guidance

## Common Services Implemented

- **Cost Management:** Budget alerts (AWS, Azure, GCP)
- **Storage:** S3 buckets, Azure storage accounts, GCS buckets
- **Container Registries:** Azure Container Registry (ACR) with private networking
- **Networking:** VPCs, spoke networks, subnets
- **Databases:** PostgreSQL, managed database instances
- **Security:** Key Vault, IAM roles, secret management
- **CI/CD:** GitHub Actions integration, service connections
- **Compute:** Virtual machines (Azure), AKS integration

## Best Practices for New Modules

1. **Provider Versions:** Follow pinning strategy above
2. **Structure:** Implement backplane/buildingblock pattern
3. **Documentation:** Include YAML front-matter and both README types
4. **Testing:** Cover positive, negative, and naming scenarios
5. **Variables:** Use snake_case with sensible defaults and examples
6. **Outputs:** Return integration-useful information
7. **Naming:** Consistent, descriptive resource names
8. **Permissions:** Least privilege principle in backplane
9. **Validation:** Input validation in variables.tf
10. **Consistency:** Follow established patterns across providers
11. **Code Quality:** Remove trailing whitespaces and maintain clean formatting

## Module Creation Checklist

- [ ] Backplane and buildingblock directories created
- [ ] All required files present (main.tf, variables.tf, outputs.tf, versions.tf)
- [ ] Provider versions follow pinning strategy
- [ ] Variables use snake_case naming
- [ ] Documentation includes YAML front-matter
- [ ] Test files cover required scenarios
- [ ] Logo image included
- [ ] Shared responsibility matrix documented
- [ ] Cross-provider consistency maintained

This comprehensive guide ensures consistency and quality across all building block modules in the multi-cloud platform.
