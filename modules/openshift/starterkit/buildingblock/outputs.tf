output "github_repo_url" {
  description = "URL of the created GitHub repository."
  value       = local.repo_html_url
}

# The per-stage parts are joined here rather than looped with template directives inside the
# heredoc: a directive keeps its own indentation, which turns the markdown into a code block.
locals {
  summary_stage_tree = join("\n\n", [
    for stage, project in meshstack_project.this : join("\\\n", [
      "@project[${project.metadata.owned_by_workspace}.${project.metadata.name}]",
      "&nbsp;&nbsp;&nbsp;&nbsp;@tenant[${meshstack_tenant.this[stage].metadata.uuid}]",
      "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;@buildingblock[${meshstack_building_block.github_actions[stage].metadata.uuid}]",
    ])
  ])

  summary_stage_rows = join("\n", [
    for stage, branch in local.deploy_branches :
    "| ${stage} | `${branch}` | [${local.app_hostnames[stage]}](https://${local.app_hostnames[stage]}) |"
  ])

  summary_access_links = join("\n", [
    for stage, project in meshstack_project.this :
    "  - [${title(stage)} access](#/w/${var.workspace_identifier}/p/${project.metadata.name}/access-management/role-mapping)"
  ])

  summary_promotion = contains(keys(local.deploy_branches), "prod") ? "- Open a pull request from `main` to `release` to promote to production.\n" : ""
}

output "summary" {
  description = "Summary with next steps and insights into created resources."
  value       = <<-EOT
    # OpenShift Starter Kit

    ✅ **Your environment is ready!**

    This starter kit has set up the following resources in workspace `${var.workspace_identifier}`:

    @buildingblock[${meshstack_building_block.repo.metadata.uuid}]

    ${local.summary_stage_tree}

    ---

    ## Deployments

    Each stage has its own GitHub environment, named after the stage, and deploys from its own branch:

    | Stage | Branch | App |
    |---|---|---|
    ${local.summary_stage_rows}

    Follow the runs in the [Actions tab](${local.repo_html_url}/actions).

    ## Next Steps

    - Clone [the repository](${local.repo_html_url}) and push to `main` to deploy.
    ${local.summary_promotion}- Invite your team in meshStack:
    ${local.summary_access_links}

    🎉 Happy coding!
  EOT
}
