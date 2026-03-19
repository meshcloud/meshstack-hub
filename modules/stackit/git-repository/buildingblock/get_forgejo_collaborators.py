#!/usr/bin/env python3

import hashlib
import json
import os
import sys
import urllib.request


def normalize_host(raw_host: str) -> str:
    host = raw_host.strip()
    if not host.startswith(("https://", "http://")):
        host = f"https://{host}"
    return host.rstrip("/")


def request_json(host: str, token: str, method: str, path: str):
    req = urllib.request.Request(
        f"{host}{path}",
        headers={"Authorization": f"token {token}", "Content-Type": "application/json"},
        method=method,
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        raw = resp.read().decode("utf-8")
    return json.loads(raw) if raw else {}


def main() -> None:
    query = json.loads(sys.stdin.read())
    owner = query["owner"]
    repo = query["repo"]

    host = normalize_host(os.environ["FORGEJO_HOST"])
    token = os.environ["FORGEJO_API_TOKEN"]

    users = request_json(host, token, "GET", f"/api/v1/repos/{owner}/{repo}/collaborators")

    collaborators = sorted(
        {
            str((u.get("login") or "")).strip()
            for u in (users if isinstance(users, list) else [])
            if str((u.get("login") or "")).strip() != ""
        }
    )
    collaborators_json = json.dumps(collaborators, separators=(",", ":"))
    current_hash = hashlib.sha256(collaborators_json.encode("utf-8")).hexdigest()

    print(
        json.dumps(
            {
                "collaborators_json": collaborators_json,
                "current_hash": current_hash,
            }
        )
    )


if __name__ == "__main__":
    main()
