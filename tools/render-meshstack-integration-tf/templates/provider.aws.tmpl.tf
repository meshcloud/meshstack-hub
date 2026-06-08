provider "aws" {
{{- if .Alias }}
  alias = "{{.Alias}}"
{{- end }}
  # Configure AWS credentials via environment variables (recommended),
  # for example AWS_PROFILE, AWS_REGION, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY.
}
