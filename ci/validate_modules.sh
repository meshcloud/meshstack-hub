#!/bin/bash

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

errors=()
warnings=()

check_readme_format() {
	local readme_path="$1"

	if [[ ! -f "$readme_path" ]]; then
		errors+=("README.md not found at $readme_path")
		return 1
	fi

	# 1. Check that the first line is exactly ---
	local first_line
	first_line=$(head -n 1 "$readme_path")
	if [[ "$first_line" != "---" ]]; then
		errors+=("Missing starting '---' in README.md at $readme_path")
		return 1
	fi

	# 2. Find end of YAML block
	local end_line
	end_line=$(awk 'NR>1 && /^---$/ { print NR; exit }' "$readme_path")
	if [[ -z "$end_line" ]]; then
		errors+=("Missing closing '---' in README.md at $readme_path")
		return 1
	fi

	# 3. Extract YAML block
	local yaml
	yaml=$(head -n "$((end_line - 1))" "$readme_path" | tail -n +2)

	# 4. Check for required fields and that they are not empty

	# name
	if ! grep -q "^name:" <<< "$yaml"; then
		errors+=("Missing 'name:' field in YAML header of README.md at $readme_path")
	elif [[ -z $(grep "^name:" <<< "$yaml" | cut -d':' -f2 | xargs) ]]; then
		errors+=("Field 'name:' is empty in README.md at $readme_path")
	fi

	# supportedPlatforms
	if ! grep -q "^supportedPlatforms:" <<< "$yaml"; then
		errors+=("Missing 'supportedPlatforms:' field in YAML header of README.md at $readme_path")
	else
		local platforms_count
		platforms_count=$(awk '/^supportedPlatforms:/ {found=1; next} /^ *[^- ]/ {found=0} found && /^ *-/{count++} END{print count+0}' <<< "$yaml")
		if [[ "$platforms_count" -eq 0 ]]; then
			errors+=("Field 'supportedPlatforms:' is empty in README.md at $readme_path")
		fi
	fi

	# description
	if ! grep -q "^description:" <<< "$yaml"; then
		errors+=("Missing 'description:' field in YAML header of README.md at $readme_path")
	else
		local desc_start desc_content
		desc_start=$(awk '/^description:/ {print NR; exit}' <<< "$yaml")
		desc_content=$(echo "$yaml" | tail -n +"$((desc_start + 1))" | awk 'NF {print; exit}')
		if [[ -z "$desc_content" ]]; then
			errors+=("Field 'description:' is empty in README.md at $readme_path")
		fi
	fi
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

	# Check for at least one .tf file (excluding .terraform subfolder)
	if ! find "$buildingblock_path" -maxdepth 1 -type f -name '*.tf' | grep -q .; then
		errors+=("No Terraform (.tf) files found in $buildingblock_path")
		return 1
	fi

	# Optional recommended file check
	local recommended_tf_files=("main.tf" "variables.tf" "outputs.tf", "provider.tf" "versions.tf")
	for tf_file in "${recommended_tf_files[@]}"; do
		if [[ ! -f "$buildingblock_path/$tf_file" ]]; then
			warnings+=("Recommended file '$tf_file' is missing in $buildingblock_path")
		fi
	done

	# Run terraform init + validate with visible output
	pushd "$buildingblock_path" > /dev/null || return 1
	rm -rf .terraform/ > /dev/null 2>&1

	echo "🔄 Running terraform init in $buildingblock_path"
	if ! terraform init -backend=false -input=false; then
		echo -e "❌ ${RED}Terraform init failed in $buildingblock_path${NC}"
		errors+=("Terraform init failed in $buildingblock_path")
		popd > /dev/null
		return 1
	fi

	echo "🔄 Running terraform validate in $buildingblock_path"
	if terraform validate; then
		echo -e "✅ ${buildingblock_path} validated successfully"
	else
		echo -e "❌ ${RED}Terraform validate failed in $buildingblock_path${NC}"
		errors+=("Terraform validate failed in $buildingblock_path")
	fi

	popd > /dev/null
}

# Ensure script is run from repo root
cd "$(dirname "$0")/.." || exit 1
modules_path="modules"

if [[ ! -d "$modules_path" ]]; then
	echo -e "${RED}Error:${NC} Modules folder not found at $modules_path"
	exit 1
fi

modules_glob="$modules_path/*/*/buildingblock"

# Check README.md files only directly inside each buildingblock
for readme_file in $(find $modules_glob -maxdepth 1 -name 'README.md'); do
	check_readme_format "$readme_file"
done

# Check PNG files only directly inside each buildingblock
for png_file in $(find $modules_glob -maxdepth 1 -name '*.png'); do
	check_png_naming "$png_file"
done

Check each buildingblock directory
for buildingblock_dir in $(find $modules_glob -type d -name 'buildingblock'); do
	check_terraform_files "$buildingblock_dir"
done

# Output summary
echo ""
echo "Number of errors: ${#errors[@]}"
echo "Number of warnings: ${#warnings[@]}"
echo ""

if [[ ${#errors[@]} -gt 0 ]]; then
	echo -e "${RED}Errors:${NC}"
	for e in "${errors[@]}"; do
		echo "- $e"
	done
	exit 1
elif [[ ${#warnings[@]} -gt 0 ]]; then
	echo -e "${YELLOW}Warnings:${NC}"
	for w in "${warnings[@]}"; do
		echo "- $w"
	done
	exit 0
else
	echo "✅ All checks passed successfully."
	exit 0
fi

if [[ -n "$GITHUB_STEP_SUMMARY" ]]; then
  {
    echo "## 🧪 Module Validation Summary"
    echo ""
    echo "**Errors:** ${#errors[@]}"
    for e in "${errors[@]}"; do echo "- ❌ $e"; done
    echo ""
    echo "**Warnings:** ${#warnings[@]}"
    for w in "${warnings[@]}"; do echo "- ⚠️ $w"; done
    if [[ ${#errors[@]} -eq 0 && ${#warnings[@]} -eq 0 ]]; then
      echo "- ✅ All checks passed successfully."
    fi
  }
fi
