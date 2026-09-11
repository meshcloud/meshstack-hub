# The backplane only exists in hub mode, so its providers are configured here rather than in the
# root. Foundation mode then never installs the aws provider at all.
#
# A module holding a provider block may not take `count`, `for_each` or `depends_on` — so keep those
# off the `module "definition"` block in the root.
#
# Credentials come from the environment: the CI role in the smoke-test account, or the developer's
# own session locally. allowed_account_ids turns a wrong session into an error instead of an IAM
# role in someone else's account.
provider "aws" {
  region              = var.test_context.fixtures.aws.region
  allowed_account_ids = [var.test_context.fixtures.aws.account_id]
}

# Nothing is created through this one: the fixture account has no organization, so the backplane
# deploys no StackSet. It is configured because the module declares the alias.
provider "aws" {
  alias               = "management"
  region              = var.test_context.fixtures.aws.region
  allowed_account_ids = [var.test_context.fixtures.aws.account_id]
}
