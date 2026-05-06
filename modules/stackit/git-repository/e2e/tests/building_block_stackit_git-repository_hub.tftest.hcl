run "building_block_stackit_git_repository_hub" {
  assert {
    condition     = meshstack_building_block_v2.this.status.status == "SUCCEEDED"
    error_message = "stackit git-repository hub building block expected SUCCEEDED, got ${meshstack_building_block_v2.this.status.status}"
  }

  assert {
    condition     = strcontains(meshstack_building_block_v2.this.status.outputs["summary"].value_string, "is ready on STACKIT Git Forgejo")
    error_message = "stackit git-repository hub building block expected summary to contain 'is ready on STACKIT Git Forgejo', got ${meshstack_building_block_v2.this.status.outputs["summary"].value_string}"
  }

  assert {
    condition     = can(regex("^${var.test_context.forgejo_base_url}/${var.test_context.forgejo_organization}/smoke-test-repo-\\d+\\.git$", meshstack_building_block_v2.this.status.outputs["repository_clone_url"].value_string))
    error_message = "stackit git-repository hub building block expected repository_clone_url to match pattern, got ${meshstack_building_block_v2.this.status.outputs["repository_clone_url"].value_string}"
  }
}
