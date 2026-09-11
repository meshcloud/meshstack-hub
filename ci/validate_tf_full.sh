#!/usr/bin/env bash
# Loads every module against real provider schemas: `tofu init -backend=false`
# followed by `tofu validate`. This is what catches an unknown resource
# attribute, a reference to an undeclared variable or local, a resource type a
# provider does not have, a missing provider configuration - and also the plain
# duplicate declaration that a parser alone would find.
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

# The github provider declares its app_auth arguments required but reads them
# from these variables, so a module authenticating as a GitHub App does not load
# without them. No request is made: `validate` only decodes provider blocks.
export GITHUB_APP_ID=0 GITHUB_APP_INSTALLATION_ID=0 GITHUB_APP_PEM_FILE=validation-only

# An e2e root pins its child modules at var.test_context.hub_git_ref, and a
# module source must resolve statically, so it does not load without a context.
export TF_VAR_test_context
TF_VAR_test_context=$(jq -c --arg ref "$(git rev-parse HEAD)" \
	'del(._comment) | .hub_git_ref = $ref' ci/validate_tf_full_mock_context.json) || exit 1

# That ref exists only here - a pull_request build sits on a merge commit no
# branch points at - so the hub resolves to this working copy. A clone from a
# local path copies every object, so the commit is found and nothing is fetched
# over the network. Only e2e roots get this: everything else pins a real ref.
hub_worktree=$PWD

# Named roots rather than exclusions: every other .tf in the repo belongs to the
# renderer, to an agent worktree or to the website, and is not a module.
dirs=$(find modules infra reference-architectures -name '*.tf' \
	-not -path '*/.terraform/*' \
	-print0 | xargs -0 -n1 dirname | sort -u)

validate_dir() {
	local dir="$1" log="$workdir/$(tr '/' '_' <<< "$1").log"
	if [[ $dir == */e2e || $dir == */e2e/* ]]; then
		export GIT_CONFIG_COUNT=1
		export GIT_CONFIG_KEY_0="url.$hub_worktree/.insteadOf"
		export GIT_CONFIG_VALUE_0=https://github.com/meshcloud/meshstack-hub.git
	fi
	# The provider registry occasionally resets a connection under this many
	# parallel inits. One retry costs a second and removes the flake.
	(cd "$dir" && { tofu init -backend=false -input=false -no-color ||
		tofu init -backend=false -input=false -no-color; } &&
		tofu validate -no-color) > "$log" 2>&1 ||
		echo "$dir" >> "$workdir/failed"
}
export -f validate_dir
export workdir hub_worktree

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
