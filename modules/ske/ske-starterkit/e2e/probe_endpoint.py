#!/usr/bin/env python3
"""Probe a single app endpoint for HTTP 200 over valid TLS.

Terraform `external` data source protocol: reads {"url": ...} as JSON on stdin and prints
{"status": ...} as JSON on stdout. The status is the HTTP status code as a string (e.g. "200")
for a TLS-verified response, or "error: <reason>" if the endpoint stays unreachable / the
certificate stays invalid until the deadline. The caller loops over endpoints with `for_each`.

Why probe here: the building block reaching SUCCEEDED means the app was deployed, but it verifies
nothing about the ingress actually serving traffic with a valid, cert-manager-issued certificate.
TLS is verified against the system trust store (the point of the check — a self-signed or
untrusted cert fails verification). cert-manager issues the certificate asynchronously, so the
URL is retried for a bounded time before giving up.
"""

import json
import ssl
import sys
import time
import urllib.error
import urllib.request

# cert-manager issues the ingress cert asynchronously via a Let's Encrypt HTTP-01 challenge, which
# for a freshly-created per-run hostname routinely lands ~6-9 min after the building block reports
# SUCCEEDED (BB completion only means the app deployed, not that the cert is ready). A 180s deadline
# was marginal even on green runs and made the test flaky; give issuance ample head-room.
DEADLINE_SECONDS = 600
POLL_INTERVAL_SECONDS = 10
REQUEST_TIMEOUT_SECONDS = 15


def probe(url):
    """Return "200" once the URL serves 200 over verified TLS, else the last status/error."""
    ctx = ssl.create_default_context()  # verifies hostname + chain against the system trust store
    deadline = time.monotonic() + DEADLINE_SECONDS
    last = "error: no attempt made"
    while True:
        try:
            with urllib.request.urlopen(
                urllib.request.Request(url, method="GET"),
                timeout=REQUEST_TIMEOUT_SECONDS,
                context=ctx,
            ) as resp:
                if resp.status == 200:
                    return "200"
                last = str(resp.status)  # TLS ok, but not ready yet — keep retrying
        except urllib.error.HTTPError as e:
            last = str(e.code)  # TLS ok, non-2xx (app not ready yet) — keep retrying
        except urllib.error.URLError as e:
            # urlopen wraps a failed TLS handshake in URLError, so a cert-verification failure
            # surfaces here (not as a bare SSLCertVerificationError) — unwrap it for a clear
            # message while cert-manager is still issuing the cert.
            reason = e.reason
            if isinstance(reason, ssl.SSLCertVerificationError):
                last = f"error: tls verification failed: {getattr(reason, 'verify_message', None) or reason}"
            else:
                last = f"error: {e}"
        except OSError as e:
            last = f"error: {e}"
        if time.monotonic() >= deadline:
            return last
        time.sleep(POLL_INTERVAL_SECONDS)


def main():
    query = json.load(sys.stdin)
    print(json.dumps({"status": probe(query["url"])}))


if __name__ == "__main__":
    main()
