#!/usr/bin/env python3
"""Post, update or delete the sticky PR comment that shows the terraform-docs diff.

Usage: ci/terraform_docs_pr_comment.py <stat file> <diff file>
"""

import json
import os
import sys
import urllib.request
from pathlib import Path
from typing import Any

MARKER = "<!-- terraform-docs -->"
MAX_DIFF_LENGTH = 50000
BODY = (
    MARKER
    + """
## terraform-docs

After this PR is merged, CI regenerates the `BEGIN_TF_DOCS` sections of these READMEs on `main`.
Leave these sections as they are and do not run terraform-docs. This applies to people and AI agents alike.

<details><summary>Changes CI will make</summary>

```
{stat}
```

````diff
{diff}
````

</details>"""
)


class GitHub:
    def __init__(self, repo: str) -> None:
        self.base_url = f"{os.environ.get('GITHUB_API_URL', 'https://api.github.com')}/repos/{repo}"
        self.token = os.environ["GITHUB_TOKEN"]

    def request(self, method: str, path: str, payload: dict[str, str] | None = None) -> bytes:
        request = urllib.request.Request(  # noqa: S310
            f"{self.base_url}{path}",
            method=method,
            data=None if payload is None else json.dumps(payload).encode(),
            headers={
                "Accept": "application/vnd.github+json",
                "Authorization": f"Bearer {self.token}",
                "X-GitHub-Api-Version": "2022-11-28",
            },
        )
        with urllib.request.urlopen(request, timeout=30) as response:  # noqa: S310
            return response.read()

    def find_comment(self, issue_number: int) -> dict[str, Any] | None:
        page = 1
        while True:
            comments: list[dict[str, Any]] = json.loads(
                self.request("GET", f"/issues/{issue_number}/comments?per_page=100&page={page}")
            )
            if not comments:
                return None
            for comment in comments:
                if MARKER in (comment["body"] or ""):
                    return comment
            page += 1


def main() -> None:
    stat_file, diff_file = (Path(arg) for arg in sys.argv[1:3])
    stat = stat_file.read_text().strip()
    diff = diff_file.read_text().strip()
    if len(diff) > MAX_DIFF_LENGTH:
        diff = diff[:MAX_DIFF_LENGTH] + "\n... diff truncated"
    body = BODY.format(stat=stat, diff=diff)

    if diff:
        with Path(os.environ["GITHUB_STEP_SUMMARY"]).open("a") as summary:
            summary.write(body + "\n")

    pull_request = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())["pull_request"]
    head_repo = (pull_request["head"]["repo"] or {}).get("full_name")
    base_repo = pull_request["base"]["repo"]["full_name"]
    # A pull request from a fork gets a read-only token.
    if head_repo != base_repo:
        print("Pull request from a fork, the job summary holds the result")
        return

    github = GitHub(base_repo)
    issue_number = pull_request["number"]
    existing = github.find_comment(issue_number)

    if not diff:
        if existing:
            github.request("DELETE", f"/issues/comments/{existing['id']}")
            print(f"Deleted terraform-docs comment {existing['id']}")
        return

    if existing:
        github.request("PATCH", f"/issues/comments/{existing['id']}", {"body": body})
        print(f"Updated terraform-docs comment {existing['id']}")
    else:
        comment: dict[str, Any] = json.loads(github.request("POST", f"/issues/{issue_number}/comments", {"body": body}))
        print(f"Created terraform-docs comment {comment['id']}")


if __name__ == "__main__":
    main()
