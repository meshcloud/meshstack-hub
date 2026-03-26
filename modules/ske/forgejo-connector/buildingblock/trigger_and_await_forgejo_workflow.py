#!/usr/bin/env python3
"""Dispatch a Forgejo workflow on a specific branch and wait for completion.

Triggers a workflow_dispatch event on the given BRANCH and polls until all jobs
reach a terminal state (success, failure, cancelled, skipped).

Run identification: Forgejo returns HTTP 204 with no body on dispatch, so there
is no run ID to correlate. Instead, we use a 5-second timestamp coincidence
window filtering by the dispatched branch to identify the correct run.

API compatibility: Forgejo 8.x does not expose /actions/workflows/{wf}/runs.
The script probes that endpoint first, then falls back to /actions/tasks which
returns one entry per job. The tasks endpoint also lacks a separate 'conclusion'
field — the 'status' value IS the terminal state.

Required environment variables:
  FORGEJO_HOST       – Forgejo instance URL (from provider)
  FORGEJO_API_TOKEN  – API token with repo action scope (from provider)
  REPOSITORY_ID      – numeric repository ID
  BRANCH             – branch to dispatch on (e.g. "dev" or "prod")

Optional:
  WORKFLOW_NAME      – workflow file name (default: pipeline.yaml)
"""

import datetime as dt
import json
import os
import re
import time
import urllib.error
import urllib.request

COINCIDENCE_WINDOW_SECONDS = 5
TERMINAL_STATUSES = {"success", "failure", "cancelled", "skipped"}
TIMEOUT_SECONDS = 900
POLL_INTERVAL_SECONDS = 10


