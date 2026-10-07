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

echo "--- Tools ---"
echo "Terraform takes the aws cli from this building block's flake, which needs nix on the runner"
command -v nix >/dev/null || { echo "nix not found: this building block needs nix on the runner" >&2; exit 1; }
nix --version
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