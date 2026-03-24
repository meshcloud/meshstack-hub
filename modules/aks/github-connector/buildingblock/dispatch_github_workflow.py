#!/usr/bin/env python3
"""Dispatch a GitHub Actions workflow using GitHub App authentication and await completion.

Generates a short-lived installation token from the GitHub App credentials,
triggers a workflow_dispatch event, then polls the returned run ID until the
run reaches a terminal state and raises on failure.

As of 2026-02-19, GitHub's workflow_dispatch API returns the run ID directly
in the response body: https://github.blog/changelog/2026-02-19-workflow-dispatch-api-now-returns-run-ids/

Required environment variables:
  GITHUB_APP_ID              - GitHub App ID (numeric)
  GITHUB_APP_INSTALLATION_ID - GitHub App installation ID (numeric)
  GITHUB_APP_PEM_FILE        - PEM-encoded RSA private key content (not a file path)
  GITHUB_REPO                - Repo name ('owner/repo' or bare 'repo'; GITHUB_OWNER is prepended if no slash)
  GITHUB_OWNER               - GitHub org/user (used when GITHUB_REPO has no slash)
  WORKFLOW_FILENAME          - Workflow file name, e.g. 'k8s-deploy.yml'
  WORKFLOW_REF               - Git ref to dispatch on, e.g. 'main'

Optional:
  POLL_INTERVAL_SECONDS      - Seconds between polls (default: 10)
  TIMEOUT_SECONDS            - Max seconds to wait for completion (default: 900)
"""

import base64
import json
import os
import time
import urllib.request

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def make_app_jwt(app_id: str, pem: str) -> str:
    now = int(time.time())
    header = b64url(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
    payload = b64url(
        json.dumps({"iat": now - 60, "exp": now + 600, "iss": app_id}).encode()
    )
    key = serialization.load_pem_private_key(pem.encode(), password=None)
    signature = key.sign(
        f"{header}.{payload}".encode(), padding.PKCS1v15(), hashes.SHA256()
    )
    return f"{header}.{payload}.{b64url(signature)}"


def github_request(token: str, method: str, url: str, payload: dict | None = None):
    body = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2026-03-10",
            "Content-Type": "application/json",
        },
        method=method,
        data=body,
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        raw = resp.read().decode()
        status = resp.status
    return status, json.loads(raw) if raw else {}


def get_installation_token(app_id: str, installation_id: str, pem: str) -> str:
    jwt = make_app_jwt(app_id, pem)
    _, data = github_request(
        jwt,
        "POST",
        f"https://api.github.com/app/installations/{installation_id}/access_tokens",
    )
    return data["token"]


def main() -> None:
    app_id = os.environ["GITHUB_APP_ID"]
    installation_id = os.environ["GITHUB_APP_INSTALLATION_ID"]
    pem = os.environ["GITHUB_APP_PEM_FILE"]
    repo = os.environ["GITHUB_REPO"]
    if "/" not in repo:
        repo = f"{os.environ['GITHUB_OWNER']}/{repo}"
    workflow_filename = os.environ["WORKFLOW_FILENAME"]
    ref = os.environ["WORKFLOW_REF"]
    poll_interval = int(os.environ.get("POLL_INTERVAL_SECONDS", "10"))
    timeout = int(os.environ.get("TIMEOUT_SECONDS", "900"))

    token = get_installation_token(app_id, installation_id, pem)

    # ── Dispatch ──────────────────────────────────────────────────────────────
    status, dispatch_data = github_request(
        token,
        "POST",
        f"https://api.github.com/repos/{repo}/actions/workflows/{workflow_filename}/dispatches",
        {"ref": ref, "return_run_details": True},
    )
    if status not in (200, 201, 202, 204):
        raise SystemExit(
            f"workflow_dispatch to '{ref}' failed with HTTP {status}. "
            f"Check that '{workflow_filename}' exists in '{repo}' and has 'on: workflow_dispatch'."
        )

    run_id = dispatch_data.get("workflow_run_id")
    if run_id is None:
        raise SystemExit("GitHub did not return a run ID in the dispatch response. ")
    print(f"Dispatched '{workflow_filename}' on ref '{ref}', run ID: {run_id}")

    # ── Poll the specific run by ID ───────────────────────────────────────────
    run_url = f"https://api.github.com/repos/{repo}/actions/runs/{run_id}"
    deadline = time.time() + timeout
    last_state: tuple | None = None

    while time.time() < deadline:
        time.sleep(poll_interval)

        _, run = github_request(token, "GET", run_url)
        status_val = run.get("status")
        conclusion = run.get("conclusion")
        html_url = run.get("html_url", "")

        state = (status_val, conclusion)
        if state != last_state:
            print(
                f"  Run {run_id} [{ref}]: status={status_val} conclusion={conclusion}"
            )
            last_state = state

        if status_val == "completed":
            if conclusion == "success":
                print(f"Run {run_id} [{ref}] completed successfully.")
                return
            raise SystemExit(
                f"Run {run_id} [{ref}] failed with conclusion='{conclusion}': {html_url}"
            )

    raise SystemExit(
        f"Timed out after {timeout}s waiting for '{workflow_filename}' on '{ref}' to complete."
    )


if __name__ == "__main__":
    main()
