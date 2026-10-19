"""Rebuilds the identity provider's mapping from every project's membership record.

Each project building block writes `mappings/<project>.json` to the bucket:

    {"project": "eu-de_app", "groups": {"eu-de_app_admin": ["a@example.com"], ...}}

This function reads all of them and replaces the mapping with a base rule plus one rule per group
that has members. It always rebuilds the whole mapping, so a dropped or out-of-order event is
repaired by the next one, and the timer trigger repairs anything else.

Credentials come from the function's agency: its temporary AK/SK signs OBS requests and its token
calls IAM.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from email.message import Message
from email.utils import formatdate

PREFIX = "mappings/"


def log(message: str) -> None:
    print(f"[idp-mapping] {message}", flush=True)


def send(req: urllib.request.Request) -> tuple[bytes, Message]:
    # The status alone does not say why a call was refused; OBS and IAM explain it in the body.
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.read(), resp.headers
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"{req.get_method()} {req.full_url} answered {e.code}: {e.read().decode(errors='replace')}") from e


class Obs:
    """Just enough of the OBS API to list and read objects, signed with OBS signature V2."""

    def __init__(self, context, region: str, bucket: str):
        self.ak = context.getSecurityAccessKey()
        self.sk = context.getSecuritySecretKey()
        self.token = context.getSecurityToken()
        self.bucket = bucket
        self.host = f"{bucket}.obs.{region}.otc.t-systems.com"

    def _get(self, key: str, query: dict[str, str] | None = None) -> bytes:
        date = formatdate(usegmt=True)
        resource = f"/{self.bucket}/{urllib.parse.quote(key)}"
        string_to_sign = f"GET\n\n\n{date}\nx-obs-security-token:{self.token}\n{resource}"
        signature = base64.b64encode(hmac.new(self.sk.encode(), string_to_sign.encode(), hashlib.sha1).digest()).decode()
        url = f"https://{self.host}/{urllib.parse.quote(key)}"
        if query:
            url += "?" + urllib.parse.urlencode(query)
        req = urllib.request.Request(url, headers={
            "Date": date,
            "x-obs-security-token": self.token,
            "Authorization": f"OBS {self.ak}:{signature}",
        })
        return send(req)[0]

    def keys(self) -> list[str]:
        keys, marker = [], ""
        while True:
            root = ET.fromstring(self._get("", {"prefix": PREFIX, "marker": marker}))
            page = [e.text for e in root.iter() if _tag(e) == "Key"]
            keys += page
            truncated = next((e.text for e in root.iter() if _tag(e) == "IsTruncated"), "false")
            if truncated != "true" or not page:
                return [k for k in keys if k.endswith(".json")]
            marker = page[-1]

    def json(self, key: str) -> dict:
        return json.loads(self._get(key))


def _tag(element: ET.Element) -> str:
    # The listing is namespaced; only the local name matters.
    return element.tag.rsplit("}", 1)[-1]


def iam(method: str, path: str, token: str, body: dict | None = None,
        headers: dict[str, str] | None = None) -> tuple[dict, Message]:
    url = os.environ["IAM_ENDPOINT"].rstrip("/") + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "X-Auth-Token": token,
        "Content-Type": "application/json;charset=utf8",
        **(headers or {}),
    })
    raw, response_headers = send(req)
    return (json.loads(raw) if raw else {}), response_headers


def domain_token(token: str) -> str:
    """Rescopes the agency's project token to the domain.

    The agency holds Security Administrator on the domain, but FunctionGraph hands out a token
    scoped to the function's project, and IAM only honours domain roles in a domain-scoped token.
    """
    info, _ = iam("GET", "/auth/tokens", token, headers={"X-Subject-Token": token})
    domain_id = info["token"]["project"]["domain"]["id"]
    _, headers = iam("POST", "/auth/tokens", token, {"auth": {
        "identity": {"methods": ["token"], "token": {"id": token}},
        "scope": {"domain": {"id": domain_id}},
    }})
    return headers["X-Subject-Token"]


def rules(records: list[dict], email_attribute: str, base_group: str) -> list[dict]:
    # Lets any federated user sign in as a virtual user named after their email. Sign-in fails when
    # no rule assigns a group, so this one assigns the base group, which holds no role.
    result = [{
        "local": [{"user": {"name": "{0}"}}, {"group": {"name": base_group}}],
        "remote": [{"type": email_attribute}],
    }]
    for record in sorted(records, key=lambda r: r["project"]):
        for group, emails in sorted(record["groups"].items()):
            if not emails:
                continue
            result.append({
                "local": [{"user": {"name": "{0}"}}, {"groups": json.dumps([group])}],
                "remote": [
                    {"type": email_attribute},
                    {"type": email_attribute, "any_one_of": sorted(emails)},
                ],
            })
    return result


def handler(event, context):
    obs = Obs(context, os.environ["REGION"], os.environ["MAPPING_BUCKET"])
    records = [obs.json(key) for key in obs.keys()]

    token = domain_token(context.getToken())
    idp = os.environ["IDENTITY_PROVIDER"]
    protocols = iam("GET", f"/OS-FEDERATION/identity_providers/{idp}/protocols", token)[0]["protocols"]
    mapping_ids = {p["mapping_id"] for p in protocols}
    if len(mapping_ids) != 1:
        raise RuntimeError(f"identity provider {idp} has mappings {sorted(mapping_ids)}, expected exactly one")
    mapping_id = mapping_ids.pop()

    desired = rules(records, os.environ["EMAIL_ATTRIBUTE"], os.environ["BASE_GROUP"])
    iam("PATCH", f"/OS-FEDERATION/mappings/{mapping_id}", token, {"mapping": {"rules": desired}})
    log(f"mapping {mapping_id} rebuilt from {len(records)} projects: {len(desired)} rules")
    return {"projects": len(records), "rules": len(desired)}
