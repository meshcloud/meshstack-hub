---
name: meshStack Environment Variable Audit
supportedPlatforms:
  - meshstack
description: Validates that the building block runner provides a clean, minimal environment with no unexpected environment variables.
---
# meshStack Environment Variable Audit

This building block verifies that the building block runner exposes only the expected set of environment variables. It acts as a canary test for the runner's environment isolation guarantees.

The pre-run script compares every environment variable present at runtime against a fixed whitelist. If any unlisted variable is found, the building block fails with a descriptive error that is surfaced to the user.

## How it works

The pre-run script runs **after** `tofu init` and **before** `tofu apply`. It:

1. Enumerates all currently set environment variables via `compgen -e`
2. Checks each one against the whitelist defined in `prerun.sh`
3. Exits non-zero and writes a user-facing error message if any unexpected variable is present

This building block provisions no cloud resources — the audit is the sole purpose.
