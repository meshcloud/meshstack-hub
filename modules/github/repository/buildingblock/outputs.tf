output "repo_name" {
  value = length(github_repository.repository) > 0 ? github_repository.repository[0].name : data.github_repository.existing[0].name
}

output "repo_full_name" {
  value = length(github_repository.repository) > 0 ? github_repository.repository[0].full_name : data.github_repository.existing[0].full_name
}

output "repo_html_url" {
  value = length(github_repository.repository) > 0 ? github_repository.repository[0].html_url : data.github_repository.existing[0].html_url
}

output "repo_git_clone_url" {
  value = length(github_repository.repository) > 0 ? github_repository.repository[0].git_clone_url : data.github_repository.existing[0].git_clone_url
}
