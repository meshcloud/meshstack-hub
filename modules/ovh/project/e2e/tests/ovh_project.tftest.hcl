run "ovh_project" {
  assert {
    condition     = output.project_building_block.status.succeeded
    error_message = "ovh project building block expected SUCCEEDED, got health status ${output.project_building_block.status.health_status}, action ${output.project_building_block.status.action}"
  }

  # The project id is a PLATFORM_TENANT_ID output, so meshStack writing it back onto the tenant is
  # what proves the round trip worked.
  assert {
    condition     = jsondecode(output.project_building_block.status.outputs["project_id"].value) == output.platform_tenant_id
    error_message = "ovh project building block expected the tenant's platform tenant id to be the created project id ${jsondecode(output.project_building_block.status.outputs["project_id"].value)}, got ${coalesce(output.platform_tenant_id, "null")}"
  }

  assert {
    condition     = strcontains(jsondecode(output.project_building_block.status.outputs["project_url"].value), jsondecode(output.project_building_block.status.outputs["project_id"].value))
    error_message = "ovh project building block expected project_url to contain the project id, got ${jsondecode(output.project_building_block.status.outputs["project_url"].value)}"
  }

  assert {
    condition     = startswith(jsondecode(output.project_building_block.status.outputs["project_urn"].value), "urn:v1:")
    error_message = "ovh project building block expected an IAM resource URN, got ${jsondecode(output.project_building_block.status.outputs["project_urn"].value)}"
  }

  # The summary names the project by its description, which proves the workspace and project
  # identifiers reached the building block.
  assert {
    condition     = strcontains(jsondecode(output.project_building_block.status.outputs["summary"].value), output.expected_project_description)
    error_message = "ovh project building block expected the summary to name the project '${output.expected_project_description}', got ${jsondecode(output.project_building_block.status.outputs["summary"].value)}"
  }
}
