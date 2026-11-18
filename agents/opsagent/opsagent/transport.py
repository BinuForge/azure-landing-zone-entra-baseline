"""Tokens and HTTPS calls, standard library only (threat model C-23).

Tokens come from the az CLI, which the workflow signs in with GitHub OIDC (.github/scripts/az-login-oidc.sh).
They are fetched once at the start: the OIDC assertion behind them is short-lived, and access tokens last
longer than a run.
"""

from __future__ import annotations

import json
import subprocess
import time
import urllib.error
import urllib.request
from typing import Any, Callable, Dict, Optional, Tuple

ARM = "https://management.azure.com"
LOG_ANALYTICS = "https://api.loganalytics.io"
STORAGE = "https://storage.azure.com"

TIMEOUT_SECONDS = 60


class HttpError(Exception):
    """A non-2xx answer. Carries the status and a short error code, never the response body."""

    def __init__(self, status: int, code: str = "", body: Optional[Dict[str, Any]] = None):
        super().__init__(f"HTTP {status}{' ' + code if code else ''}")
        self.status = status
        self.code = code
        self.body = body or {}


def az_token(resource: str) -> str:
    result = subprocess.run(
        ["az", "account", "get-access-token", "--resource", resource, "--query", "accessToken", "-o", "tsv"],
        capture_output=True,
        text=True,
        check=False,
    )
    token = result.stdout.strip()
    if result.returncode != 0 or not token:
        # stderr can name the tenant or the identity, so it is not repeated.
        raise RuntimeError(f"Could not get a token for {resource}; is the job signed in?")
    return token


Sender = Callable[[urllib.request.Request], Tuple[int, Dict[str, str], bytes]]


def _send(request: urllib.request.Request) -> Tuple[int, Dict[str, str], bytes]:
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:  # noqa: S310 (https only)
            return response.status, dict(response.headers), response.read()
    except urllib.error.HTTPError as error:
        return error.code, dict(error.headers or {}), error.read() or b""


class Client:
    """Calls Azure with a token per audience. `send` is replaced in tests."""

    def __init__(self, tokens: Dict[str, str], send: Sender = _send, sleep: Callable[[float], None] = time.sleep):
        self._tokens = tokens
        self._send = send
        self._sleep = sleep

    def call(
        self,
        method: str,
        url: str,
        audience: str,
        body: Any = None,
        headers: Optional[Dict[str, str]] = None,
        raw: Optional[bytes] = None,
        retries_on_429: int = 0,
    ) -> Dict[str, Any]:
        if not url.startswith("https://"):
            raise ValueError("Only https URLs are called")
        data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
        all_headers = {"Authorization": f"Bearer {self._tokens[audience]}"}
        if body is not None:
            all_headers["Content-Type"] = "application/json"
        all_headers.update(headers or {})

        for attempt in range(retries_on_429 + 1):
            request = urllib.request.Request(url, data=data, method=method, headers=all_headers)
            status, response_headers, payload = self._send(request)
            if status == 429 and attempt < retries_on_429:
                wait = response_headers.get("Retry-After") or response_headers.get("retry-after") or "10"
                self._sleep(min(float(wait) if wait.replace(".", "", 1).isdigit() else 10.0, 60.0))
                continue
            break

        try:
            parsed = json.loads(payload) if payload else {}
        except ValueError:
            parsed = {}
        if not 200 <= status < 300:
            error = parsed.get("error", {}) if isinstance(parsed, dict) else {}
            code = error.get("code", "") if isinstance(error, dict) else ""
            raise HttpError(status, str(code)[:60], parsed if isinstance(parsed, dict) else {})
        return parsed if isinstance(parsed, dict) else {"value": parsed}
