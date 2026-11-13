output "project_id" {
  value       = tencentcloud_project.project.id
  description = "The ID of the created Tencent Cloud project."
}

output "project_name" {
  value       = tencentcloud_project.project.project_name
  description = "The name of the created Tencent Cloud project."
}

output "console_url" {
  value       = "https://console.cloud.tencent.com/project/manage?projectId=${tencentcloud_project.project.id}"
  description = "The deep link URL to access the project in the Tencent Cloud console."
}

output "admin_group_id" {
  value       = tencentcloud_cam_group.admins.id
  description = "The ID of the admin CAM group."
}

output "user_group_id" {
  value       = tencentcloud_cam_group.users.id
  description = "The ID of the user CAM group."
}

output "reader_group_id" {
  value       = tencentcloud_cam_group.readers.id
  description = "The ID of the reader CAM group."
}
