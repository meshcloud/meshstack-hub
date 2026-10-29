# The members of the project see and use the bucket in the console, through their project groups.
# OBS is a global service, so their roles on the project do not reach it; these roles grant this
# bucket and its key only. The actions follow the ones the upstream module grants its access user.

data "opentelekomcloud_identity_group_v3" "project" {
  for_each = var.group_access

  name = "${data.opentelekomcloud_identity_project_v3.tenant.name}_${each.key}"
}

# OBS takes the bucket and object permissions through the `MOS` project, as the upstream module
# assigns them too.
data "opentelekomcloud_identity_project_v3" "obs" {
  name = "MOS"
}

# The provider targets the region's project, which holds the bucket's KMS key.
data "opentelekomcloud_identity_project_v3" "region" {}

data "opentelekomcloud_kms_key_v1" "bucket" {
  key_description = "${module.bucket.bucket_name} encryption key"
}

locals {
  bucket_resource = "obs:*:*:bucket:${module.bucket.bucket_name}"
  object_resource = "obs:*:*:object:${module.bucket.bucket_name}/*"

  read_bucket_actions = [
    "obs:bucket:HeadBucket",
    "obs:bucket:ListBucket",
    "obs:bucket:ListBucketVersions",
    "obs:bucket:GetBucketLocation",
    "obs:bucket:ListBucketMultipartUploads",
  ]
  read_object_actions = [
    "obs:object:GetObject",
    "obs:object:GetObjectVersion",
    "obs:object:GetObjectAcl",
    "obs:object:GetObjectVersionAcl",
  ]
  write_object_actions = [
    "obs:object:PutObject",
    "obs:object:DeleteObject",
    "obs:object:DeleteObjectVersion",
    "obs:object:ListMultipartUploadParts",
    "obs:object:AbortMultipartUpload",
    "obs:object:ModifyObjectMetaData",
  ]
}

resource "opentelekomcloud_identity_role_v3" "bucket" {
  for_each = toset(values(var.group_access))

  display_name  = "${module.bucket.bucket_name}-${each.key}"
  description   = "${each.key == "write" ? "Read and write" : "Read"} access to the OBS bucket ${module.bucket.bucket_name} for its project's members."
  display_layer = "domain"

  # The console lists every bucket name before it opens one; it shows no other bucket's content.
  statement {
    effect = "Allow"
    action = ["obs:bucket:ListAllMybuckets"]
  }

  statement {
    effect   = "Allow"
    resource = [local.bucket_resource]
    action   = local.read_bucket_actions
  }

  statement {
    effect   = "Allow"
    resource = [local.object_resource]
    action   = each.key == "write" ? concat(local.read_object_actions, local.write_object_actions) : local.read_object_actions
  }
}

resource "opentelekomcloud_identity_role_v3" "key" {
  display_name  = "${module.bucket.bucket_name}-key"
  description   = "Use of the KMS key of the OBS bucket ${module.bucket.bucket_name} for its project's members."
  display_layer = "project"

  statement {
    effect = "Allow"
    action = ["kms:cmk:list", "kms:cmk:get"]
  }

  statement {
    effect   = "Allow"
    resource = ["KMS:*:*:KeyId:${data.opentelekomcloud_kms_key_v1.bucket.id}"]
    action   = ["kms:cmk:generate", "kms:dek:create", "kms:cmk:crypto", "kms:dek:crypto"]
  }
}

resource "opentelekomcloud_identity_role_assignment_v3" "bucket" {
  for_each = var.group_access

  group_id   = data.opentelekomcloud_identity_group_v3.project[each.key].id
  project_id = data.opentelekomcloud_identity_project_v3.obs.id
  role_id    = opentelekomcloud_identity_role_v3.bucket[each.value].id
}

resource "opentelekomcloud_identity_role_assignment_v3" "key" {
  for_each = var.group_access

  group_id   = data.opentelekomcloud_identity_group_v3.project[each.key].id
  project_id = data.opentelekomcloud_identity_project_v3.region.id
  role_id    = opentelekomcloud_identity_role_v3.key.id
}
