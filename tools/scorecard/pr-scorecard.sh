#!/usr/bin/env bash
# Runs the scorecard on all modules that changed relative to a base git ref.
# Progress is written to stderr; the markdown report goes to stdout (or --output file).
set -euo pipefail

BASE_REF="origin/main"
OUTPUT_FILE=""

for arg in "$@"; do
  case "$arg" in
    --base=*)   BASE_REF="${arg#--base=}" ;;
    --output=*) OUTPUT_FILE="${arg#--output=}" ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

MODULES=$(git diff --name-only "${BASE_REF}...HEAD" \
  | grep '^modules/' \
  | sed 's|^modules/\([^/]*/[^/]*\)/.*|\1|' \
  | sort -u || true)

emit() {
  if [ -n "$OUTPUT_FILE" ]; then
    printf '%s\n' "$@" >> "$OUTPUT_FILE"
  else
    printf '%s\n' "$@"
  fi
}

[ -n "$OUTPUT_FILE" ] && : > "$OUTPUT_FILE"

if [ -z "$MODULES" ]; then
  emit "_No module changes detected relative to \`${BASE_REF}\`._"
  exit 0
fi

emit "> Scorecard run on commit \`$(git rev-parse HEAD)\` relative to \`${BASE_REF}\`"
emit ""

# Separate existing modules from deleted ones, build --module args for a single invocation.
MODULE_ARGS=()
while IFS= read -r MODULE; do
  [ -z "$MODULE" ] && continue
  if [ -d "modules/$MODULE" ]; then
    MODULE_ARGS+=("--module=$MODULE")
  else
    emit "### \`${MODULE}\`" "" "_Module directory not found (deleted?)._" ""
  fi
done <<< "$MODULES"

if [ ${#MODULE_ARGS[@]} -gt 0 ]; then
  echo "Running scorecard for: ${MODULE_ARGS[*]#--module=}" >&2
  node "$SCRIPT_DIR/scorecard.mjs" "${MODULE_ARGS[@]}" 2>&1 | {
    if [ -n "$OUTPUT_FILE" ]; then cat >> "$OUTPUT_FILE"; else cat; fi
  } || true
fi
