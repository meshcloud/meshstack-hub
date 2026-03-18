#!/usr/bin/env python3
"""Dispatch a Forgejo workflow and wait for completion.

Triggers a workflow_dispatch event and polls until all jobs reach a terminal
state (success, failure, cancelled, skipped).

Parallel-dispatch safety: Forgejo returns HTTP 204 with no body on dispatch,
so there is no run ID to correlate. Instead, we use a timestamp coincidence
window (2 s) combined with EXPECTED_WORKFLOW_TASK_NAME to identify the correct
run among concurrent dispatches (e.g. stage=dev vs stage=prod).

API compatibility: Forgejo 8.x does not expose /actions/workflows/{wf}/runs.
The script probes that endpoint first, then falls back to /actions/tasks which
returns one entry per job. The tasks endpoint also lacks a separate 'conclusion'
field — the 'status' value IS the terminal state.

Required environment variables:
  FORGEJO_HOST                  – Forgejo instance URL (from provider)
  FORGEJO_API_TOKEN             – API token with repo action scope (from provider)
  REPOSITORY_ID                 – numeric repository ID
  WORKFLOW_ONLY_STAGE           – value for the only_stage workflow input
  EXPECTED_WORKFLOW_TASK_NAME   – job name used to identify the correct run

Optional:
  WORKFLOW_NAME                 – workflow file name (default: pipeline.yaml)
"""

