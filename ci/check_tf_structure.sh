#!/bin/bash
set -e

warnings=()

# Required Terraform files
common_tf_files=("main.tf" "variables.tf" "outputs.tf" "provider.tf" "versions.tf")
readme_file="APP_TEAM_README.md"

# Find relevant module directories
mapfile -t paths_to_check < <(find modules/ -type d \( -path "*/buildingblock" -o -path "*/backplane" \))

if [ "${#paths_to_check[@]}" -eq 0 ]; then
  echo "❌ No Terraform module folders found."
  exit 1
fi

# Check each directory silently unless a file is missing
for path in "${paths_to_check[@]}"; do
  for tf_file in "${common_tf_files[@]}"; do
    if [[ ! -f "$path/$tf_file" ]]; then
      warnings+=("⚠️  '$tf_file' is missing in $path")
    fi
  done

  if [[ "$(basename "$path")" == "buildingblock" ]]; then
    if [[ ! -f "$path/$readme_file" ]]; then
      warnings+=("⚠️  '$readme_file' is missing in $path")
    fi
  fi
done

# Output only if something's wrong
if [ "${#warnings[@]}" -gt 0 ]; then
  echo "❌ Issues detected:"
  for warn in "${warnings[@]}"; do
    echo "$warn"
  done
  exit 1
else
  exit 0
fi
