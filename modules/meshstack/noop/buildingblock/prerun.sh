echo "=== meshStack Building Block Pre-Run Script ==="
echo "Running after 'tofu init', before 'tofu apply'"
echo ""

echo "--- Run Modes ---"
echo "Run mode APPLY/DESTROY is passed as a positional argument"
echo "Selected run mode: $1"
echo ""

echo "--- meshBuildingBlockRun JSON input ---"
echo "# Read stdin once and extract multiple fields:"
input=$(cat)
workspace_id=$(echo "$input" | jq -r '.spec.buildingBlock.spec.workspaceIdentifier')
buildingblock_uuid=$(echo "$input" | jq -r '.spec.buildingBlock.uuid')
echo "Workspace identifier: $workspace_id"
echo "Building Block UUID: $buildingblock_uuid"
echo ""

echo "--- Working Directory ---"
echo "Working directory: $(pwd)"
ls -lah
echo ""

echo "--- Tool Installation ---"
echo "Currently not supported via apk add, but coming soon, see https://feedback.meshcloud.io/feature-requests/p/building-block-should-support-aws-cli-and-other"
# sudo apk add aws-cli
echo ""

echo "--- Terraform State Manipulation ---"
echo "The tofu backend is already initialized and a workspace selected"
tofu show -no-color
echo ""

echo "--- Capturing System Logs ---"
echo "Stdout log message from pre-run script"
echo "Stderr log message from pre-run script" >&2
echo ""

echo "--- Capturing User Messages ---"
echo "User message from pre-run script" >> "$MESHSTACK_USER_MESSAGE"

echo "=== Pre-run script completed successfully ==="
echo "'tofu apply' will now execute."