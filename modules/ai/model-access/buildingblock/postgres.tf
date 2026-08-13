# The tenant's Postgres database and its owner user, inside the PostgreSQL Flex instance every tenant
# shares. `modules/stackit/postgresflex/buildingblock/database` was split out of that building block
# provider-free for exactly this call: it declares no provider of its own, so it inherits the
# `stackit` provider configured in provider.tf, and a module that carries its own provider
# configuration could not be called with `count` or `for_each` by any composition at all.
#
# `existing_instance_id` selects the submodule's database-only mode. It then creates
# `stackit_postgresflex_database` and `stackit_postgresflex_user` against the instance and touches
# nothing about the instance itself, which is what keeps tenant churn out of the shared server: every
# input describing the instance shape has no effect in that mode.
module "postgres" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/postgresflex/buildingblock/database?ref=${var.hub.git_ref}"

  project_id     = var.stackit_project_id
  stackit_region = local.stackit_region

  existing_instance_id = var.langfuse_postgres_instance_id

  database_name     = local.langfuse_postgres_database
  database_username = local.langfuse_postgres_username

  # `login` and nothing else. Langfuse runs its Postgres migrations with `prisma migrate deploy`,
  # which creates and alters tables inside a database the user owns and never creates a database, so
  # `createdb` would let a tenant create databases outside its own scope.
  database_user_roles = ["login"]
}
