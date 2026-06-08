provider "azurerm" {
{{- if .Alias }}
  alias = "{{.Alias}}"
{{- end }}
  features {}
  resource_provider_registrations = "none"
}
