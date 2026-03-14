#!/bin/bash

# meshStack Building Block Pre-Run Script - Reference Implementation

set -euo pipefail

echo "=== meshStack Building Block Pre-Run Script ==="
echo "Running after 'tofu init', before 'tofu apply'"
echo ""

echo "--- Run Modes ---"
echo "Run mode APPLY/DESTROY is passed as a positional argument"
echo "Selected run mode: $1"
echo ""

echo "--- meshBuildingBlockRun JSON input ---"
cat | jq -r '.spec.buildingBlock.spec.workspaceIdentifier'
echo ""

echo "--- Working Directory ---"
echo "Working directory: $(pwd)"
ls -lah
echo ""

echo "--- Tool Installation ---"
apk add aws-cli
echo ""

echo "--- Terraform State Manipulation ---"
echo "The tofu backend is already initialized and a workspace selected"
tofu state list
echo ""

echo "--- Capturing System Logs ---"
echo "Stdout log message from pre-run script"
echo "Stderr log message from pre-run script" >&2
echo ""

echo "--- Capturing User Messages ---"
echo "User message from pre-run script" >> "$MESHSTACK_USER_MESSAGE"

echo "=== Pre-run script completed successfully ==="
echo "'tofu apply' will now execute."