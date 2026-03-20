#!/usr/bin/env python3

import json
import os
import sys
import urllib.request


def normalize_host(raw_host: str) -> str:
    host = raw_host.strip()
    if not host.startswith(("https://", "http://")):
        host = f"https://{host}"
    return host.rstrip("/")


def main() -> None:
    query = json.loads(sys.stdin.read())

    forgejo_host = normalize_host(os.environ["FORGEJO_HOST"])
    forgejo_api_token = os.environ["FORGEJO_API_TOKEN"]
    repository_id = query["FORGEJO_REPOSITORY_ID"]

    req = urllib.request.Request(
        f"{forgejo_host}/api/v1/repositories/{repository_id}",
        headers={"Authorization": f"token {forgejo_api_token}", "Content-Type": "application/json"},
        method="GET",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        payload = json.loads(resp.read().decode("utf-8"))

    print(
        json.dumps(
            {
                "forgejo_host": forgejo_host,
                "forgejo_api_token": forgejo_api_token,
                "owner": payload["owner"]["username"],
                "name": payload["name"],
                "default_branch": payload.get("default_branch", "main"),
            }
        )
    )


if __name__ == "__main__":
    main()
