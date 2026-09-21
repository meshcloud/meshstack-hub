provider "azuredevops" {
  org_service_url       = "${var.azuredevops_base_url}/${var.azuredevops_organization}"
  personal_access_token = var.azuredevops_personal_access_token
}
