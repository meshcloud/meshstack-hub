data "btp_directories" "all" {}

locals {
  subfolders = [
    for dir in data.btp_directories.all.values : {
      id   = dir.id
      name = dir.name
    }
    if dir.parent_id == var.parent_id
  ]

  selected_subfolder_id = try(
    one([
      for sf in local.subfolders : sf.id
      if sf.name == var.subfolder
    ]),
    null
  )

  base_project_identifier = regex("^(.+?)(-(dev|prod|qa|test))?$", var.project_identifier)[0]
}

output "project_folder" {
  value = local.base_project_identifier
}

# Create a child directory underneath a parent directory without features enabled
resource "btp_directory" "child" {
  parent_id   = local.selected_subfolder_id
  name        = local.base_project_identifier
  description = "This is a child directory."
}
