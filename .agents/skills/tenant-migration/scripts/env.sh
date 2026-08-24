# Credentials and API constants for the tenant migration. Source it, do not execute it.
#
#   source scripts/env.sh || return 1
#
# Set these three for your instance before sourcing. There are no defaults on purpose: the wrong
# instance here migrates the wrong tenants.
#
#   MIG_IAC_REPO   the IaC runtime repo whose setup-env.sh loads the meshStack API key from Vault
#   MIG_MESH_URL   the meshStack API base url
#   MIG_CLIENT_ID  the API key's client id, paired with the key that setup-env.sh exports
#
: "${MIG_IAC_REPO:?set MIG_IAC_REPO to the IaC runtime repo, e.g. ~/git/<org>/<org>-cloudfoundation}"
: "${MIG_MESH_URL:?set MIG_MESH_URL, e.g. https://federation.<instance>.meshcloud.io}"
: "${MIG_CLIENT_ID:?set MIG_CLIENT_ID to the meshStack API key client id}"

# It cds to the IaC repo first on purpose: setup-env.sh only works from the repo root, and agent shells
# reset the working directory between commands, which makes a bare `source ./setup-env.sh` fail silently.
cd "$MIG_IAC_REPO" || return 1
source ./setup-env.sh >/dev/null 2>&1

# setup-env.sh falls back to an interactive `vault login -method=oidc`, which cannot complete in a
# non-interactive shell — it then carries on with no secrets at all. Catch that here, because the
# alternative is a 401 that jq renders as an empty list, i.e. "no tenants exist".
if [ -z "$MESHSTACK_API_KEY_CLOUDFOUNDATION" ]; then
  echo "FATAL: vault secrets not loaded. Run 'source ./setup-env.sh' in a terminal to do the OIDC login." >&2
  return 1
fi

export MESH="$MIG_MESH_URL"

# /api/login only issues a redirect; the token has to come from keycloak directly. The sso host mirrors
# the api host: federation.<instance>.meshcloud.io -> sso.<instance>.meshcloud.io.
MIG_SSO_URL=${MIG_SSO_URL:-$(printf '%s' "$MESH" | sed 's#//federation\.#//sso.#')}
export MT=$(curl -s -u "${MIG_CLIENT_ID}:${MESHSTACK_API_KEY_CLOUDFOUNDATION}" \
  -d 'grant_type=client_credentials' \
  "${MIG_SSO_URL}/auth/realms/meshfed/protocol/openid-connect/token" \
  | jq -r '.access_token // empty')
[ -z "$MT" ] && { echo "FATAL: token request failed" >&2; return 1; }

# Every meshObject type needs its own versioned Accept header. Plain v4 (no -preview) returns 406.
export BBACC="Accept: application/vnd.meshcloud.api.meshbuildingblock.v2-preview.hal+json"
export TN3="Accept: application/vnd.meshcloud.api.meshtenant.v3.hal+json"
export TN4="Accept: application/vnd.meshcloud.api.meshtenant.v4-preview.hal+json"
export PL2="Accept: application/vnd.meshcloud.api.meshplatform.v2.hal+json"

# ~/.terraformrc may carry a dev override with an older meshstack provider than the one that wrote the
# state, which makes tofu refuse to read it.
[ -f /tmp/tofu-no-override.tfrc ] || printf 'provider_installation {\n  direct {}\n}\n' > /tmp/tofu-no-override.tfrc
export TF_CLI_CONFIG_FILE=/tmp/tofu-no-override.tfrc
