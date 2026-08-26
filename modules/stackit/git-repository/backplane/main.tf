data "http" "org_lookup" {
  url = "${var.forgejo_base_url}/api/v1/orgs/${var.forgejo_organization}"
  request_headers = {
    Authorization = "token ${var.forgejo_token}"
    Accept        = "application/json"
  }

  # Forgejo intermittently leaves requests hanging without an answer. Without a
  # retry the single attempt takes the whole backplane apply down with it.
  retry {
    attempts     = 5
    min_delay_ms = 1000
    max_delay_ms = 10000
  }

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Forgejo organization '${var.forgejo_organization}' does not exist or token has insufficient permissions."
    }
  }
}
