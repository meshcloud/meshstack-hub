provider "{{.Name}}" {
{{- if .Alias }}
  alias = "{{.Alias}}"
{{- end }}
}
