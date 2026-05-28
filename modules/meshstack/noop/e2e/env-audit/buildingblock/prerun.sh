#!/usr/bin/env bash
set -euo pipefail
compgen -e | sort > prerun_env_keys.txt
echo "Pre-run environment keys captured to prerun_env_keys.txt"
