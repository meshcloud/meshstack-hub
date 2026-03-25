#!/usr/bin/env python3
"""Resolve workspace member emails to Forgejo usernames via the search API.

Called as a Terraform external data source.
Input (via stdin JSON):  { "emails": "alice@example.com,bob@example.com" }
Output (via stdout JSON): { "alice@example.com": "alice", "bob@example.com": "" }

An empty string value means the user was not found on the Forgejo instance.
"""

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


def normalize_host(raw_host: str) -> str:
    host = raw_host.strip()
    if not host.startswith(("https://", "http://")):
        host = f"https://{host}"
    return host.rstrip("/")


def search_user_by_email(forgejo_host: str, token: str, email: str) -> str | None:
    """Search for a Forgejo user by email. Returns the login name or None."""
    url = f"{forgejo_host}/api/v1/users/search?q={urllib.parse.quote(email)}"
    req = urllib.request.Request(
        url,
        headers={"Authorization": f"token {token}"},
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError:
        return None

    # The search API returns partial matches, so we must verify the email exactly
    for user in payload.get("data", []):
        if user.get("email", "").lower() == email.lower():
            return user["login"]

    return None


def main() -> None:
    query = json.loads(sys.stdin.read())
    emails_csv = query.get("emails", "")

    if not emails_csv.strip():
        print(json.dumps({}))
        return

    emails = [e.strip() for e in emails_csv.split(",") if e.strip()]

    forgejo_host = normalize_host(os.environ["FORGEJO_HOST"])
    token = os.environ["FORGEJO_API_TOKEN"]

    result = {}
    for email in emails:
        username = search_user_by_email(forgejo_host, token, email)
        result[email] = username or ""

    print(json.dumps(result))


if __name__ == "__main__":
    main()
