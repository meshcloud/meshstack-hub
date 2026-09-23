#!/usr/bin/env bash
# An `output` block cannot fan out over a map, so one `app_link_<stage>` output is generated per stage.

run_json=$(cat)

stages=$(
  echo "$run_json" |
    jq -r '.spec.buildingBlock.spec.inputs[] | select(.key == "landing_zone_refs") | .value' |
    jq -r 'keys[]'
)

if [ -z "$stages" ]; then
  echo "No landing_zone_refs input found — writing no stage outputs."
  exit 0
fi

target="meshstack_stage_outputs.tf"
: >"$target"

for stage in $stages; do
  # shellcheck disable=SC2016
  printf 'output "app_link_%s" {\n  description = "Public URL for the %s stage application."\n  value       = "https://${local.app_hostnames["%s"]}"\n}\n\n' \
    "$stage" "$stage" "$stage" >>"$target"
done

echo "Wrote $target for stages: $(echo "$stages" | tr '\n' ' ')"
