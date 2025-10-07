# Add documentation template resource
resource "azurerm_resource_group_template_deployment" "documentation" {
  name                = "azure-devops-documentation"
  resource_group_name = azurerm_resource_group.devops.name
  deployment_mode     = "Incremental"

  template_content = jsonencode({
    "$schema"      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    contentVersion = "1.0.0.0"
    parameters     = {}
    variables      = {}
    resources      = []
    outputs = {
      documentation = {
        type = "object"
        value = {
          title       = "Azure DevOps Project Building Block"
          description = "Creates and manages Azure DevOps projects with user entitlements and group memberships"
          version     = "1.0.0"
          backplane = {
            resources = [
              "Azure AD Service Principal",
              "Azure Key Vault for PAT storage",
              "Custom Role Definitions",
              "Role Assignments"
            ]
          }
          buildingblock = {
            resources = [
              "Azure DevOps Project",
              "User Entitlements (Stakeholder licenses)",
              "Custom Project Groups",
              "Group Memberships"
            ]
          }
          requirements = [
            "Azure DevOps organization",
            "Personal Access Token with required scopes",
            "Users must exist in Azure AD/identity provider"
          ]
        }
      }
    }
  })
}