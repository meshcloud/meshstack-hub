# Builds the definition from hub source with an ephemeral backplane in the fixture AWS account.
variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    run_id      = string

    fixtures = object({
      aws = object({
        account_id = string
        region     = string

        # The account's shared OIDC provider for the meshStack runner issuer. AWS permits one per
        # issuer URL per account, so the harness owns it rather than each e2e run creating one.
        oidc_provider_arn = string
      })
    })
  })
  nullable = false
}

module "under_test" {
  source = "../../../"

  providers = {
    aws            = aws
    aws.management = aws.management
    meshstack      = meshstack
  }

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  bbd_display_name = "${var.test_context.run_id} AWS Budget Alert"

  aws_oidc_provider_arn        = var.test_context.fixtures.aws.oidc_provider_arn
  backplane_name               = "${var.test_context.run_id}-ba"
  aws_target_account_role_name = "${var.test_context.run_id}-ba-target"

  # The fixture is a plain member account, not an organization management account, so there is no OU
  # to distribute the target role to — the backplane creates it in the fixture account itself. That
  # still exercises the production credential chain: federate, then assume the target role.
  aws_target_ou_ids = []
}

output "version_ref" {
  value = module.under_test.building_block_definition.version_ref
}
