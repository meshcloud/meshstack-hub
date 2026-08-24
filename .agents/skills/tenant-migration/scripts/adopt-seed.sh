#!/usr/bin/env bash
# adopt-seed.sh <workspace> <project> <container-id> <expected-project-id>
#
# Builds /tmp/mig-seed.json for a tenant that has no old building block, so `migrate.sh <ws> <proj> -
# <project-id>` has a seed state to push. Imports the live STACKIT project into the `adopt/` harness —
# a byte-identical copy of the hub module the runner executes — then normalises the result.
#
# It also adopts every project role assignment that already exists in STACKIT *and* that the run will
# manage. Replicator-created projects already carry `owner` / `editor` / `reader` grants, and a grant
# the run wants but the seed omits fails the whole run with "found a duplicate role assignment".
#
# The run's grants come from the meshProject's user bindings through `role_mapping`, so the set is
# computed here the same way instead of guessed. Grants outside that set — the legacy `project.*` and
# `ufw.*` roles, and `owner` / `editor` / `reader` given to somebody who is not a meshProject member —
# are deliberately left out, so the run never manages them and never removes them.
#
# It plans before it writes the seed and aborts if anything is replaced or destroyed. Either would cost
# the live STACKIT project or somebody's access. Creates are expected: they are the grants the
# meshProject calls for that STACKIT does not have yet.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS=$1; PROJ=$2; CONTAINER=$3; PID=$4

# Where new projects go and who the module manages them as. Both are instance-specific, so they come
# from the environment — a wrong parent container id creates the project in the wrong folder.
: "${MIG_PARENT_CONTAINER_ID:?set MIG_PARENT_CONTAINER_ID to the landing-zone folder container id}"
: "${MIG_SERVICE_ACCOUNT_EMAIL:?set MIG_SERVICE_ACCOUNT_EMAIL to the platform service account}"

# The runner executes OpenTofu 1.11.0, and OpenTofu refuses to read a state written by a newer
# version. The local binary is newer, so its version has to be rewritten out of the seed.
RUNNER_TOFU_VERSION=1.11.0

# The block's own role_mapping, and the meshStack role display names that produce its keys. Confirmed
# against the `users` input of a real run: Project Admin -> admin, Project User -> user,
# Project Reader -> reader.
ROLE_MAPPING='{"admin":["owner"],"reader":["reader"],"user":["editor"]}'
MESH_ROLES='{"Project Admin":"admin","Project User":"user","Project Reader":"reader"}'

cd "$HERE/adopt"
unset STACKIT_SERVICE_ACCOUNT_KEY_PATH
export STACKIT_SERVICE_ACCOUNT_KEY="$STACKIT_ORG_SERVICE_ACCOUNT_KEY"

# The meshProject's user bindings, which is what meshStack turns into the block's `users` input.
curl -sf -H "Authorization: Bearer $MT" \
  -H "Accept: application/vnd.meshcloud.api.meshprojectuserbinding.v3.hal+json" \
  "$MESH/api/meshobjects/meshprojectbindings/userbindings?projectIdentifier=$PROJ&workspaceIdentifier=$WS" \
  > /tmp/adopt-bindings.json
skipped=$(jq -r --argjson r "$MESH_ROLES" \
  '[._embedded.meshProjectUserBindings[]?.roleRef.name | select($r[.] == null)] | unique | join(", ")' \
  /tmp/adopt-bindings.json)
[ -n "$skipped" ] && echo "  NOTE: meshStack roles with no STACKIT mapping, ignored: $skipped"

jq -n --arg name "$PROJ" --argjson mapping "$ROLE_MAPPING" --argjson meshroles "$MESH_ROLES" \
  --arg parent "$MIG_PARENT_CONTAINER_ID" --arg sa "$MIG_SERVICE_ACCOUNT_EMAIL" \
  --slurpfile b /tmp/adopt-bindings.json '{
  parent_container_id: $parent,
  project_name: $name,
  service_account_email: $sa,
  labels: {},
  role_mapping: $mapping,
  users: ($b[0]._embedded.meshProjectUserBindings // []
    | map({subject: .subject.name, role: $meshroles[.roleRef.name]}) | map(select(.role != null))
    | group_by(.subject) | map({
        meshIdentifier: .[0].subject, username: .[0].subject, firstName: "-", lastName: "-",
        email: .[0].subject, euid: .[0].subject, roles: ([.[].role] | unique)
      }))
}' > /tmp/adopt.tfvars.json
echo "  meshProject members: $(jq -r '[.users[].email]|join(" ")' /tmp/adopt.tfvars.json)"

TFARGS=(-no-color -var-file=/tmp/adopt.tfvars.json -var "stackit_service_account_key=$STACKIT_SERVICE_ACCOUNT_KEY")

rm -f terraform.tfstate terraform.tfstate.backup
tofu import "${TFARGS[@]}" stackit_resourcemanager_project.project "$CONTAINER" >/dev/null
got=$(jq -r '.resources[]|select(.type=="stackit_resourcemanager_project")|.instances[0].attributes.project_id' terraform.tfstate)
[ "$got" = "$PID" ] || { echo "ABORT: imported $got, expected $PID"; exit 1; }

# Grants that already exist in STACKIT and that the run will manage. Everything else stays unmanaged.
stackit project member list --project-id "$PID" -o json > /tmp/adopt-members.json
jq -r --argjson mapping "$ROLE_MAPPING" --slurpfile v /tmp/adopt.tfvars.json '
  ([ $v[0].users[] | .email as $s | .roles[] | $mapping[.][] | "\($s):\(.)" ] | unique) as $wanted
  | [ .[] | "\(.subject):\(.role)" ] | unique | map(select(IN($wanted[]))) | .[]' \
  /tmp/adopt-members.json > /tmp/adopt-adopt-keys.txt

# The role assignment's import id is "<project-id>,<role>,<subject>".
while IFS= read -r key; do
  [ -n "$key" ] || continue
  tofu import "${TFARGS[@]}" \
    "stackit_authorization_project_role_assignment.role_assignments[\"$key\"]" \
    "$PID,${key##*:},${key%:*}" >/dev/null
  echo "  adopted $key"
done < /tmp/adopt-adopt-keys.txt

tofu plan "${TFARGS[@]}" > /tmp/adopt-plan.txt 2>&1
if grep -qE 'must be replaced|forces replacement' /tmp/adopt-plan.txt; then
  echo "ABORT: plan replaces a resource. See /tmp/adopt-plan.txt"; exit 1
fi
if grep -q '^No changes\.' /tmp/adopt-plan.txt; then
  echo "  plan: no changes"
elif grep -qE '^Plan: [0-9]+ to add, [0-9]+ to change, 0 to destroy\.$' /tmp/adopt-plan.txt; then
  echo "  plan: $(grep -E '^Plan: ' /tmp/adopt-plan.txt)"
  grep -E '^  # ' /tmp/adopt-plan.txt | sed 's/^/  /'
else
  echo "ABORT: plan destroys something. See /tmp/adopt-plan.txt"; tail -30 /tmp/adopt-plan.txt; exit 1
fi

jq --arg v "$RUNNER_TOFU_VERSION" \
  '.terraform_version = $v | .serial = 1 | .outputs = {} | .resources |= map(select((.instances|length) > 0))' \
  terraform.tfstate > /tmp/mig-seed.json
echo "  seed: $(jq -r '[.resources[]|"\(.name)(\(.instances|length))"]|join(" ")' /tmp/mig-seed.json), tofu $(jq -r .terraform_version /tmp/mig-seed.json)"
