#!/bin/bash

# CLI output colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

errors=()
warnings=()

# Check if Terraform is installed
if ! command -v terraform >/dev/null 2>&1; then
	echo -e "${RED}Error:${NC} Terraform is not installed or not in PATH"
	exit 1
fi

check_readme_format() {
	local readme_path="$1"

	if [[ ! -f "$readme_path" ]]; then
		errors+=("README.md not found at $readme_path")
		return 1
	fi

	# Check for valid YAML front matter
	if ! awk '/^---/{f=1; next} /^---$/{if(f){exit 0}} END{exit 1}' "$readme_path"; then
		errors+=("README.md at $readme_path does not have a valid YAML front matter block (start and end with '---')")
		return 1
	fi

	# Extract YAML block
	local yaml_header
	yaml_header=$(awk '/^---/{f=1; next} /^---$/{f=0} f' "$readme_path")

	# Check for required fields
	if ! grep -q "name:" <<< "$yaml_header"; then
		errors+=("Missing 'name' in YAML header of README.md at $readme_path")
	fi
	if ! grep -q "supportedPlatforms:" <<< "$yaml_header"; then
		errors+=("Missing 'supportedPlatforms' in YAML header of README.md at $readme_path")
	fi
	if ! grep -q "description:" <<< "$yaml_header"; then
		errors+=("Missing 'description' in YAML header of README.md at $readme_path")
	fi

	return 0
}

check_png_naming() {
	local png_path="$1"
	local png_name
	png_name=$(basename "$png_path")

	if [[ "$png_name" != "logo.png" ]]; then
		warnings+=("PNG file '$png_name' should be named 'logo.png' to be importable in meshStack (path: $png_path)")
	fi
}

check_terraform_files() {
	local buildingblock_path="$1"

	# Check if any .tf files exist
	if ! find "$buildingblock_path" -maxdepth 1 -name '*.tf' | grep -q .; then
		errors+=("No Terraform (.tf) files found in $buildingblock_path")
		return 1
	fi

	# Optional: Check for recommended files
	local required_tf_files=("main.tf" "variables.tf" "outputs.tf" "provider.tf" "versions.tf")
	for tf_file in "${required_tf_files[@]}"; do
		if [[ ! -f "$buildingblock_path/$tf_file" ]]; then
			warnings+=("Recommended file '$tf_file' is missing in $buildingblock_path")
		fi
	done

	# Validate Terraform configuration
	pushd "$buildingblock_path" > /dev/null || return 1

	if ! terraform init -backend=false -input=false > /dev/null 2>&1; then
		errors+=("Terraform init failed in $buildingblock_path")
	elif ! terraform validate > /dev/null 2>&1; then
		errors+=("Terraform validate failed in $buildingblock_path")
	fi

	popd > /dev/null || return 1
}

# Ensure the script is run from repo root
cd "$(dirname "$0")/.." || exit 1
modules_path="modules"

if [[ ! -d "$modules_path" ]]; then
	echo -e "${RED}Error:${NC} Modules folder not found at $modules_path"
	exit 1
fi

modules_glob="$modules_path/*/*/buildingblock"

# Check all README.md files
find $modules_glob -name 'README.md' -print0 | while IFS= read -r -d '' readme_file; do
	check_readme_format "$readme_file"
done

# Check all PNG files
find $modules_glob -name '*.png' -print0 | while IFS= read -r -d '' png_file; do
	check_png_naming "$png_file"
done

# Check all Terraform buildingblock directories
find $modules_glob -type d -name 'buildingblock' -print0 | while IFS= read -r -d '' buildingblock_dir; do
	check_terraform_files "$buildingblock_dir"
done

# Print results
echo ""
echo "Number of errors: ${#errors[@]}"
echo "Number of warnings: ${#warnings[@]}"
echo ""

if [[ ${#errors[@]} -gt 0 ]]; then
	echo -e "${RED}Errors found:${NC}"
	for error in "${errors[@]}"; do
		echo -e "- $error"
	done
	echo ""
	exit 1
elif [[ ${#warnings[@]} -gt 0 ]]; then
	echo -e "${YELLOW}Warnings found:${NC}"
	for warning in "${warnings[@]}"; do
		echo -e "- $warning"
	done
	echo ""
	exit 0
else
	echo "✅ All checks passed successfully."
	exit 0
fi
