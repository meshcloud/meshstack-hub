output "forgejo_robot_name" {
  value     = harbor_robot_account.forgejo_robot.name
  sensitive = true
}

output "forgejo_robot_token" {
  value     = harbor_robot_account.forgejo_robot.secret
  sensitive = true
}

output "harbor_roject" {
  value     = harbor_project.harbor_project.name
  sensitive = true
}

output "k8s_image_pull_robot_name" {
  value     = harbor_robot_account.k8s_image_pull_robot.name
  sensitive = true
}

output "k8s_image_pull_robot_token" {
  value     = harbor_robot_account.k8s_image_pull_robot.secret
  sensitive = true
}

output "service_account_kubeconfig" {
  value     = module.k8s_service_account.kubeconfig
  sensitive = true
}
