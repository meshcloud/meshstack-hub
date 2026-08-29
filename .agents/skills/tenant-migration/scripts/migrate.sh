#!/usr/bin/env bash
# migrate.sh <workspace> <project> <old-bb-uuid|-> <expected-stackit-project-id>
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/env.sh" || exit 1
set -u
WS=$1; PROJ=$2; OLDBB=$3; PID=$4

# The building block definition the new tenant's landing zone makes mandatory. Instance-specific.
: "${MIG_NEW_BBD_UUID:?set MIG_NEW_BBD_UUID to the building block definition of the target landing zone}"
NEWDEF=$MIG_NEW_BBD_UUID
say(){ echo "  $*"; }

echo "=== $WS/$PROJ -> likvid-stackit.global ==="

# 1. capture and disarm the old block
if [ "$OLDBB" != "-" ]; then
  curl -s -H "Authorization: Bearer $MT" \
    "$MESH/api/terraform/state/workspace/$WS/buildingBlock/$OLDBB" > /tmp/mig-old.json
  got=$(jq -r '.resources[]|select(.type=="stackit_resourcemanager_project")|.instances[0].attributes.project_id' /tmp/mig-old.json)
  [ "$got" = "$PID" ] || { echo "ABORT: state holds $got, expected $PID"; exit 1; }
  jq -f "$HERE/reseed.jq" /tmp/mig-old.json > /tmp/mig-seed.json
  say "seed state: $(jq -r '[.resources[]|"\(.name)(\(.instances|length))"]|join(" ")' /tmp/mig-seed.json)"
  say "purge old block -> $(curl -s -X DELETE -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $MT" -H "$BBACC" \
    "$MESH/api/meshobjects/meshbuildingblocks/$OLDBB/purge")"
  sleep 8
else
  [ -s /tmp/mig-seed.json ] || { echo "ABORT: no /tmp/mig-seed.json prepared"; exit 1; }
  say "using externally prepared seed state"
fi

# 2. delete the old tenant
say "delete old tenant -> $(curl -s -X DELETE -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $MT" \
  -H "Accept: application/vnd.meshcloud.api.meshtenant.v3.hal+json" \
  "$MESH/api/meshobjects/meshtenants/$WS.$PROJ.stackit.sovereign")"
sleep 10

# 3. create the new tenant and seed its block's state before the runner starts
before=$(curl -s -H "Authorization: Bearer $MT" -H "$BBACC" \
  "$MESH/api/meshobjects/meshbuildingblocks?definitionUuid=$NEWDEF&size=200" \
  | jq -r '._embedded.meshBuildingBlocks[]?.metadata.uuid' | sort | tr '\n' ' ')
printf '{"apiVersion":"v3","kind":"meshTenant","metadata":{"ownedByWorkspace":"%s","ownedByProject":"%s","platformIdentifier":"likvid-stackit.global"},"spec":{"landingZoneIdentifier":"likvid-stackit-default"}}' \
  "$WS" "$PROJ" > /tmp/mig-ten.json
code=$(curl -s -o /tmp/mig-ten-out.json -w '%{http_code}' -X POST -H "Authorization: Bearer $MT" \
  -H "Content-Type: application/vnd.meshcloud.api.meshtenant.v3.hal+json" \
  -H "Accept: application/vnd.meshcloud.api.meshtenant.v3.hal+json" \
  --data-binary @/tmp/mig-ten.json "$MESH/api/meshobjects/meshtenants")
say "create new tenant -> $code"
[ "$code" = 201 ] || { head -c 300 /tmp/mig-ten-out.json; exit 1; }

BB=""
for i in $(seq 1 60); do
  sleep 0.5
  BB=$(curl -s -H "Authorization: Bearer $MT" -H "$BBACC" \
    "$MESH/api/meshobjects/meshbuildingblocks?definitionUuid=$NEWDEF&size=200" \
    | jq -r --argjson b "$(printf '%s' "$before" | jq -R 'split(" ")|map(select(length>0))')" \
        '[._embedded.meshBuildingBlocks[]?.metadata.uuid] - $b | .[0] // empty')
  [ -n "$BB" ] && break
done
[ -n "$BB" ] || { echo "ABORT: new block not found"; exit 1; }
say "seed state into $BB -> $(curl -s -o /dev/null -w '%{http_code}' -X POST -H "Authorization: Bearer $MT" \
  -H "Content-Type: application/json" --data-binary @/tmp/mig-seed.json \
  "$MESH/api/terraform/state/workspace/$WS/buildingBlock/$BB")"
echo "$BB" > /tmp/mig-bb

# 4. wait, then verify
for i in $(seq 1 40); do
  s=$(curl -s -H "Authorization: Bearer $MT" -H "$BBACC" "$MESH/api/meshobjects/meshbuildingblocks/$BB" | jq -r '.status.status')
  case "$s" in SUCCEEDED|FAILED) break;; esac
  sleep 15
done
say "run -> $s"
say "block project_id  = $(curl -s -H "Authorization: Bearer $MT" -H "$BBACC" "$MESH/api/meshobjects/meshbuildingblocks/$BB" | jq -r '.status.outputs.project_id.value')"
say "tenant localId    = $(curl -s -H "Authorization: Bearer $MT" -H 'Accept: application/vnd.meshcloud.api.meshtenant.v3.hal+json' \
  "$MESH/api/meshobjects/meshtenants/$WS.$PROJ.likvid-stackit.global" | jq -r '.spec.localId')"
say "expected          = $PID"
stackit project describe "$PID" 2>&1 | grep -E 'NAME|STATE|PARENT' | sed 's/^/  /'