def as_int(value, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


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
        status = resp.status
    data = json.loads(raw) if raw else {}
    return status, data


def parse_timestamp(ts: str | None):
    if not ts:
        return None
    return dt.datetime.fromisoformat(ts.replace("Z", "+00:00"))


def find_runs_endpoint(host: str, token: str, owner: str, repo_name: str, workflow_name: str) -> str:
    """Probe available run list endpoints, return the first that works."""
    candidates = [
        f"/api/v1/repos/{owner}/{repo_name}/actions/workflows/{workflow_name}/runs?limit=30",
        f"/api/v1/repos/{owner}/{repo_name}/actions/tasks?limit=30",
    ]
    for candidate in candidates:
        try:
            request_json(host, token, "GET", candidate)
            return candidate
        except urllib.error.HTTPError as exc:
            if exc.code == 404:
                continue
            raise

    raise SystemExit(
        "Could not find a supported Forgejo workflow runs endpoint. "
        "Tried: " + ", ".join(candidates)
    )


def identify_run_from_tasks(tasks: list[dict], branch: str, dispatch_at: dt.datetime) -> list[dict]:
    """From /actions/tasks, find tasks matching our branch and event within the coincidence window."""
    candidates = []
    for task in tasks:
        if task.get("head_branch") != branch:
            continue
        # Filter by event type when available to avoid confusing push-triggered runs
        event = task.get("event")
        if event and event != "workflow_dispatch":
            continue
        created_at = parse_timestamp(task.get("created_at"))
        if created_at and created_at >= dispatch_at - dt.timedelta(seconds=COINCIDENCE_WINDOW_SECONDS):
            candidates.append(task)

    if not candidates:
        return []

    # Group by run_number, pick the latest run
    by_run: dict[int, list[dict]] = {}
    for task in candidates:
        rn = as_int(task.get("run_number"), -1)
        if rn >= 0:
            by_run.setdefault(rn, []).append(task)

    if by_run:
        latest_run = max(by_run)
        return by_run[latest_run]

    return candidates


def identify_run_from_workflow_runs(runs: list[dict], branch: str, dispatch_at: dt.datetime) -> list[dict]:
    """From /actions/workflows/{wf}/runs, find runs matching our branch and event within the coincidence window."""
    candidates = []
    for run in runs:
        if run.get("head_branch") != branch:
            continue
        # Filter by event type when available to avoid confusing push-triggered runs
        event = run.get("event")
        if event and event != "workflow_dispatch":
            continue
        created_at = parse_timestamp(run.get("created_at"))
        if created_at and created_at >= dispatch_at - dt.timedelta(seconds=COINCIDENCE_WINDOW_SECONDS):
            candidates.append(run)

    candidates.sort(key=lambda r: as_int(r.get("id")), reverse=True)
    return candidates


def await_tasks_completion(tasks: list[dict], seen_job_status: dict[str, str]) -> tuple[bool, str]:
    """Check if all tasks are terminal. Returns (all_done, status_summary)."""
    by_job_name: dict[str, dict] = {}
    for task in tasks:
        task_name = str(task.get("name") or task.get("display_title") or "").strip()
        if not task_name:
            continue
        prev = by_job_name.get(task_name)
        if prev is None or as_int(task.get("id")) > as_int(prev.get("id")):
            by_job_name[task_name] = task

    for task in by_job_name.values():
        task_name = str(task.get("name") or task.get("display_title") or "unknown").strip()
        task_status = str(task.get("status") or "unknown")
        if seen_job_status.get(task_name) != task_status:
            print(f"  Job {task_name}: {task_status}")
            seen_job_status[task_name] = task_status

    non_terminal = [t for t in by_job_name.values() if t.get("status") not in TERMINAL_STATUSES]
    if non_terminal:
        return False, ""

    failed = [t for t in by_job_name.values() if t.get("status") not in {"success", "skipped"}]
    if failed:
        summary = ", ".join(
            f"{t.get('name', t.get('display_title', 'unknown'))}={t.get('status')}" for t in failed
        )
        return True, f"failed: {summary}"

    return True, "success"


def main() -> None:
    host = normalize_host(os.environ["FORGEJO_HOST"])
    token = os.environ["FORGEJO_API_TOKEN"]
    repository_id = os.environ["REPOSITORY_ID"]
    workflow_name = os.environ.get("WORKFLOW_NAME", "pipeline.yaml")
    branch = os.environ["BRANCH"]

    _, repo = request_json(host, token, "GET", f"/api/v1/repositories/{repository_id}")
    owner = repo["owner"]["username"]
    repo_name = repo["name"]

    print(f"Dispatching workflow {workflow_name} on branch {branch} for {owner}/{repo_name}")

    dispatch_at = dt.datetime.now(dt.timezone.utc)
    dispatch_path = f"/api/v1/repos/{owner}/{repo_name}/actions/workflows/{workflow_name}/dispatches"
    status, _ = request_json(host, token, "POST", dispatch_path, {"ref": branch})
    if status not in (200, 201, 202, 204):
        raise SystemExit(f"Workflow dispatch failed with status {status}")

    runs_path = find_runs_endpoint(host, token, owner, repo_name, workflow_name)
    uses_tasks_endpoint = "/actions/tasks" in runs_path
    print(f"Polling workflow status via {runs_path}")

    seen_job_status: dict[str, str] = {}
    deadline = time.time() + TIMEOUT_SECONDS

    while time.time() < deadline:
        _, payload = request_json(host, token, "GET", runs_path)
        runs = payload.get("workflow_runs", [])

        if uses_tasks_endpoint:
            candidates = identify_run_from_tasks(runs, branch, dispatch_at)
            if candidates:
                done, result = await_tasks_completion(candidates, seen_job_status)
                if done:
                    run_id = as_int(candidates[0].get("run_number"))
                    url = candidates[0].get("url", "")
                    if result == "success":
                        print(f"Workflow run {run_id} on {branch} completed successfully: {url}")
                        return
                    raise SystemExit(f"Workflow run {run_id} on {branch} {result}: {url}")
        else:
            candidates = identify_run_from_workflow_runs(runs, branch, dispatch_at)
            if candidates:
                run = candidates[0]
                run_id = run.get("id")
                status_val = run.get("status")
                conclusion = run.get("conclusion")
                html_url = run.get("html_url", run.get("url", ""))

                # Normalize: some Forgejo versions use status as terminal state
                if conclusion is None and status_val in TERMINAL_STATUSES:
                    conclusion = status_val
                    status_val = "completed"

                if status_val == "completed":
                    if conclusion == "success":
                        print(f"Workflow run {run_id} on {branch} completed successfully: {html_url}")
                        return
                    raise SystemExit(f"Workflow run {run_id} on {branch} failed: conclusion={conclusion}: {html_url}")

                print(f"Workflow run {run_id} on {branch}: status={status_val} conclusion={conclusion}")

        time.sleep(POLL_INTERVAL_SECONDS)

    raise SystemExit(f"Timed out waiting for workflow on branch {branch} to complete.")


if __name__ == "__main__":
    main()
