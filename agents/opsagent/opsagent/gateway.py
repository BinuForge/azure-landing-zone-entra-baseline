"""Calls the model through the AI gateway, the only route to it (ADR-0008, docs/runbooks/ai-gateway.md)."""

from __future__ import annotations

from typing import Any, Dict, List

from .config import Config
from .transport import Client, HttpError

API_VERSION = "2024-10-21"
MAX_COMPLETION_TOKENS = 3000


class Blocked(Exception):
    """The guardrail refused the prompt or the answer. `filters` names what fired, without content."""

    def __init__(self, filters: List[str]):
        super().__init__("guardrail blocked the request")
        self.filters = filters


class Unavailable(Exception):
    """No answer from the model: kill switch, limit, or another gateway error. Safe to log."""


def _fired(result: Any) -> List[str]:
    if not isinstance(result, dict):
        return []
    return sorted(k for k, v in result.items() if isinstance(v, dict) and (v.get("filtered") or v.get("detected")))


class Gateway:
    def __init__(self, client: Client, cfg: Config):
        self._client = client
        self._cfg = cfg

    def chat(self, messages: List[Dict[str, Any]], tools: List[Dict[str, Any]]) -> Dict[str, Any]:
        url = f"{self._cfg.gateway}/deployments/{self._cfg.deployment}/chat/completions?api-version={API_VERSION}"
        body: Dict[str, Any] = {"messages": messages, "max_completion_tokens": MAX_COMPLETION_TOKENS}
        if tools:
            body["tools"] = tools
            body["tool_choice"] = "auto"
        try:
            answer = self._client.call(
                "POST",
                url,
                self._cfg.gateway_audience,
                body=body,
                # The gateway logs the run ID beside the request ID it sends on to Foundry (C-22).
                headers={"x-correlation-id": self._cfg.run_id},
                retries_on_429=3,
            )
        except HttpError as error:
            if error.status == 400 and error.code == "content_filter":
                inner = error.body.get("error", {}).get("innererror", {})
                raise Blocked(_fired(inner.get("content_filter_result", {}))) from None
            if error.status == 503:
                raise Unavailable("gateway disabled (kill switch)") from None
            if error.status == 429:
                raise Unavailable("gateway token limit reached") from None
            raise Unavailable(f"gateway returned {error.status}") from None

        choice = (answer.get("choices") or [{}])[0]
        if choice.get("finish_reason") == "content_filter":
            raise Blocked(_fired(choice.get("content_filter_results", {})))
        return choice.get("message", {})
