provider "meshstack" {
{{- if .Alias }}
  alias = "{{.Alias}}"
{{- end }}
  # Run `meshstack login` (https://github.com/meshcloud/meshstack-cli) to configure this provider.
  # Alternatively, authenticate with an API key via MESHSTACK_ENDPOINT, MESHSTACK_API_KEY and
  # MESHSTACK_API_SECRET environment variables, see https://docs.meshcloud.io/api/authentication/api-keys/
}
