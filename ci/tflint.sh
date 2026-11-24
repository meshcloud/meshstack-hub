#!/usr/bin/env bash
# Lints every module root with the rulesets pinned in .tflint.hcl.
#
# tflint cannot load a module `source` that holds an interpolation. So this lints
# a copy of the working tree in which each source carries a literal, and an output
# in the copy still references each replaced expression, so none turns unused.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v tflint > /dev/null || {
	echo "tflint is not on PATH"
	exit 1
}

roots=(modules infra reference-architectures)
ref=${GITHUB_SHA:-$(git rev-parse HEAD)}
jobs="${TFLINT_JOBS:-$(( $(nproc 2> /dev/null || sysctl -n hw.ncpu) * 2 ))}"

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

# Tracked and untracked files as they are on disk, so local changes are linted too.
git ls-files -z --cached --others --exclude-standard -- .tflint.hcl "${roots[@]}" |
	while IFS= read -r -d '' f; do [[ -e $f ]] && printf '%s\0' "$f"; done |
	tar --null -T - -cf - | tar -xf - -C "$workdir"

source_line='^[[:space:]]*source[[:space:]]*='
while IFS= read -r file; do
	dir=$(dirname "$file")
	grep -E "$source_line" "$file" | grep -oE '\$\{[^}]*\}' | sed -E 's/^\$\{[[:space:]]*//; s/[[:space:]]*\}$//' >> "$dir/.tflint-source-refs"
	sed -i -E "/$source_line/{
		s/\\$\\{[[:space:]]*var\\.hub\\.git_ref[[:space:]]*\\}/$ref/g
		s/\\$\\{[[:space:]]*var\\.hub_git_ref[[:space:]]*\\}/$ref/g
		s/\\$\\{[[:space:]]*local\\.mode[[:space:]]*\\}/hub/g
	}" "$file"
done < <(grep -rlE --include='*.tf' "$source_line.*\\$\\{" "$workdir")

if leftover=$(grep -rnE --include='*.tf' "$source_line.*\\$\\{" "$workdir"); then
	echo "ci/tflint.sh cannot rewrite these module sources, teach it the new pattern:"
	echo "${leftover//"$workdir/"/}"
	exit 1
fi

while IFS= read -r refs; do
	{
		echo 'output "tflint_source_refs" {'
		echo '  description = "Expressions ci/tflint.sh replaced in module sources."'
		echo "  value       = [$(sort -u "$refs" | paste -sd, -)]"
		echo '}'
	} > "$(dirname "$refs")/tflint_source_refs.tf"
	rm "$refs"
done < <(find "$workdir" -name .tflint-source-refs)

cd "$workdir"
tflint --init --config="$workdir/.tflint.hcl"
status=0
output=$(tflint --recursive --config="$workdir/.tflint.hcl" --max-workers="$jobs" --format=compact --no-color) || status=$?
[[ -n $output ]] && echo "$output"

if [[ -n ${GITHUB_ACTIONS:-} ]]; then
	# compact: <file>:<line>:<col>: <Severity> - <message> (<rule>)
	sed -nE 's/^([^:]+):([0-9]+):([0-9]+): (Error|Warning|Notice) - (.*) \(([a-z0-9_]+)\)$/::\L\4\E file=\1,line=\2,col=\3,title=\6::\5/p' <<< "$output"
fi

exit "$status"
