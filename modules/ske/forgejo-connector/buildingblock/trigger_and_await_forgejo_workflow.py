#!/usr/bin/env python3
"""Dispatch a Forgejo workflow on a specific branch and wait for completion.

Triggers a workflow_dispatch event on the given BRANCH and polls until the run
either fails or every expected job has finished successfully.

Run identification: Forgejo returns HTTP 204 with no body on dispatch, so there
is no run ID to correlate. Instead, we use a timestamp coincidence window
filtering by the dispatched branch to identify the correct run.

Why EXPECTED_JOBS is required (Forgejo API limitation)
------------------------------------------------------
This Forgejo version (11.0.0 / gitea-1.22.0) exposes no run-level status: the
only readable endpoint is /actions/tasks, which returns ONE entry per job with a
per-job `status` and no whole-run rollup. Critically, a job gated by `needs:`
(e.g. `deploy` needs `build_image`) gets NO task entry until its dependency
finishes — so there is a window where the only visible task is `build_image`
in state success. Treating "all currently visible tasks are terminal" as "run
done" therefore reports success before `deploy` has even been scheduled.

To close that race without a run-level status field, the caller must tell us
which jobs make up a run via EXPECTED_JOBS. We only declare success once every
expected job has appeared as a task AND all are terminal-success; any job
failure fails fast (dependents then never run, so we must not keep waiting for
them). A future Forgejo based on gitea >= 1.24 adds run/job Actions API routes
exposing an overall run status+conclusion, which would let us await a run by its
own status without enumerating job names. Caveat: gitea issue #35134 (open as of
1.24.x/1.25) reports that /actions/tasks still omits "Waiting"/blocked jobs until
a runner starts them, so even there prefer the run-level status over re-deriving
completion from the per-job list.

Required environment variables:
  FORGEJO_HOST       – Forgejo instance URL (from provider)
  FORGEJO_API_TOKEN  – API token with repo action scope (from provider)
  REPOSITORY_ID      – numeric repository ID
  BRANCH             – branch to dispatch on (e.g. "dev" or "prod")
  EXPECTED_JOBS      – comma-separated job names that must all succeed
                       (as they appear in /actions/tasks, e.g. "build_image,deploy")

Optional:
  WORKFLOW_NAME      – workflow file name (default: pipeline.yaml)

There is intentionally no in-script timeout: the script polls until the run
reaches a terminal verdict. The caller bounds the wall-clock time instead — the
Terraform provisioner wraps this in `timeout 900` (15 minutes).
"""

import datetime as dt
import os
import time
import urllib.request
import json

COINCIDENCE_WINDOW_SECONDS = 5
TERMINAL_STATUSES = {"success", "failure", "cancelled", "skipped"}
SUCCESS_STATUSES = {"success", "skipped"}
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


def identify_run_tasks(tasks: list[dict], branch: str, dispatch_at: dt.datetime) -> list[dict]:
    """Return the tasks of our dispatched run.

    /actions/tasks returns one entry per job across all recent runs. We select
    the latest run (highest run_number) whose tasks match our branch, the
    workflow_dispatch event and the dispatch coincidence window.
    """
    candidates = []
    for task in tasks:
        if task.get("head_branch") != branch:
            continue
        event = task.get("event")
        if event and event != "workflow_dispatch":
            continue
        created_at = parse_timestamp(task.get("created_at"))
        if created_at and created_at >= dispatch_at - dt.timedelta(seconds=COINCIDENCE_WINDOW_SECONDS):
            candidates.append(task)

    by_run: dict[int, list[dict]] = {}
    for task in candidates:
        rn = as_int(task.get("run_number"), -1)
        if rn >= 0:
            by_run.setdefault(rn, []).append(task)

    return by_run[max(by_run)] if by_run else []


def latest_task_per_job(tasks: list[dict]) -> dict[str, dict]:
    """Collapse to the newest task per job name (handles re-runs)."""
    by_job: dict[str, dict] = {}
    for task in tasks:
        name = str(task.get("name") or "").strip()
        if not name:
            continue
        prev = by_job.get(name)
        if prev is None or as_int(task.get("id")) > as_int(prev.get("id")):
            by_job[name] = task
    return by_job


def evaluate_run(tasks: list[dict], expected_jobs: set[str], seen_job_status: dict[str, str]) -> tuple[str, str]:
    """Return (verdict, detail) where verdict is 'success', 'failure' or 'pending'."""
    by_job = latest_task_per_job(tasks)

    for name, task in by_job.items():
        status = str(task.get("status") or "unknown")
        if seen_job_status.get(name) != status:
            print(f"  Job {name}: {status}")
            seen_job_status[name] = status

    # Fail fast: a failed job means dependent jobs will never be scheduled, so
    # there is no point waiting for the rest of the expected jobs to appear.
    failed = {n: str(t.get("status")) for n, t in by_job.items()
              if str(t.get("status")) in TERMINAL_STATUSES and str(t.get("status")) not in SUCCESS_STATUSES}
    if failed:
        return "failure", ", ".join(f"{n}={s}" for n, s in failed.items())

    # Success requires every expected job to have appeared (a needs-gated job
    # has no task until its dependency completes) and all jobs to be terminal.
    if expected_jobs - set(by_job):
        return "pending", ""
    if any(str(t.get("status")) not in TERMINAL_STATUSES for t in by_job.values()):
        return "pending", ""
    return "success", ""


def main() -> None:
    host = normalize_host(os.environ["FORGEJO_HOST"])
    token = os.environ["FORGEJO_API_TOKEN"]
    repository_id = os.environ["REPOSITORY_ID"]
    workflow_name = os.environ.get("WORKFLOW_NAME", "pipeline.yaml")
    branch = os.environ["BRANCH"]
    expected_jobs = {j.strip() for j in os.environ["EXPECTED_JOBS"].split(",") if j.strip()}
    if not expected_jobs:
        raise SystemExit("EXPECTED_JOBS must list at least one job name")

    _, repo = request_json(host, token, "GET", f"/api/v1/repositories/{repository_id}")
    owner = repo["owner"]["username"]
    repo_name = repo["name"]

    print(f"Dispatching workflow {workflow_name} on branch {branch} for {owner}/{repo_name}")
    print(f"Awaiting jobs: {', '.join(sorted(expected_jobs))}")

    dispatch_at = dt.datetime.now(dt.timezone.utc)
    dispatch_path = f"/api/v1/repos/{owner}/{repo_name}/actions/workflows/{workflow_name}/dispatches"
    status, _ = request_json(host, token, "POST", dispatch_path, {"ref": branch})
    if status not in (200, 201, 202, 204):
        raise SystemExit(f"Workflow dispatch failed with status {status}")

    tasks_path = f"/api/v1/repos/{owner}/{repo_name}/actions/tasks?limit=30"
    print(f"Polling workflow status via {tasks_path}")

    seen_job_status: dict[str, str] = {}
    while True:
        _, payload = request_json(host, token, "GET", tasks_path)
        tasks = identify_run_tasks(payload.get("workflow_runs", []), branch, dispatch_at)
        if tasks:
            verdict, detail = evaluate_run(tasks, expected_jobs, seen_job_status)
            run_id = as_int(tasks[0].get("run_number"))
            url = tasks[0].get("url", "")
            if verdict == "success":
                print(f"Workflow run {run_id} on {branch} completed successfully: {url}")
                return
            if verdict == "failure":
                raise SystemExit(f"Workflow run {run_id} on {branch} failed: {detail}: {url}")

        time.sleep(POLL_INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
