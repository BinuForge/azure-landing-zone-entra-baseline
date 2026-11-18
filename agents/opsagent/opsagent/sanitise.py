"""Model output is sanitised before it is stored (threat model C-13, test T-09).

No images, even from an allowed host, because rendering one sends a request. No HTML. Links only to
Microsoft Learn and this repository; any other link keeps its text and loses its target.
"""

from __future__ import annotations

import re
from typing import Tuple
from urllib.parse import urlparse

IMAGE = re.compile(r"!\[[^\]\n]*\](?:\([^)\n]*\)|\[[^\]\n]*\])")
HTML = re.compile(r"</?[A-Za-z!][^>\n]*>")
LINK = re.compile(r"\[([^\]\n]+)\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"\n]*\")?\s*\)")
REFERENCE = re.compile(r"^[ \t]*\[[^\]\n]+\]:[ \t]*(\S+).*$", re.MULTILINE)
BARE_URL = re.compile(r"(?<!\]\()\b(?:https?|ftp|data|javascript|file):[^\s)\]>]*", re.IGNORECASE)


def allowed(url: str, repository: str) -> bool:
    parsed = urlparse(url)
    if parsed.scheme != "https" or parsed.username or parsed.password or parsed.port:
        return False
    host = (parsed.hostname or "").lower()
    if host == "learn.microsoft.com":
        return True
    return host == "github.com" and (parsed.path + "/").startswith(f"/{repository}/")


def sanitise(text: str, repository: str) -> Tuple[str, int]:
    """Returns the cleaned text and how many items were removed."""
    removed = 0

    def count(replacement: str):
        def inner(_: "re.Match[str]") -> str:
            nonlocal removed
            removed += 1
            return replacement

        return inner

    text = IMAGE.sub(count("[image removed]"), text)
    text = HTML.sub(count(""), text)

    def link(match: "re.Match[str]") -> str:
        nonlocal removed
        if allowed(match.group(2), repository):
            return match.group(0)
        removed += 1
        return f"{match.group(1)} [link removed]"

    text = LINK.sub(link, text)

    def reference(match: "re.Match[str]") -> str:
        nonlocal removed
        if allowed(match.group(1), repository):
            return match.group(0)
        removed += 1
        return "[link removed]"

    text = REFERENCE.sub(reference, text)

    def bare(match: "re.Match[str]") -> str:
        nonlocal removed
        if allowed(match.group(0), repository):
            return match.group(0)
        removed += 1
        return "[link removed]"

    text = BARE_URL.sub(bare, text)
    return text, removed
