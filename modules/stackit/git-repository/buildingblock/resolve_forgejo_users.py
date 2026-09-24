#!/usr/bin/env python3
"""Resolves workspace member emails to Forgejo usernames for a Terraform external data source.

Output maps each email to a username ("" if unresolved) and "error:<email>" to the reason.
Users come from the STACKIT Git users API, authenticated via workload identity federation. The
Forgejo token's technical user is restricted and cannot see other users.
"""

import json
import os
import sys
import urllib.parse
import urllib.request

NOT_FOUND = "no account found — member must sign in to Forgejo first"


def request(url: str, headers: dict, data: bytes | None = None):
    req = urllib.request.Request(url, headers=headers, data=data)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def stackit_access_token() -> str:
    with open(os.environ.get("STACKIT_FEDERATED_TOKEN_FILE", "/var/run/secrets/stackit.cloud/serviceaccount/token")) as f:
        assertion = f.read().strip()

    form = urllib.parse.urlencode({
        "grant_type": "client_credentials",
        "client_assertion_type": "urn:schwarz:params:oauth:client-assertion-type:workload-jwt",
        "client_assertion": assertion,
        "client_id": os.environ["STACKIT_SERVICE_ACCOUNT_EMAIL"],
    }).encode()
    endpoint = os.environ.get("STACKIT_IDP_TOKEN_ENDPOINT", "https://accounts.stackit.cloud/oauth/v2/token")
    return request(endpoint, {"Content-Type": "application/x-www-form-urlencoded"}, form)["access_token"]


def stackit_users(project_id: str, instance_id: str) -> dict[str, str]:
    api_host = os.environ.get("STACKIT_GIT_API_HOST", "https://git.api.stackit.cloud")
    headers = {"Authorization": f"Bearer {stackit_access_token()}"}
    users, page, total_pages = {}, 1, 1
    while page <= total_pages:
        body = request(f"{api_host}/v1beta/projects/{project_id}/instances/{instance_id}/users?page={page}", headers)
        users.update({u["email"].lower(): u["username"] for u in body["users"]})
        total_pages = body.get("totalPages", 1)
        page += 1
    return users


def main() -> None:
    query = json.loads(sys.stdin.read())
    emails = [e.strip() for e in query.get("emails", "").split(",") if e.strip()]
    if not emails:
        print(json.dumps({}))
        return

    users = stackit_users(query["stackit_project_id"], query["stackit_git_instance_id"])

    result = {}
    for email in emails:
        username = users.get(email.lower(), "")
        result[email] = username
        result[f"error:{email}"] = "" if username else NOT_FOUND

    print(json.dumps(result))


if __name__ == "__main__":
    main()
