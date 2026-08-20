run "building_block_stackit_project_hub" {
  assert {
    condition     = output.project_building_block.status.status == "SUCCEEDED"
    error_message = "stackit project hub building block expected SUCCEEDED, got ${output.project_building_block.status.status}"
  }

  assert {
    condition     = jsondecode(output.project_building_block.status.outputs["project_name"].value) == "smoke-prj-${var.test_context.name_suffix}-dev"
    error_message = "stackit project hub building block expected the STACKIT project to be named after the meshStack project identifier 'smoke-prj-${var.test_context.name_suffix}-dev', got ${jsondecode(output.project_building_block.status.outputs["project_name"].value)}"
  }

  # The project id is a PLATFORM_TENANT_ID output, so meshStack writing it back onto the tenant is
  # what proves the whole landing zone round trip worked.
  assert {
    condition     = jsondecode(output.project_building_block.status.outputs["project_id"].value) == output.platform_tenant_id
    error_message = "stackit project hub building block expected the tenant's platform tenant id to be the created STACKIT project id ${jsondecode(output.project_building_block.status.outputs["project_id"].value)}, got ${output.platform_tenant_id}"
  }

  # STACKIT derives the container id from the project name plus a random discriminator.
  assert {
    condition     = startswith(jsondecode(output.project_building_block.status.outputs["container_id"].value), "smoke-prj")
    error_message = "stackit project hub building block expected container_id to be derived from the project name, got ${jsondecode(output.project_building_block.status.outputs["container_id"].value)}"
  }

  assert {
    condition     = strcontains(jsondecode(output.project_building_block.status.outputs["project_url"].value), jsondecode(output.project_building_block.status.outputs["project_id"].value))
    error_message = "stackit project hub building block expected project_url to contain the project id, got ${jsondecode(output.project_building_block.status.outputs["project_url"].value)}"
  }

  assert {
    condition     = strcontains(jsondecode(output.project_building_block.status.outputs["project_url"].value), "portal.stackit.cloud")
    error_message = "stackit project hub building block expected project_url to point at the STACKIT portal, got ${jsondecode(output.project_building_block.status.outputs["project_url"].value)}"
  }

  # The pre-run script writes the organization membership section the summary embeds, so finding it
  # here is what proves the pre-run script ran at all (over an empty user list, see main.tf).
  assert {
    condition     = strcontains(jsondecode(output.project_building_block.status.outputs["summary"].value), "STACKIT Organization Membership")
    error_message = "stackit project hub building block expected the summary to embed the pre-run script's organization membership section, got ${jsondecode(output.project_building_block.status.outputs["summary"].value)}"
  }
}
