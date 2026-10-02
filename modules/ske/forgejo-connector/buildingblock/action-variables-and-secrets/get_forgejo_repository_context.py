#!/usr/bin/env python3

import json
import os
import sys
import time
import urllib.error
import urllib.request

REQUEST_TIMEOUT_SECONDS = 30
RETRY_DELAYS_SECONDS = (1, 2, 4, 8, 16)
# Answers that say "not now" rather than "no": everything else is the server's
# verdict on our request and must fail the run.
RETRYABLE_HTTP_STATUSES = {429, 500, 502, 503, 504}


def normalize_host(raw_host: str) -> str:
    host = raw_host.strip()
    if not host.startswith(("https://", "http://")):
        host = f"https://{host}"
    return host.rstrip("/")


def get_json_once(url: str, token: str) -> dict:
    req = urllib.request.Request(
        url,
        headers={"Authorization": f"token {token}", "Content-Type": "application/json"},
        method="GET",
    )
    with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT_SECONDS) as resp:
        return json.loads(resp.read().decode("utf-8"))


def get_json(url: str, token: str) -> dict:
    """GET a Forgejo endpoint, retrying transient failures.

    Forgejo intermittently leaves a request hanging until it times out. This
    data source runs on every plan and destroy, so one such answer would fail
    the whole building block run — including its teardown.

    Diagnostics go to stderr: stdout is the external data source's JSON result.
    """
    for delay in RETRY_DELAYS_SECONDS:
        try:
            return get_json_once(url, token)
        except urllib.error.HTTPError as err:
            if err.code not in RETRYABLE_HTTP_STATUSES:
                raise
            reason = f"HTTP {err.code}"
        except OSError as err:
            # URLError, socket timeout, connection reset — all OSError subclasses.
            reason = f"{type(err).__name__}: {err}"
        print(f"GET {url} failed ({reason}); retrying in {delay}s", file=sys.stderr)
        time.sleep(delay)
    return get_json_once(url, token)


def main() -> None:
    query = json.loads(sys.stdin.read())

    forgejo_host = normalize_host(os.environ["FORGEJO_HOST"])
    forgejo_api_token = os.environ["FORGEJO_API_TOKEN"]
    repository_id = query["FORGEJO_REPOSITORY_ID"]

    payload = get_json(f"{forgejo_host}/api/v1/repositories/{repository_id}", forgejo_api_token)

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