import datetime as dt
import json
import os
import re
import time
import urllib.error
import urllib.request


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
    repository_id = os.environ["REPOSITORY_ID"]
    workflow_name = os.environ.get("WORKFLOW_NAME", "pipeline.yaml")
    only_stage = os.environ["WORKFLOW_ONLY_STAGE"]
    expected_task_name = os.environ["EXPECTED_WORKFLOW_TASK_NAME"]

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
        {"ref": default_branch, "inputs": {"only_stage": only_stage}},
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
    expected_jobs = dispatch_response.get("jobs", [])
    if not isinstance(expected_jobs, list):
        expected_jobs = []
    if expected_jobs:
        print(f"Dispatched workflow jobs: {', '.join(expected_jobs)}")

    location = headers.get("Location", "")
    m = re.search(r"/actions/runs/(\d+)", location)
    if m:
        expected_run_id = int(m.group(1))

    deadline = time.time() + 900
    run_list_candidates = [
        f"/api/v1/repos/{owner}/{repo_name}/actions/workflows/{workflow_name}/runs?limit=30",
        f"/api/v1/repos/{owner}/{repo_name}/actions/tasks?limit=30",
    ]
    runs_path = None

    for candidate in run_list_candidates:
        try:
            request_json(host, token, "GET", candidate)
            runs_path = candidate
            break
        except urllib.error.HTTPError as exc:
            if exc.code == 404:
                continue
            raise

    if runs_path is None:
        raise SystemExit(
            "Could not find a supported Forgejo workflow runs endpoint. "
            "Tried: " + ", ".join(run_list_candidates)
        )

    uses_tasks_endpoint = "/actions/tasks" in runs_path
    print(f"Polling workflow status via {runs_path}")
    seen_job_status: dict[str, str] = {}
    last_wait_reason: tuple | None = None
    last_run_state: tuple | None = None

    while time.time() < deadline:
        _, _, payload = request_json(host, token, "GET", runs_path)
        runs = payload.get("workflow_runs", [])

        if uses_tasks_endpoint:
            if expected_run_number is not None:
                candidates = [r for r in runs if as_int(r.get("run_number"), -1) == expected_run_number]
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

                # Disambiguate parallel dispatches: group by run_number and pick
                # the run whose job list contains the expected task name.
                if expected_task_name and candidates:
                    by_run: dict[int, list[dict]] = {}
                    for task in candidates:
                        rn = as_int(task.get("run_number"), -1)
                        if rn >= 0:
                            by_run.setdefault(rn, []).append(task)

                    matched_run = None
                    for rn in sorted(by_run, reverse=True):
                        if any(
                            str(t.get("name", "")).strip() == expected_task_name
                            for t in by_run[rn]
                        ):
                            matched_run = rn
                            break

                    if matched_run is not None:
                        candidates = by_run[matched_run]
                        expected_run_number = matched_run
                        print(f"Identified run {matched_run} by expected task '{expected_task_name}'")
                    else:
                        candidates = []
        elif expected_run_id is not None:
            candidates = [r for r in runs if as_int(r.get("id")) == expected_run_id]
        elif expected_run_number is not None:
            candidates = [r for r in runs if as_int(r.get("run_number"), -1) == expected_run_number]
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
            candidates.sort(key=lambda r: as_int(r.get("id")), reverse=True)

        if candidates:
            if uses_tasks_endpoint:
                # /actions/tasks returns one task per job in the workflow.
                # Wait for all jobs in the dispatched composition to reach terminal states.
                by_job_name: dict[str, dict] = {}
                for task in candidates:
                    task_name = str(task.get("name") or task.get("display_title") or "").strip()
                    if not task_name:
                        continue
                    prev = by_job_name.get(task_name)
                    if prev is None or as_int(task.get("id")) > as_int(prev.get("id")):
                        by_job_name[task_name] = task

                if expected_jobs:
                    missing_jobs = [job for job in expected_jobs if job not in by_job_name]
                    if missing_jobs:
                        wait_reason = ("missing", tuple(missing_jobs))
                        if wait_reason != last_wait_reason:
                            print(f"Awaiting jobs to appear: {', '.join(missing_jobs)}")
                            last_wait_reason = wait_reason
                        time.sleep(10)
                        continue
                    relevant_tasks = [by_job_name[job] for job in expected_jobs]
                else:
                    relevant_tasks = list(by_job_name.values())

                for task in relevant_tasks:
                    task_name = str(task.get("name") or task.get("display_title") or "unknown").strip()
                    task_status = str(task.get("status") or "unknown")
                    previous_status = seen_job_status.get(task_name)
                    if previous_status != task_status:
                        print(f"Job {task_name}: {task_status}")
                        seen_job_status[task_name] = task_status

                terminal_statuses = {"success", "failure", "cancelled", "skipped"}
                non_terminal = [t for t in relevant_tasks if t.get("status") not in terminal_statuses]
                if non_terminal:
                    running = tuple(
                        f"{str(t.get('name') or t.get('display_title') or 'unknown').strip()}={t.get('status')}"
                        for t in non_terminal
                    )
                    wait_reason = ("running", running)
                    if wait_reason != last_wait_reason:
                        print(f"Awaiting jobs: {', '.join(running)}")
                        last_wait_reason = wait_reason
                    time.sleep(10)
                    continue

                last_wait_reason = None
                failed = [
                    t
                    for t in relevant_tasks
                    if t.get("status") not in {"success", "skipped"}
                ]
                run_id = expected_run_id if expected_run_id is not None else as_int(relevant_tasks[0].get("id"))
                html_url = relevant_tasks[0].get("url", "")
                if not failed:
                    print(f"Workflow run {run_id} completed successfully: {html_url}")
                    return

                failed_statuses = ", ".join(
                    f"{t.get('name', t.get('display_title', 'unknown'))}={t.get('status')}" for t in failed
                )
                raise SystemExit(f"Workflow run {run_id} failed jobs: {failed_statuses}: {html_url}")
            else:
                run = candidates[0]
                run_id = run.get("id")
                status_val = run.get("status")
                conclusion = run.get("conclusion")
                html_url = run.get("html_url", run.get("url", ""))
                run_state = (status_val, conclusion)
                if run_state != last_run_state:
                    print(f"Workflow run {run_id}: status={status_val} conclusion={conclusion}")
                    last_run_state = run_state

                if conclusion is None and status_val in {"success", "failure", "cancelled", "skipped"}:
                    conclusion = status_val
                    status_val = "completed"

                if status_val == "completed":
                    if conclusion == "success":
                        print(f"Workflow run {run_id} completed successfully: {html_url}")
                        return
                    raise SystemExit(f"Workflow run {run_id} failed with conclusion={conclusion}: {html_url}")

        time.sleep(10)

    raise SystemExit("Timed out waiting for dispatched pipeline workflow to complete.")


if __name__ == "__main__":
    main()
