"""Identifiers become stable tokens before the model sees them, and output is scanned (threat model C-11).

Tokens use square brackets, such as [guid-1], so the sanitiser's HTML rule cannot mistake them for tags.
The model only ever sees tokens, and reports are built from the same tokenised data, so no step needs to
put real values back.
"""

from __future__ import annotations

import re
from typing import Any, Dict, List

GUID = re.compile(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
IPV4 = re.compile(r"(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?:/\d{1,2})?(?![\d.])")
TENANT_DOMAIN = re.compile(r"[a-z0-9-]+\.onmicrosoft\.com", re.IGNORECASE)
EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")

PATTERNS = (("GUID", GUID), ("IP address", IPV4), ("tenant domain", TENANT_DOMAIN), ("email", EMAIL))


class Redactor:
    def __init__(self, subscription_id: str, tenant_id: str):
        self._named = {subscription_id.lower(): "[subscription]", tenant_id.lower(): "[tenant]"}
        self._tokens: Dict[str, str] = dict(self._named)
        self._ips: Dict[str, str] = {}

    def _guid(self, match: "re.Match[str]") -> str:
        key = match.group(0).lower()
        if key not in self._tokens:
            self._tokens[key] = f"[guid-{len(self._tokens) - len(self._named) + 1}]"
        return self._tokens[key]

    def _ip(self, match: "re.Match[str]") -> str:
        key = match.group(0)
        if key not in self._ips:
            self._ips[key] = f"[ip-{len(self._ips) + 1}]"
        return self._ips[key]

    def text(self, value: str) -> str:
        value = GUID.sub(self._guid, value)
        value = IPV4.sub(self._ip, value)
        value = TENANT_DOMAIN.sub("[tenant-domain]", value)
        return EMAIL.sub("[email]", value)

    def data(self, value: Any) -> Any:
        if isinstance(value, str):
            return self.text(value)
        if isinstance(value, dict):
            return {self.text(str(k)): self.data(v) for k, v in value.items()}
        if isinstance(value, list):
            return [self.data(v) for v in value]
        return value


def scan(text: str) -> List[str]:
    """Kinds of identifier left in the text. Empty means clean."""
    return sorted({name for name, pattern in PATTERNS if pattern.search(text)})
