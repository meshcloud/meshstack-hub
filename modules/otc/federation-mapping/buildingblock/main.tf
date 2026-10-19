# What the function acts as. Its token calls IAM and its temporary AK/SK reads the bucket.
resource "opentelekomcloud_identity_agency_v3" "function" {
  name                  = var.name
  description           = "Lets the meshStack federation mapping function rebuild the identity provider mapping."
  delegated_domain_name = "op_svc_cff"
  domain_roles          = ["Security Administrator", "OBS ReadOnlyAccess"]
}

# FunctionGraph collects no logs unless the function names a log group and stream.
resource "opentelekomcloud_lts_group_v2" "function" {
  group_name  = var.name
  ttl_in_days = var.log_retention_days
}

resource "opentelekomcloud_lts_stream_v2" "function" {
  group_id    = opentelekomcloud_lts_group_v2.function.id
  stream_name = var.name
}

resource "opentelekomcloud_fgs_function_v2" "this" {
  name        = var.name
  app         = "default"
  description = "Rebuilds the ${var.identity_provider_name} mapping from the project membership records in ${var.mapping_bucket}."
  runtime     = "Python3.10"
  handler     = "index.handler"
  code_type   = "inline"
  func_code   = base64encode(file("${path.module}/function/index.py"))
  memory_size = 128
  timeout     = 60

  agency     = opentelekomcloud_identity_agency_v3.function.name
  app_agency = opentelekomcloud_identity_agency_v3.function.name

  # Each run rebuilds the whole mapping, so one at a time is enough and keeps two runs from
  # interleaving their reads and writes. An event dropped meanwhile is covered by the next one, or
  # by the timer.
  max_instance_num = "1"

  enable_lts_log = true
  log_group_id   = opentelekomcloud_lts_group_v2.function.id
  log_group_name = opentelekomcloud_lts_group_v2.function.group_name
  log_topic_id   = opentelekomcloud_lts_stream_v2.function.id
  log_topic_name = opentelekomcloud_lts_stream_v2.function.stream_name

  user_data = jsonencode({
    REGION            = var.region
    IAM_ENDPOINT      = "https://iam.${var.region}.otc.t-systems.com/v3"
    MAPPING_BUCKET    = var.mapping_bucket
    IDENTITY_PROVIDER = var.identity_provider_name
    EMAIL_ATTRIBUTE   = var.email_attribute
    BASE_GROUP        = var.base_group
  })
}

resource "opentelekomcloud_fgs_trigger_v2" "bucket" {
  function_urn = opentelekomcloud_fgs_function_v2.this.urn
  type         = "OBS"
  event_data = jsonencode({
    name   = var.name
    bucket = var.mapping_bucket
    events = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    prefix = "mappings/"
    suffix = ".json"
  })
}

resource "opentelekomcloud_fgs_trigger_v2" "resync" {
  function_urn = opentelekomcloud_fgs_function_v2.this.urn
  type         = "TIMER"
  event_data = jsonencode({
    name          = "${var.name}-resync"
    schedule_type = "Cron"
    schedule      = var.resync_schedule
    user_event    = "resync"
  })
}
