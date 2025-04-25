#!/bin/bash

errors=()

check_readme_format() {
	local readme_path="$1"
	if [[ ! -f "$readme_path" ]]; then
		errors+=("README.md not found at $readme_path")
		return 1
	fi

	if ! grep -q "^---" "$readme_path"; then
		errors+=("Missing '---' at the beginning of the README.md at $readme_path")
	fi
	if ! grep -q "name: " "$readme_path"; then
		errors+=("Missing 'name' in README.md at $readme_path")
	fi
	if ! grep -q "supportedPlatforms:" "$readme_path"; then
		errors+=("Missing 'supportedPlatforms' in README.md at $readme_path")
	fi
	if ! grep -q "description:" "$readme_path"; then
		errors+=("Missing 'description' in README.md at $readme_path")
	fi
	if ! grep -q "^---$" "$readme_path"; then
		errors+=("Missing ending '---' in README.md at $readme_path")
	fi
	return 0
}

check_png_naming() {
	local png_path="$1"
	local png_name=$(basename "$png_path")
	if [[ "$png_name" != "logo.png" ]]; then
		errors+=("Warning: PNG file '$png_name' should be named 'logo.png' to be importable in meshStack")
	fi
}

check_terraform_files() {
	local buildingblock_path="$1"
	local tf_files=("main.tf" "variables.tf" "outputs.tf")

	for tf_file in "${tf_files[@]}"; do
		if [[ ! -f "$buildingblock_path/$tf_file" ]]; then
			errors+=("Error: '$tf_file' not found in $buildingblock_path")
		fi
	done
	return 0
}

# Ensure it is called from the repo root
cd "$(dirname "$0")/.."
modules_path="modules"

if [[ ! -d "$modules_path" ]]; then
	echo "Error: Modules folder not found at $modules_path"
	exit 1
fi

modules_glob="$modules_path/*/*/buildingblock"

for readme_file in $(find $modules_glob -name 'README.md'); do
	check_readme_format "$readme_file"
done

for png_file in $(find $modules_glob -name '*.png'); do
	check_png_naming "$png_file"
done

for buildingblock_dir in $(find $modules_glob -type d -name 'buildingblock'); do
	check_terraform_files "$buildingblock_dir"
done

echo "Number of errors: ${#errors[@]}"
if [[ ${#errors[@]} -gt 0 ]]; then
	echo "Errors found:"
	for error in "${errors[@]}"; do
		echo "- $error"
	done
	exit 1
else
	echo "All checks passed successfully."
	exit 0
fi
