#!/usr/bin/env bash
set -euo pipefail

crane_version="v0.22.1"
crane_sha256="0ab7a1d6932a213aed964ce97666c3077fe691c8606413674a8b3e0b9ec4cda0"
crane_archive="go-containerregistry_Linux_x86_64.tar.gz"

mkdir -p .crane
curl --silent --show-error --fail --location --output ".crane/${crane_archive}" \
  "https://github.com/google/go-containerregistry/releases/download/${crane_version}/${crane_archive}"
echo "${crane_sha256}  .crane/${crane_archive}" | sha256sum --check --strict
tar -xzf ".crane/${crane_archive}" -C .crane crane
rm ".crane/${crane_archive}"

.crane/crane version
