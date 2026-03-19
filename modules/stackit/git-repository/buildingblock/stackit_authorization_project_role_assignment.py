#!/usr/bin/env python3

import base64
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding


def normalize_host(raw_host: str) -> str:
    host = raw_host.strip()
    if not host.startswith(("https://", "http://")):
        host = f"https://{host}"
    return host.rstrip("/")


def b64url_json(data: dict) -> str:
    return base64.urlsafe_b64encode(json.dumps(data, separators=(",", ":")).encode("utf-8")).decode("ascii").rstrip("=")


def b64url_bytes(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


def create_service_account_assertion(service_account_key_raw: str) -> tuple[str, str]:
    service_account_key = json.loads(service_account_key_raw)
    credentials = service_account_key["credentials"]

    kid = credentials["kid"]
    private_key_pem = credentials["privateKey"]

    header = {"alg": "RS512", "typ": "JWT", "kid": kid}
    now = int(time.time())
    payload = {
        "iss": credentials["iss"],
        "sub": credentials["sub"],
        "jti": str(uuid.uuid4()),
        "aud": credentials["aud"],
        "iat": now,
        "exp": now + 3600,
    }

    signing_input = f"{b64url_json(header)}.{b64url_json(payload)}".encode("ascii")
    private_key = serialization.load_pem_private_key(private_key_pem.encode("utf-8"), password=None)
    signature = private_key.sign(signing_input, padding.PKCS1v15(), hashes.SHA512())
    return f"{signing_input.decode('ascii')}.{b64url_bytes(signature)}", credentials["iss"]


def get_access_token_from_service_account_key() -> str:
    key_raw = os.environ.get("STACKIT_SERVICE_ACCOUNT_KEY", "").strip()
    if not key_raw:
        raise KeyError("Missing STACKIT_SERVICE_ACCOUNT_KEY")

    assertion, issuer = create_service_account_assertion(key_raw)
    token_url = os.environ.get("STACKIT_TOKEN_URL", "https://service-account.api.stackit.cloud/token").strip()

    body = urllib.parse.urlencode(
        {
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": assertion,
        }
    ).encode("utf-8")

    req = urllib.request.Request(
        token_url,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
        data=body,
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read().decode("utf-8")
    except urllib.error.HTTPError as err:
        raw_body = err.read().decode("utf-8", errors="replace") if err.fp else ""
        print(
            f"Service account token request failed with HTTP {err.code} for issuer '{issuer}'. Response body: {raw_body}",
            file=sys.stderr,
        )
        raise SystemExit(1) from err

    payload = json.loads(raw) if raw else {}
    access_token = str(payload.get("access_token", "")).strip()
    if not access_token:
        print(f"Service account token response missing access_token for issuer '{issuer}'.", file=sys.stderr)
        raise SystemExit(1)

    return access_token

def is_subject_pending(subject: str, status_code: int, error_payload: dict | object) -> bool:
    if status_code not in (400, 404) or not isinstance(error_payload, dict):
        return False

    message = str(error_payload.get("message", "")).lower()
    if ("subject" in message) and ("not found" in message):
        return True
    if ("subject" in message) and ("subject must be part of the same organization as the resource" in message):
        return True
    return False


def main() -> None:
    subject = os.environ["SUBJECT"].strip()
    role = os.environ["ROLE"].strip()
    resource_id = os.environ["RESOURCE_ID"].strip()
    resource_type = os.environ.get("RESOURCE_TYPE", "project").strip()

    if not subject:
        raise ValueError("SUBJECT must not be empty")
    if not role:
        raise ValueError("ROLE must not be empty")
    if not resource_id:
        raise ValueError("RESOURCE_ID must not be empty")
    if not resource_type:
        raise ValueError("RESOURCE_TYPE must not be empty")

    host = normalize_host(os.environ.get("STACKIT_AUTHORIZATION_BASE_URL", "https://authorization.api.stackit.cloud"))
    token = get_access_token_from_service_account_key()

    payload = {
        "resourceType": resource_type,
        "members": [
            {
                "subject": subject,
                "role": role,
            }
        ],
    }
    body = json.dumps(payload, separators=(",", ":")).encode("utf-8")

    path = f"/v2/{urllib.parse.quote(resource_id, safe='')}/members"
    req = urllib.request.Request(
        f"{host}{path}",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        method="PATCH",
        data=body,
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            status_code = resp.getcode()
            raw_body = resp.read().decode("utf-8")
    except urllib.error.HTTPError as err:
        status_code = err.code
        raw_body = err.read().decode("utf-8", errors="replace") if err.fp else ""
        error_payload = {}
        if raw_body:
            try:
                error_payload = json.loads(raw_body)
            except json.JSONDecodeError:
                error_payload = {"message": raw_body}

        if is_subject_pending(subject, status_code, error_payload):
            print(
                json.dumps(
                    {
                        "http_status_code": str(status_code),
                        "noop": "true",
                        "message": str(error_payload.get("message", "subject not found")),
                    }
                )
            )
            return

        print(
            f"AddMembers failed with HTTP {status_code} for subject '{subject}', role '{role}', resource '{resource_id}'. Response body: {raw_body}",
            file=sys.stderr,
        )
        raise SystemExit(1) from err
    except urllib.error.URLError as err:
        print(f"AddMembers request failed for subject '{subject}': {err}", file=sys.stderr)
        raise SystemExit(1) from err

    if status_code != 200:
        print(
            f"AddMembers returned unexpected HTTP {status_code} for subject '{subject}'. Response body: {raw_body}",
            file=sys.stderr,
        )
        raise SystemExit(1)

    print(
        json.dumps(
            {
                "http_status_code": str(status_code),
                "noop": "false",
            }
        )
    )


if __name__ == "__main__":
    main()
