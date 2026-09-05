# Rewrite an old STACKIT Project block state into the new module's shape.
# Keeps the project resource untouched; merges every role-assignment resource
# into the new module's single `role_assignments` map, re-keyed "<subject>:<role>".
def assignments:
  [ .resources[] | select(.type == "stackit_authorization_project_role_assignment") ];
{
  version: .version,
  terraform_version: .terraform_version,
  serial: 1,
  lineage: .lineage,
  outputs: {},
  check_results: null,
  resources: (
    [ .resources[] | select(.type == "stackit_resourcemanager_project") ]
    + (if (assignments | length) == 0 then [] else
        [ { mode: "managed",
            type: "stackit_authorization_project_role_assignment",
            name: "role_assignments",
            provider: (assignments[0].provider),
            each: "map",
            instances: [ assignments[].instances[]
              | .index_key = (.attributes.subject + ":" + .attributes.role) ]
          } ]
      end)
  )
}
