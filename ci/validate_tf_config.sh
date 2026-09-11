#!/usr/bin/env bash
# Rejects a module whose configuration OpenTofu cannot load - duplicate
# declarations, syntax errors, unknown blocks. `tofu validate` reports those on
# an *uninitialized* directory, so this needs no provider downloads and no
# network: the whole repo checks in about three seconds. A full
# `terraform_validate` hook was tried before and dropped, because initializing
# ~160 module directories is far too slow to sit in front of every commit.
set -uo pipefail

cd "$(dirname "$0")/.."

command -v tofu > /dev/null || {
	echo "tofu is not on PATH - run this from 'nix develop'"
	exit 1
}

# An empty data directory keeps every run uninitialized, so a developer who has
# already run `tofu init` somewhere sees the same diagnostics as CI.
TF_DATA_DIR="$(mktemp -d)"
export TF_DATA_DIR
trap 'rm -rf "$TF_DATA_DIR"' EXIT

# Diagnostics only `tofu init` could settle: a provider schema, an installed
# child module, or a module source that interpolates a variable (hub modules
# pin their children at var.hub.git_ref). None of them judges the configuration.
report_load_errors='
  def needs_init($summary):
    [ "Missing required provider",
      "missing or corrupted provider plugins",
      "Module not installed",
      "Unable to compute static value",
      "Failed to request input from user"
    ] | any(. as $prefix | $summary | startswith($prefix));
  .diagnostics[]?
  | select(needs_init(.summary) | not)
  | "  \(.range.filename // "?"):\(.range.start.line // 0): \(.summary). \(.detail)"
'

status=0
for dir in $(printf '%s\n' "$@" | xargs -n1 dirname | sort -u); do
	# A commit that deletes a module still lists its files, and a directory left
	# with no .tf at all is not a module tofu can be asked about.
	[[ -n $(find "$dir" -maxdepth 1 -name '*.tf' -print -quit 2> /dev/null) ]] || continue

	# Anything tofu reports that jq cannot read is a failure, not a pass: a gate
	# that goes quiet when the tooling breaks is worse than no gate.
	report=$(cd "$dir" && tofu validate -json < /dev/null)
	if ! errors=$(jq -r "$report_load_errors" <<< "$report"); then
		echo "$dir: could not read tofu's diagnostics"
		echo "$report"
		status=1
	elif [[ -n "$errors" ]]; then
		echo "$dir"
		echo "$errors"
		status=1
	fi
done

exit $status
