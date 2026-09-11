#!/usr/bin/env bash
# Loads every module against real provider schemas: `tofu init -backend=false`
# followed by `tofu validate`. This catches what a schema-less check cannot -
# unknown resource attributes, references to undeclared variables and locals,
# resource types a provider does not have, missing provider configurations.
#
# Three things keep it inside a two-minute CI job:
#   * one plugin cache for the whole run, so each provider version is fetched
#     once instead of once per directory,
#   * TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE, without which OpenTofu
#     re-fetches every provider it cannot match against a committed lock file -
#     and this repo commits none. The "break" is writing a lock file that only
#     covers this machine's platform; we throw those away.
#   * the directories are independent, so they run in parallel.
set -uo pipefail
cd "$(dirname "$0")/.."

command -v tofu > /dev/null || {
	echo "tofu is not on PATH"
	exit 1
}

known_failures=ci/validate_tf_full_known_failures.txt
jobs="${VALIDATE_JOBS:-$(( $(nproc 2> /dev/null || sysctl -n hw.ncpu) * 2 ))}"

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$workdir/plugins}"
export TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE=1
mkdir -p "$TF_PLUGIN_CACHE_DIR"

# e2e roots take their child module's git ref from a test variable, so their
# module tree cannot be resolved without running the test. The renderer's
# templates and testdata are inputs to a Go tool, not modules. Both stay on the
# schema-less check in .pre-commit-config.yaml, which needs neither.
dirs=$(find . -name '*.tf' \
	-not -path './.git/*' \
	-not -path '*/.terraform/*' \
	-not -path './.claude/*' \
	-not -path './node_modules/*' \
	-not -path './website/*' \
	-not -path './tools/render-meshstack-integration-tf/templates/*' \
	-not -path './tools/render-meshstack-integration-tf/testdata/*' \
	-not -path '*/e2e/*' \
	-print0 | xargs -0 -n1 dirname | sort -u)

validate_dir() {
	local dir="$1" log="$workdir/$(tr '/' '_' <<< "${1#./}").log"
	# The provider registry occasionally resets a connection under this many
	# parallel inits. One retry costs a second and removes the flake.
	(cd "$dir" && { tofu init -backend=false -input=false -no-color ||
		tofu init -backend=false -input=false -no-color; } &&
		tofu validate -no-color) > "$log" 2>&1 ||
		echo "${dir#./}" >> "$workdir/failed"
}
export -f validate_dir
export workdir

xargs -P "$jobs" -I{} bash -c 'validate_dir "$@"' _ {} <<< "$dirs"

touch "$workdir/failed"
sort -o "$workdir/failed" "$workdir/failed"
sed 's/#.*//; s/[[:space:]]*$//' "$known_failures" | grep -v '^$' | sort > "$workdir/known"

status=0
while read -r dir; do
	echo "::error::$dir does not load"
	cat "$workdir/$(tr '/' '_' <<< "$dir").log"
	status=1
done < <(comm -23 "$workdir/failed" "$workdir/known")

while read -r dir; do
	echo "::notice::$dir loads now - drop it from $known_failures"
done < <(comm -13 "$workdir/failed" "$workdir/known")

exit $status
