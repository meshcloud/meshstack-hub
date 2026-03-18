#!/usr/bin/env python3

import datetime as dt
import json
import os
import re
import time
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
        headers = dict(resp.headers.items())
        status = resp.status
    data = json.loads(raw) if raw else {}
    return status, headers, data


def parse_timestamp(ts: str | None):
    if not ts:
        return None
    return dt.datetime.fromisoformat(ts.replace("Z", "+00:00"))


def main() -> None:
    host = normalize_host(os.environ["FORGEJO_HOST"])
    token = os.environ["FORGEJO_API_TOKEN"]
    repository_id = os.environ["FORGEJO_REPOSITORY_ID"]
    workflow_name = os.environ.get("FORGEJO_WORKFLOW_NAME", "pipeline.yaml")
    stage = os.environ["FORGEJO_WORKFLOW_STAGE"]

    _, _, repo = request_json(host, token, "GET", f"/api/v1/repositories/{repository_id}")
    owner = repo["owner"]["username"]
    repo_name = repo["name"]
    default_branch = repo.get("default_branch", "main")

    dispatch_at = dt.datetime.now(dt.timezone.utc)
    status, headers, dispatch_response = request_json(
        host,
        token,
        "POST",
        f"/api/v1/repos/{owner}/{repo_name}/actions/workflows/{workflow_name}/dispatches",
        {"ref": default_branch, "inputs": {"stage": stage}},
    )
    if status not in (200, 201, 202, 204):
        raise SystemExit(f"Workflow dispatch failed with status {status}")

    expected_run_id = None
    expected_run_number = None

    if "id" in dispatch_response:
        expected_run_id = int(dispatch_response["id"])
    if "run_id" in dispatch_response:
        expected_run_id = int(dispatch_response["run_id"])
    if "run_number" in dispatch_response:
        expected_run_number = int(dispatch_response["run_number"])

    location = headers.get("Location", "")
    m = re.search(r"/actions/runs/(\\d+)", location)
    if m:
        expected_run_id = int(m.group(1))

    deadline = time.time() + 900
    runs_path = f"/api/v1/repos/{owner}/{repo_name}/actions/runs?limit=30"

    while time.time() < deadline:
        _, _, payload = request_json(host, token, "GET", runs_path)
        runs = payload.get("workflow_runs", [])

        if expected_run_id is not None:
            candidates = [r for r in runs if int(r.get("id", 0)) == expected_run_id]
        elif expected_run_number is not None:
            candidates = [r for r in runs if int(r.get("run_number", 0)) == expected_run_number]
        else:
            candidates = []
            for run in runs:
                if run.get("event") != "workflow_dispatch":
                    continue
                if run.get("head_branch") != default_branch:
                    continue
                created_at = parse_timestamp(run.get("created_at"))
                if created_at and created_at >= dispatch_at - dt.timedelta(seconds=2):
                    candidates.append(run)
            candidates.sort(key=lambda r: int(r.get("id", 0)), reverse=True)

        if candidates:
            run = candidates[0]
            run_id = run.get("id")
            status_val = run.get("status")
            conclusion = run.get("conclusion")
            html_url = run.get("html_url", "")

            if status_val == "completed":
                if conclusion == "success":
                    print(f"Workflow run {run_id} completed successfully: {html_url}")
                    return
                raise SystemExit(f"Workflow run {run_id} failed with conclusion={conclusion}: {html_url}")

        time.sleep(10)

    raise SystemExit("Timed out waiting for dispatched pipeline workflow to complete.")


if __name__ == "__main__":
    main()
