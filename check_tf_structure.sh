#!/bin/bash

set -e

warnings=()
recommended_tf_files=("main.tf" "variables.tf" "outputs.tf" "provider.tf" "versions.tf")

# Nur Verzeichnisse prüfen, in denen mindestens eine .tf-Datei liegt
for buildingblock_path in $(find . -type f -name "*.tf" -exec dirname {} \; | sort -u); do
  for tf_file in "${recommended_tf_files[@]}"; do
    if [[ ! -f "$buildingblock_path/$tf_file" ]]; then
      warnings+=("⚠️  '$tf_file' missing in $buildingblock_path")
    fi
  done
done

# Ausgabe & Exit-Code
if [ "${#warnings[@]}" -gt 0 ]; then
  for warn in "${warnings[@]}"; do
    echo "$warn"
  done
  exit 1
else
  echo "✅ All recommended Terraform files are present."
fi
