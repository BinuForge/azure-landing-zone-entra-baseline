"""Every figure in the narrative must appear in a tool result (threat model C-21, test T-12).

A figure matches when a tool value rounds to it at the precision the narrative used, so 12.3456 in a tool
result allows 12.35 or 12.3 in the text. Numbers that are part of a name or token (lab-nsg-01, T-01,
[guid-2], gpt-5) are not figures. Numbered list markers are ignored.
"""

from __future__ import annotations

import re
from typing import Any, Iterable, List, Set

NUMBER = re.compile(r"(?<![\w.\-\[/])(\d{1,3}(?:,\d{3})+|\d+)(\.\d+)?(?![\w\-\]/]|\.\d)")
LIST_MARKER = re.compile(r"^(\s*)\d+[.)]\s", re.MULTILINE)


def _numbers_in_text(text: str) -> List[float]:
    return [float((m.group(1) + (m.group(2) or "")).replace(",", "")) for m in NUMBER.finditer(text)]


def known_numbers(values: Iterable[Any]) -> Set[float]:
    found: Set[float] = set()

    def walk(value: Any) -> None:
        if isinstance(value, bool):
            return
        if isinstance(value, (int, float)):
            found.add(float(value))
        elif isinstance(value, str):
            found.update(_numbers_in_text(value))
        elif isinstance(value, dict):
            for v in value.values():
                walk(v)
        elif isinstance(value, list):
            for v in value:
                walk(v)

    for value in values:
        walk(value)
    return found


def unsupported(narrative: str, known: Set[float]) -> List[str]:
    """Figures in the narrative that no tool result supports, as written."""
    text = LIST_MARKER.sub(r"\1", narrative)
    missing = []
    for match in NUMBER.finditer(text):
        written = match.group(1) + (match.group(2) or "")
        places = len(match.group(2)) - 1 if match.group(2) else 0
        value = float(written.replace(",", ""))
        if not any(abs(round(k, places) - value) < 1e-9 for k in known):
            missing.append(written)
    return missing
