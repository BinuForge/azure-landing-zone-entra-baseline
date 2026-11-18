"""One run: the model picks named queries and writes the narrative; code does everything else.

If the model is fooled, the worst case is a bad paragraph that a person reads: there is no write tool
(C-03), no free-form query (C-05) and no identifier to leak (C-11). If anything goes wrong with the
narrative, the report is still written from code-rendered tables and marked "narrative withheld" (D6).
"""

from __future__ import annotations

import json
import pathlib
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

from . import figures
from .config import MAX_MODEL_TURNS, MAX_TOOL_CALLS, Config
from .gateway import Blocked, Gateway, Unavailable
from .redact import Redactor, scan
from .sanitise import sanitise
from .tools import TOOLS, Refused, default_calls, validate
from .transport import Client, HttpError
from .untrusted import Flag, flags, wrap

SYSTEM_PROMPT = pathlib.Path(__file__).resolve().parent.parent / "system_prompt.md"


@dataclass
class Call:
    name: str
    args: Dict[str, Any]
    status: str  # ok, error <status>, refused
    data: Optional[Dict[str, Any]] = None
    by: str = "model"


@dataclass
class Outcome:
    narrative: Optional[str]
    withheld: Optional[str]
    calls: List[Call] = field(default_factory=list)
    flags: List[Flag] = field(default_factory=list)
    refused: int = 0
    removed: int = 0
    figures_checked: int = 0
    blocked_by: List[str] = field(default_factory=list)


def _safe_name(value: Any) -> str:
    text = "".join(c for c in str(value) if c.isalnum() or c in "_-")[:40]
    return text or "(empty)"


class Agent:
    def __init__(self, cfg: Config, client: Client, gateway: Gateway, log=print):
        self.cfg = cfg
        self.client = client
        self.gateway = gateway
        self.redactor = Redactor(cfg.subscription_id, cfg.tenant_id)
        self.log = log

    def _run_tool(self, name: str, args: Dict[str, Any], by: str) -> Call:
        tool = TOOLS[name]
        try:
            data = self.redactor.data(tool.run(self.client, self.cfg, args))
            call = Call(name, args, "ok", data, by)
        except HttpError as error:
            call = Call(name, args, f"error {error.status}", None, by)
        # Logs are public: tool name, parameters from a fixed list, and the status only.
        self.log(f"tool {name} {json.dumps(args, sort_keys=True)} by {by}: {call.status}")
        return call

    def run(self) -> Outcome:
        outcome = Outcome(narrative=None, withheld=None)
        messages: List[Dict[str, Any]] = [
            {"role": "system", "content": SYSTEM_PROMPT.read_text()},
            {"role": "user", "content": f"Write the report for the last {self.cfg.days} days."},
        ]
        specs = [t.spec() for t in TOOLS.values()]
        model_calls = 0
        text: Optional[str] = None

        try:
            for _ in range(MAX_MODEL_TURNS):
                message = self.gateway.chat(messages, specs)
                requested = message.get("tool_calls") or []
                if not requested:
                    text = message.get("content") or ""
                    break
                if model_calls + len(requested) > MAX_TOOL_CALLS:
                    outcome.withheld = f"tool call limit of {MAX_TOOL_CALLS} reached"
                    break
                messages.append({"role": "assistant", "content": message.get("content"), "tool_calls": requested})
                for request in requested:
                    model_calls += 1
                    content = self._handle(request, outcome)
                    messages.append({"role": "tool", "tool_call_id": request.get("id", ""), "content": content})
            else:
                outcome.withheld = f"no answer after {MAX_MODEL_TURNS} model turns"
        except Blocked as blocked:
            outcome.withheld = "the guardrail blocked the request"
            outcome.blocked_by = blocked.filters
        except Unavailable as error:
            outcome.withheld = str(error)

        if text is not None and outcome.withheld is None:
            self._check(text, outcome)

        if outcome.withheld:
            self._fill_tables(outcome)
        for call in outcome.calls:
            if call.data is not None:
                outcome.flags.extend(flags(call.name, call.data))
        return outcome

    def _handle(self, request: Dict[str, Any], outcome: Outcome) -> str:
        function = request.get("function") or {}
        name = function.get("name")
        try:
            if name not in TOOLS:
                raise Refused(f"unknown tool {_safe_name(name)}")
            try:
                raw_args = json.loads(function.get("arguments") or "{}")
            except ValueError:
                raise Refused(f"{name}: arguments are not JSON") from None
            args = validate(TOOLS[name], raw_args)
        except Refused as refused:
            outcome.refused += 1
            self.log(f"refused: {refused}")
            outcome.calls.append(Call(_safe_name(name), {}, "refused"))
            return json.dumps({"error": f"Refused: {refused}. Only the listed tools and values are allowed."})

        call = self._run_tool(name, args, "model")
        outcome.calls.append(call)
        if call.data is None:
            return json.dumps({"error": f"The query failed with {call.status}."})
        return wrap(call.data)

    def _check(self, text: str, outcome: Outcome) -> None:
        clean, outcome.removed = sanitise(text, self.cfg.repository)
        left = scan(clean)
        if left:
            outcome.withheld = f"identifiers in the narrative ({', '.join(left)})"
            return
        known = figures.known_numbers([c.data for c in outcome.calls if c.data] + [c.args for c in outcome.calls])
        known.update({float(self.cfg.days), float(MAX_TOOL_CALLS)})
        missing = figures.unsupported(clean, known)
        outcome.figures_checked = len(figures.NUMBER.findall(figures.LIST_MARKER.sub(r"\1", clean)))
        if missing:
            outcome.withheld = f"figures not found in any tool result: {', '.join(missing[:5])}"
            return
        if not clean.strip():
            outcome.withheld = "the model returned no text"
            return
        outcome.narrative = clean

    def _fill_tables(self, outcome: Outcome) -> None:
        done = {(c.name, json.dumps(c.args, sort_keys=True)) for c in outcome.calls if c.data is not None}
        for planned in default_calls(self.cfg.days):
            key = (planned["name"], json.dumps(planned["args"], sort_keys=True))
            if key not in done:
                outcome.calls.append(self._run_tool(planned["name"], planned["args"], "code"))
