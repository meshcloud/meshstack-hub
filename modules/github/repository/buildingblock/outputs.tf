output "repo_name" {
  value = github_repository.repository.name
}

output "repo_full_name" {
  value = github_repository.repository.full_name
}

output "repo_html_url" {
  value = github_repository.repository.html_url
}

output "repo_git_clone_url" {
  value = github_repository.repository.git_clone_url
}
