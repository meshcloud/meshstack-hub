#!/bin/sh
# Registration runs in cloud-init after Terraform, so a runner that never registers would otherwise
# leave the run SUCCEEDED. The token comes from the environment to keep it out of ps output.
set -eu

base_url=$1
organization=$2
runner_name=$3

timeout_seconds=300
poll_seconds=10

url="${base_url}/api/v1/orgs/${organization}/actions/runners"
response_file=$(mktemp)
trap 'rm -f "${response_file}"' EXIT

deadline=$(($(date +%s) + timeout_seconds))

while :; do
  http_code=$(curl -sS --max-time 15 -o "${response_file}" -w '%{http_code}' \
    -H "Authorization: token ${FORGEJO_API_TOKEN}" \
    -H "Accept: application/json" \
    "${url}" 2>/dev/null || echo "000")

  # Polling cannot recover from these.
  case "${http_code}" in
  401 | 403 | 404)
    echo "Listing runners for organization ${organization} answered HTTP ${http_code}." >&2
    echo "Check that the organization exists and the PAT still has org-admin rights." >&2
    exit 1
    ;;
  esac

  # Runner objects have no nested objects, so splitting on `}` yields one runner per line.
  entry=$(tr '}' '\n' <"${response_file}" | grep -F "\"name\":\"${runner_name}\"" | head -n 1 || true)

  case "${entry}" in
  *'"status":"offline"'*) state="registered but offline" ;;
  *'"status":"'*)
    echo "Runner ${runner_name} is registered in organization ${organization}."
    exit 0
    ;;
  *) state="not registered" ;;
  esac

  if [ "$(date +%s)" -ge "${deadline}" ]; then
    echo "Runner ${runner_name} is ${state} ${timeout_seconds}s after the VM was created." >&2
    echo "It registers from cloud-init on the VM. Read /var/log/cloud-init-output.log and" >&2
    echo "journalctl -u git-runner there to see why the agent download or registration failed." >&2
    exit 1
  fi

  sleep "${poll_seconds}"
done
