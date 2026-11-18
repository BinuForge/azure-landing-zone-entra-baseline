"""Renders the full report for the private store and the counts-only summary for the public run page.

Every table is rendered by code from tokenised tool results, so no figure in a table comes from the model.
Text from Azure is escaped before it goes into a table, so planted markdown cannot render.
"""

from __future__ import annotations

import datetime as dt
import json
from typing import Any, Dict, List

from .agent import Call, Outcome
from .config import Config
from .redact import scan
from .sanitise import sanitise
from .transport import STORAGE, Client


def _cell(value: Any, repository: str) -> str:
    text, _ = sanitise(str(value), repository)
    for char in "\\`*_[]()!<>|#":
        text = text.replace(char, f"\\{char}")
    return " ".join(text.split())[:200]


def _table(headers: List[str], rows: List[List[Any]], repository: str) -> str:
    if not rows:
        return "_No rows._\n"
    lines = ["| " + " | ".join(headers) + " |", "|" + "---|" * len(headers)]
    lines += ["| " + " | ".join(_cell(v, repository) for v in row) + " |" for row in rows]
    return "\n".join(lines) + "\n"


def _data(call: Call, repository: str) -> str:
    d: Dict[str, Any] = call.data or {}
    if call.name == "list_resources":
        rows = [[i["name"], i["type"], i["location"], "; ".join(f"{k}={v}" for k, v in i["tags"].items())] for i in d["items"]]
        return f"{d['count']} resources.\n\n" + _table(["Name", "Type", "Location", "Tags"], rows, repository)
    if call.name in ("cost_by_service", "cost_by_resource_group"):
        label = "service" if call.name == "cost_by_service" else "resource_group"
        rows = [[r[label], f"{r['cost']:.2f}"] for r in d["rows"]]
        head = f"Total {d['total']:.2f} {d['currency']} over {d['days']} days, {d['count']} rows.\n\n"
        return head + _table([label.replace("_", " ").capitalize(), f"Cost ({d['currency']})"], rows, repository)
    if call.name == "advisor_recommendations":
        rows = [[i["impact"], i["problem"], i["solution"], i["resource"]] for i in d["items"]]
        return f"{d['count']} recommendations.\n\n" + _table(["Impact", "Problem", "Solution", "Resource"], rows, repository)
    if call.name == "log_ingestion":
        rows = [[r["data_type"], f"{r['gb']:.4f}"] for r in d["rows"]]
        return f"Total {d['total_gb']:.4f} GB over {d['days']} days.\n\n" + _table(["Table", "GB"], rows, repository)
    return "_Unknown tool._\n"


def render(cfg: Config, outcome: Outcome, now: dt.datetime) -> str:
    repo = cfg.repository
    out = [
        "# Ops agent report",
        "",
        f"- Run: {cfg.run_id} (attempt {cfg.run_attempt}), {now:%Y-%m-%d %H:%M} UTC, last {cfg.days} days",
        f"- Model: {cfg.deployment} through the AI gateway",
        f"- Narrative: {'written' if outcome.narrative else 'withheld, ' + str(outcome.withheld)}",
        "",
        "## Narrative",
        "",
    ]
    if outcome.narrative:
        out += ["_Written by the model from the tool results below. A person reviews every suggestion._", "", outcome.narrative.strip(), ""]
    else:
        out += [f"Narrative withheld: {outcome.withheld}. The tables below are rendered by code from tool results.", ""]
        if outcome.blocked_by:
            out += [f"Guardrail filters that fired: {', '.join(outcome.blocked_by)}.", ""]

    out += ["## Suspicious content in tool results", ""]
    if outcome.flags:
        out += ["Code flagged this text in Azure data. It was passed to the model as untrusted data only.", ""]
        out.append(_table(["Where", "Why", "Text"], [[f.where, f.reason, f.excerpt] for f in outcome.flags], repo))
    else:
        out += ["None found.", ""]

    out += ["## Tool calls", ""]
    out.append(
        _table(
            ["#", "Tool", "Parameters", "Asked by", "Status"],
            [[i + 1, c.name, json.dumps(c.args, sort_keys=True), c.by, c.status] for i, c in enumerate(outcome.calls)],
            repo,
        )
    )

    out += ["## Data", ""]
    for call in outcome.calls:
        if call.data is not None:
            out += [f"### {call.name} {json.dumps(call.args, sort_keys=True)}", "", _data(call, repo)]

    out += [
        "## Checks",
        "",
        f"- Refused tool requests: {outcome.refused}",
        f"- Items removed by the sanitiser: {outcome.removed}",
        f"- Figures checked against tool results: {outcome.figures_checked}",
        "",
    ]
    return "\n".join(out)


def summary(cfg: Config, outcome: Outcome, stored: bool) -> str:
    """Counts only: this goes on a public run page (C-12, T-08)."""
    ok = sum(1 for c in outcome.calls if c.status == "ok")
    lines = [
        "### Ops agent",
        "",
        "| Check | Result |",
        "|---|---|",
        f"| Narrative | {'written' if outcome.narrative else 'withheld'} |",
        f"| Guardrail blocked | {'yes' if outcome.blocked_by or (outcome.withheld or '').startswith('the guardrail') else 'no'} |",
        f"| Tool calls | {len(outcome.calls)} ({ok} ok, {outcome.refused} refused) |",
        f"| Suspicious items flagged | {len(outcome.flags)} |",
        f"| Items removed by the sanitiser | {outcome.removed} |",
        f"| Report stored privately | {'yes' if stored else 'no'} |",
        "",
    ]
    return "\n".join(lines)


def blob_name(cfg: Config, now: dt.datetime) -> str:
    return f"{now:%Y/%m}/{now:%Y-%m-%d}-run-{cfg.run_id}-{cfg.run_attempt}.md"


def store(client: Client, cfg: Config, name: str, text: str) -> None:
    """Writes the report with the runner's write-only role (ADR-0015). It cannot read it back."""
    problems = scan(text)
    if problems:
        raise RuntimeError(f"Report not stored: identifiers left ({', '.join(problems)})")
    client.call(
        "PUT",
        f"{cfg.report_container}/{name}",
        STORAGE,
        raw=text.encode(),
        headers={
            "x-ms-blob-type": "BlockBlob",
            "x-ms-version": "2023-11-03",
            "Content-Type": "text/markdown; charset=utf-8",
            # Never replace an earlier report; a rerun has its own attempt number.
            "If-None-Match": "*",
        },
    )
