output "resolved_tags" {
  description = "The three TAG inputs as meshStack resolved them for this run."
  value = {
    project        = var.project_tag
    payment_method = var.payment_method_tag
    landing_zone   = var.landing_zone_tag
    run_marker     = var.run_marker
  }
}
