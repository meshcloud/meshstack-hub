run "building_block_stackit_git_repository_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "stackit git-repository hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = strcontains(jsondecode(meshstack_building_block.this.status.outputs["summary"].value), "is ready on STACKIT Git Forgejo")
    error_message = "stackit git-repository hub building block expected summary to contain 'is ready on STACKIT Git Forgejo', got ${jsondecode(meshstack_building_block.this.status.outputs["summary"].value)}"
  }

  assert {
    condition     = can(regex("^${var.test_context.forgejo_base_url}/${var.test_context.forgejo_organization}/smoke-test-repo-\\d+\\.git$", jsondecode(meshstack_building_block.this.status.outputs["repository_clone_url"].value)))
    error_message = "stackit git-repository hub building block expected repository_clone_url to match pattern, got ${jsondecode(meshstack_building_block.this.status.outputs["repository_clone_url"].value)}"
  }
}
