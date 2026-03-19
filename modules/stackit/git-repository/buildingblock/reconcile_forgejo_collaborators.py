#!/usr/bin/env python3

import json
import os
import urllib.request


def normalize_host(raw_host: str) -> str:
    host = raw_host.strip()
    if not host.startswith(("https://", "http://")):
        host = f"https://{host}"
    return host.rstrip("/")


def request_json(host: str, token: str, method: str, path: str, payload: dict | None = None):
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{host}{path}",
        headers={"Authorization": f"token {token}", "Content-Type": "application/json"},
        method=method,
        data=body,
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        raw = resp.read().decode("utf-8")
    return json.loads(raw) if raw else {}


def main() -> None:
    host = normalize_host(os.environ["FORGEJO_HOST"])
    token = os.environ["FORGEJO_API_TOKEN"]
    owner = os.environ["REPOSITORY_OWNER"]
    repo = os.environ["REPOSITORY_NAME"]

    desired = json.loads(os.environ["DESIRED_COLLABORATORS_JSON"])
    current = set(json.loads(os.environ["CURRENT_COLLABORATORS_JSON"]))
    protected = set(json.loads(os.environ.get("PROTECTED_COLLABORATORS_JSON", "[]")))

    desired_users = set(desired.keys())

    for username in sorted(desired_users):
        permission = desired[username]
        request_json(
            host,
            token,
            "PUT",
            f"/api/v1/repos/{owner}/{repo}/collaborators/{username}",
            {"permission": permission},
        )

    removable = sorted((current - desired_users) - protected)
    for username in removable:
        request_json(
            host,
            token,
            "DELETE",
            f"/api/v1/repos/{owner}/{repo}/collaborators/{username}",
        )


if __name__ == "__main__":
    main()
