#!/usr/bin/env python3
"""Best-effort STACKIT organization membership onboarding."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

SUMMARY_FILE = Path("stackit_organization_membership_summary.md")
AUTHORIZATION_ENDPOINT = "https://authorization.api.stackit.cloud"
TOKEN_ENDPOINT = "https://accounts.stackit.cloud/oauth/v2/token"
DEFAULT_ORGANIZATION_ROLE = "organization.viewer"
DEFAULT_FEDERATED_TOKEN_FILE = "/var/run/secrets/stackit.cloud/serviceaccount/token"
WIF_CLIENT_ASSERTION_TYPE = "urn:schwarz:params:oauth:client-assertion-type:workload-jwt"


def info(message: str) -> None:
    print(f"[stackit-org-membership] {message}")


def warn(message: str) -> None:
    print(f"[stackit-org-membership] WARN: {message}", file=sys.stderr)
    if user_message_file := os.environ.get("MESHSTACK_USER_MESSAGE"):
        with open(user_message_file, "a", encoding="utf-8") as handle:
            handle.write(f"STACKIT organization membership warning: {message}\n")


def request(
    method: str,
    url: str,
    *,
    token: str | None = None,
    json_body: dict | None = None,
    form_body: dict | None = None,
) -> tuple[int, str]:
    headers = {}
    data = None

    if token:
        headers["Authorization"] = f"Bearer {token}"

    if json_body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(json_body).encode("utf-8")

    if form_body is not None:
        headers["Content-Type"] = "application/x-www-form-urlencoded"
        data = urllib.parse.urlencode(form_body).encode("utf-8")

    try:
        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        with urllib.request.urlopen(req, timeout=30) as response:
            return response.status, response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode("utf-8", errors="replace")
    except urllib.error.URLError as error:
        return 0, str(error.reason)


def extract_emails(run_input: str) -> list[str]:
    run = json.loads(run_input)
    inputs = run["spec"]["buildingBlock"]["spec"]["inputs"]
    users_input = next(item for item in inputs if item["key"] == "users")
    users = json.loads(users_input["value"])
    return sorted({user["email"].strip().lower() for user in users})


def get_access_token() -> str:
    if token := os.environ.get("STACKIT_ACCESS_TOKEN"):
        return token

    token_file = Path(os.environ.get("STACKIT_FEDERATED_TOKEN_FILE", DEFAULT_FEDERATED_TOKEN_FILE))
    code, body = request(
        "POST",
        os.environ.get("STACKIT_IDP_TOKEN_ENDPOINT", TOKEN_ENDPOINT),
        form_body={
            "grant_type": "client_credentials",
            "client_assertion_type": WIF_CLIENT_ASSERTION_TYPE,
            "client_assertion": token_file.read_text(encoding="utf-8").strip(),
            "client_id": os.environ["STACKIT_SERVICE_ACCOUNT_EMAIL"],
        },
    )

    if not 200 <= code < 300:
        warn(f"token exchange returned HTTP {code}: {body[:500]}")
        return ""

    token = json.loads(body).get("access_token", "")
    if not token:
        warn("token exchange response did not contain an access_token")
    return token


def add_member(organization_id: str, role: str, email: str, token: str) -> dict[str, str]:
    code, body = request(
        "PATCH",
        f"{AUTHORIZATION_ENDPOINT}/v2/{urllib.parse.quote(organization_id, safe='')}/members",
        token=token,
        json_body={"resourceType": "organization", "members": [{"subject": email, "role": role}]},
    )

    if 200 <= code < 300:
        return {"status": "succeeded", "details": "Add request succeeded."}

    details = f"Add request returned HTTP {code}: {body[:300]}"
    warn(f"{email}: {details}")
    return {"status": "failed", "details": details}


def get_assignment(organization_id: str, role: str, email: str, token: str) -> dict[str, str]:
    org = urllib.parse.quote(organization_id, safe="")
    subject = urllib.parse.quote(email, safe="")
    code, body = request(
        "GET",
        f"{AUTHORIZATION_ENDPOINT}/v2/organization/{org}/members?subject={subject}",
        token=token,
    )

    if not 200 <= code < 300:
        return {
            "status": "unknown",
            "details": f"Could not query organization membership. STACKIT API returned HTTP '{code}'.",
        }

    roles = sorted(
        {
            member["role"]
            for member in json.loads(body).get("members", [])
            if member["subject"].lower() == email
        }
    )

    if role in roles:
        return {"status": "assigned", "details": "Required organization role is assigned."}

    if roles:
        current_roles = ", ".join(f"`{current_role}`" for current_role in roles)
        return {
            "status": "missing",
            "details": f"Current organization roles: {current_roles}; missing required role `{role}`.",
        }

    return {
        "status": "missing",
        "details": "No organization membership for this user was returned by STACKIT.",
    }


def make_row(
    email: str,
    role: str,
    add_status: str,
    add_details: str,
    assignment_status: str,
    assignment_details: str,
) -> dict[str, str]:
    return {
        "email": email,
        "role": role,
        "add_status": add_status,
        "add_details": add_details,
        "assignment_status": assignment_status,
        "assignment_details": assignment_details,
    }


def markdown_cell(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ")


def write_summary(organization_id: str, role: str, rows: list[dict[str, str]]) -> None:
    lines = [
        "# STACKIT Organization Membership",
        "",
        "The pre-run script adds all meshStack users assigned to this project to the STACKIT organization with the required organization role, then checks the resulting membership status before project-level role assignments are applied.",
        "",
        f"- **Organization ID**: `{organization_id}`",
        f"- **Required organization role**: `{role}`",
        "",
        "| User | Required role | Add request | Current assignment | Details |",
        "|------|---------------|-------------|--------------------|---------|",
    ]

    for row in rows:
        add_icon = {"succeeded": "✅", "failed": "⚠️", "skipped": "❓"}[row["add_status"]]
        assignment_icon = {"assigned": "✅", "missing": "⚠️", "unknown": "❓"}[
            row["assignment_status"]
        ]
        details = " ".join([row["add_details"], row["assignment_details"]]).strip()
        lines.append(
            "| "
            f"`{markdown_cell(row['email'])}` | "
            f"`{markdown_cell(row['role'])}` | "
            f"{add_icon} {markdown_cell(row['add_status'])} | "
            f"{assignment_icon} {markdown_cell(row['assignment_status'])} | "
            f"{markdown_cell(details)} |"
        )

    has_problem = any(
        row["add_status"] == "failed" or row["assignment_status"] in {"missing", "unknown"}
        for row in rows
    )
    if has_problem:
        lines += [
            "",
            "## How to fix missing access",
            "",
            "- If **Add request** is **failed**, verify that the building block service account has the STACKIT organization role `iam.member-admin` and that Workload Identity Federation is configured correctly. Then re-run this building block.",
            f"- If **Current assignment** is **missing**, ask a STACKIT organization administrator to add the user to organization `{organization_id}` with role `{role}`, then re-run this building block.",
            "- If **Current assignment** is **unknown**, verify API access for querying organization members and re-run this building block.",
        ]

    SUMMARY_FILE.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1].upper() == "DESTROY":
        info("destroy run detected; skipping organization membership onboarding")
        return

    organization_id = os.environ["STACKIT_ORGANIZATION_ID"]
    role = os.environ.get("STACKIT_ORGANIZATION_MEMBER_ROLE", DEFAULT_ORGANIZATION_ROLE)
    emails = extract_emails(sys.stdin.read())

    if not emails:
        info("no users found; skipping organization membership onboarding")
        write_summary(organization_id, role, [])
        return

    info(f"ensuring {len(emails)} user(s) have organization role '{role}' on '{organization_id}'")

    token = get_access_token()
    if not token:
        write_summary(
            organization_id,
            role,
            [
                make_row(
                    email,
                    role,
                    "skipped",
                    "Could not obtain a STACKIT access token, so no add request was made.",
                    "unknown",
                    "Membership could not be checked.",
                )
                for email in emails
            ],
        )
        return

    rows = []
    for email in emails:
        add = add_member(organization_id, role, email, token)
        assignment = get_assignment(organization_id, role, email, token)
        rows.append(
            make_row(
                email,
                role,
                add["status"],
                add["details"],
                assignment["status"],
                assignment["details"],
            )
        )

    write_summary(organization_id, role, rows)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # best-effort pre-run must not block apply
        warn(f"unexpected pre-run failure: {exc}")
        sys.exit(0)
