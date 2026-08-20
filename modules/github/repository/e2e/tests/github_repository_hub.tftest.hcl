run "github_repository_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "github repository hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = can(regex("^smoke-test-github-repository-\\d+$", jsondecode(meshstack_building_block.this.status.outputs["repo_name"].value)))
    error_message = "github repository hub building block expected repo_name to match the smoke test naming pattern, got ${jsondecode(meshstack_building_block.this.status.outputs["repo_name"].value)}"
  }

  assert {
    condition     = can(regex("^[^/]+/smoke-test-github-repository-\\d+$", jsondecode(meshstack_building_block.this.status.outputs["repo_full_name"].value)))
    error_message = "github repository hub building block expected repo_full_name to be '<owner>/<repo>', got ${jsondecode(meshstack_building_block.this.status.outputs["repo_full_name"].value)}"
  }

  assert {
    condition     = can(regex("^https://github\\.com/[^/]+/smoke-test-github-repository-\\d+$", jsondecode(meshstack_building_block.this.status.outputs["repo_html_url"].value)))
    error_message = "github repository hub building block expected repo_html_url to be the repository URL, got ${jsondecode(meshstack_building_block.this.status.outputs["repo_html_url"].value)}"
  }

  assert {
    condition     = can(regex("^https://github\\.com/[^/]+/smoke-test-github-repository-\\d+\\.git$", jsondecode(meshstack_building_block.this.status.outputs["repo_git_clone_url"].value)))
    error_message = "github repository hub building block expected repo_git_clone_url to be a clonable git URL, got ${jsondecode(meshstack_building_block.this.status.outputs["repo_git_clone_url"].value)}"
  }
}
