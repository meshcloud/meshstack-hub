#!/usr/bin/env bash
set -euo pipefail

echo "=== Environment Variable Audit ==="
echo "Verifying only expected environment variables are present..."

# Whitelist of environment variables supplied by the building-block runner.
#
# Note: building block input variables that are explicitly marked as env-vars in
# the building block definition are also injected at runtime with arbitrary names.
# Those are intentional and not covered by this static whitelist.
ALLOWED_ENV_VARS=(
  # Core system variables required for basic process operation (cleanSystemEnv)
  "HOME" "PATH" "PWD" "TMPDIR" "TMP" "TEMP"
  # Backwards-compat variables kept for pre-run script use cases (cleanSystemEnv)
  "SSH_KNOWN_HOSTS"     # SSH host key file location (Docker image)
  "NIX_CONFIG"          # Nix package manager config (Docker image)
  "MESHSTACK_ENDPOINT"  # meshStack API base URL (injected by platform)
  "CUSTOM_CA_CERTS_PATH" # Custom CA certificate path (Docker image)
  "TF_LOG" "TF_LOG_CORE" "TF_LOG_PROVIDER" "TF_LOG_PATH" # Terraform logging
  "CHECKPOINT_DISABLE"  # Disables Terraform checkpoint calls
  "TF_IN_AUTOMATION"    # Signals Terraform it runs in CI (set by tfexec)
  # Script-specific variable (buildScriptEnvironmentVariables)
  "MESHSTACK_USER_MESSAGE" # Path to user-facing message file
  # Optional: set by buildTfEnv when SSH-based git source authentication is used
  "GIT_SSH_COMMAND"
  # Variables set by bash itself when launching the script process
  "SHLVL" "_"
)

unexpected_vars=()
while IFS= read -r var; do
  found=false
  for allowed in "${ALLOWED_ENV_VARS[@]}"; do
    if [[ "$var" == "$allowed" ]]; then
      found=true
      break
    fi
  done
  [[ "$found" == false ]] && unexpected_vars+=("$var")
done < <(compgen -e)

if [[ ${#unexpected_vars[@]} -gt 0 ]]; then
  msg="ERROR: Unexpected environment variables detected."$'\n'
  msg+="The building-block runner provides a minimal, clean environment to prevent"$'\n'
  msg+="credential leakage from the host. The following variables are not on the"$'\n'
  msg+="whitelist and should not be present:"$'\n'
  for var in "${unexpected_vars[@]}"; do
    msg+="  - $var"$'\n'
  done
  msg+=$'\n'
  msg+="If these are building block inputs passed as env-vars (env: true in the BBD),"$'\n'
  msg+="this check is expected to fail — add those variable names to the whitelist."$'\n'
  msg+="Otherwise, investigate how these variables entered the runner environment."

  echo "$msg" >&2
  echo "$msg" >> "$MESHSTACK_USER_MESSAGE"
  exit 1
fi

echo "Environment audit passed: only expected variables are present."
