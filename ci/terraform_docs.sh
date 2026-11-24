#!/usr/bin/env bash
# Reference architecture READMEs are written by hand, so only hub module
# backplanes and building blocks are covered.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
config="$PWD/.terraform-docs.yml"

# terraform-docs cannot parse a variable inside a module `source`:
# https://github.com/terraform-docs/terraform-docs/issues/793
excluded='^modules/(ske/forgejo-connector|stackit/git-repository)/buildingblock/'

git ls-files -- 'modules/*.tf' |
  grep -E '^modules/[^/]+/[^/]+/(backplane|buildingblock)/.+\.tf$' |
  grep -Ev "$excluded" |
  xargs -n1 dirname |
  sort -u |
  while read -r dir; do
    readme="$dir/README.md"
    if [[ -f "$readme" ]] && grep -q '<!-- BEGIN_TF_DOCS -->' "$readme"; then
      terraform-docs --config="$config" "$dir" >/dev/null
    fi
  done
