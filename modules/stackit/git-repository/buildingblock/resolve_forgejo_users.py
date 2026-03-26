#!/usr/bin/env python3
"""Resolve workspace member emails to Forgejo usernames via the search API.

Called as a Terraform external data source.
Input (via stdin JSON):  { "emails": "alice@example.com,bob@example.com" }
Output (via stdout JSON): {
  "alice@example.com": "alice",
  "error:alice@example.com": "",
  "bob@example.com": "",
  "error:bob@example.com": "no account found — member must sign in to Forgejo first"
}

An empty string value for the email key means the user was not found.
The "error:<email>" key contains the reason why the user was not found.
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


def search_user_by_email(forgejo_host: str, token: str, email: str) -> tuple[str | None, str]:
    """Search for a Forgejo user by email. Returns (login, error_reason).

    Tries /users/search first (requires "explore users" to be enabled on the
    Forgejo instance). If that returns 404, falls back to guessing the username
    from the email prefix (everything before @) and verifying via /users/{name}.
    """
    username = _search_user_api(forgejo_host, token, email)
    if username is not None:
        return username, ""

    # Fallback: derive candidate username from email prefix and verify
    return _lookup_user_by_email_prefix(forgejo_host, token, email)


def _search_user_api(forgejo_host: str, token: str, email: str) -> str | None:
    """Try the /users/search endpoint. Returns login, None if not found, or
    None if the endpoint is unavailable (404 when explore is disabled)."""
    url = f"{forgejo_host}/api/v1/users/search?q={urllib.parse.quote(email)}"
    req = urllib.request.Request(
        url,
        headers={"Authorization": f"token {token}"},
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return None  # endpoint unavailable (explore users disabled)
        raise  # surface auth/server errors (401, 403, 5xx) immediately

    # The search API returns partial matches, so we must verify the email exactly
    for user in payload.get("data", []):
        if user.get("email", "").lower() == email.lower():
            return user["login"]

    return None


def _lookup_user_by_email_prefix(forgejo_host: str, token: str, email: str) -> tuple[str | None, str]:
    """Guess username from email prefix and verify via /users/{username}.

    Works even when the Forgejo instance has "explore users" disabled. The
    assumption is that SSO-provisioned accounts use the email local-part as
    the username (e.g. alice@example.com → alice).
    """
    local_part = email.split("@")[0]
    if not local_part:
        return None, "no account found — member must sign in to Forgejo first"

    url = f"{forgejo_host}/api/v1/users/{urllib.parse.quote(local_part)}"
    req = urllib.request.Request(
        url,
        headers={"Authorization": f"token {token}"},
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            user = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError:
        return None, "no account found — member must sign in to Forgejo first"

    if user.get("email", "").lower() == email.lower():
        return user["login"], ""

    actual_email = user.get("email", "")
    return None, f"username '{local_part}' exists but has email '{actual_email}' — sign in with correct email first"


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
        username, error = search_user_by_email(forgejo_host, token, email)
        result[email] = username or ""
        result[f"error:{email}"] = error

    print(json.dumps(result))


if __name__ == "__main__":
    main()
