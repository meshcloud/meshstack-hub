#!/bin/bash

errors=()
fix_mode=false

# Check if --fix flag is passed
if [[ "$1" == "--fix" ]]; then
	fix_mode=true
fi

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

check_png_minimization() {
	local png_path="$1"

	# Get original file size
	local original_size
	if [[ -f "$png_path" ]]; then
		original_size=$(wc -c < "$png_path")
	else
		return 1
	fi

	# Create a temporary minimized version using pngquant
	local temp_minimized
	temp_minimized=$(mktemp)

	if pngquant --quality=100 --force --output "$temp_minimized" "$png_path" 2>/dev/null; then
		local minimized_size
		minimized_size=$(wc -c < "$temp_minimized")

		# Calculate percentage reduction and absolute savings
		local size_reduction=$(( (original_size - minimized_size) * 100 / original_size ))
		local savings_bytes=$(( original_size - minimized_size ))
		local savings_kib=$(( savings_bytes / 1024 ))
		local original_kib=$(( original_size / 1024 ))
		local minimized_kib=$(( minimized_size / 1024 ))

		# If more than 10% reduction is possible
		if [[ $size_reduction -gt 10 ]]; then
			if [[ "$fix_mode" == true ]]; then
				# In fix mode, replace the original with the minimized version
				mv "$temp_minimized" "$png_path"
				echo "Fixed: $png_path (${original_kib} KiB -> ${minimized_kib} KiB, saved ${savings_kib} KiB / $size_reduction%)"
			else
				# In validate mode, just report the issue
				errors+=("PNG at $png_path is not sufficiently minimized (${original_kib} KiB -> ${minimized_kib} KiB, save ${savings_kib} KiB / $size_reduction%)")
			fi
		else
			rm -f "$temp_minimized"
		fi
	else
		rm -f "$temp_minimized"
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
	check_png_minimization "$png_file"
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
	if [[ "$fix_mode" == true ]]; then
		echo "All PNGs are sufficiently minimized."
	else
		echo "All checks passed successfully."
	fi
	exit 0
fi
