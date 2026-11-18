"""The runner's only tools: five named, read-only queries with validated parameters (threat model C-05).

The model picks a tool by name and fills in its parameters. It never supplies a URL, a scope or a query
string: those are fixed here. An unknown tool or a bad parameter is refused before anything is called.
No tool writes (C-03).
"""

from __future__ import annotations

import datetime as dt
from dataclasses import dataclass
from typing import Any, Callable, Dict, List

from .config import MAX_DAYS, Config
from .transport import ARM, LOG_ANALYTICS, Client

ADVISOR_CATEGORIES = ["Cost", "Security", "HighAvailability", "OperationalExcellence", "Performance"]
MAX_ROWS = 25


class Refused(ValueError):
    """The model asked for something outside the fixed list. The message is safe to log."""


@dataclass(frozen=True)
class Tool:
    name: str
    description: str
    parameters: Dict[str, Any]
    run: Callable[[Client, Config, Dict[str, Any]], Dict[str, Any]]

    def spec(self) -> Dict[str, Any]:
        return {
            "type": "function",
            "function": {"name": self.name, "description": self.description, "parameters": self.parameters},
        }


def _days_param() -> Dict[str, Any]:
    return {"type": "integer", "minimum": 1, "maximum": MAX_DAYS, "description": "Days back from today."}


def _schema(properties: Dict[str, Any]) -> Dict[str, Any]:
    return {"type": "object", "properties": properties, "required": list(properties), "additionalProperties": False}


def validate(tool: Tool, args: Any) -> Dict[str, Any]:
    if not isinstance(args, dict):
        raise Refused(f"{tool.name}: arguments must be an object")
    properties = tool.parameters["properties"]
    extra = set(args) - set(properties)
    if extra:
        raise Refused(f"{tool.name}: unknown parameter")
    clean: Dict[str, Any] = {}
    for name, schema in properties.items():
        if name not in args:
            raise Refused(f"{tool.name}: {name} is required")
        value = args[name]
        if schema["type"] == "integer":
            if isinstance(value, bool) or not isinstance(value, int):
                raise Refused(f"{tool.name}: {name} must be a whole number")
            if not schema["minimum"] <= value <= schema["maximum"]:
                raise Refused(f"{tool.name}: {name} is out of range")
        elif schema["type"] == "string":
            if value not in schema["enum"]:
                raise Refused(f"{tool.name}: {name} is not an allowed value")
        clean[name] = value
    return clean


def _period(days: int) -> Dict[str, str]:
    today = dt.datetime.now(dt.timezone.utc).date()
    start = today - dt.timedelta(days=days)
    return {"from": f"{start.isoformat()}T00:00:00Z", "to": f"{today.isoformat()}T23:59:59Z"}


def list_resources(client: Client, cfg: Config, args: Dict[str, Any]) -> Dict[str, Any]:
    group = cfg.resource_groups[args["resource_group"]]
    url = f"{ARM}/subscriptions/{cfg.subscription_id}/resourceGroups/{group}/resources?api-version=2021-04-01&$top=100"
    items = [
        {
            "name": r.get("name", ""),
            "type": r.get("type", ""),
            "location": r.get("location", ""),
            "tags": r.get("tags") or {},
        }
        for r in client.call("GET", url, ARM).get("value", [])
    ]
    return {"resource_group": group, "count": len(items), "items": items[:MAX_ROWS]}


def _cost(client: Client, cfg: Config, days: int, dimension: str, label: str) -> Dict[str, Any]:
    url = f"{ARM}/subscriptions/{cfg.subscription_id}/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
    body = {
        "type": "ActualCost",
        "timeframe": "Custom",
        "timePeriod": _period(days),
        "dataset": {
            "granularity": "None",
            "aggregation": {"totalCost": {"name": "PreTaxCost", "function": "Sum"}},
            "grouping": [{"type": "Dimension", "name": dimension}],
        },
    }
    props = client.call("POST", url, ARM, body=body).get("properties", {})
    names = [c.get("name", "") for c in props.get("columns", [])]
    cost_col = next((i for i, n in enumerate(names) if n in ("PreTaxCost", "Cost", "totalCost")), 0)
    dim_col = names.index(dimension) if dimension in names else 1
    cur_col = names.index("Currency") if "Currency" in names else None
    rows = []
    currency = ""
    for row in props.get("rows", []):
        rows.append({label: str(row[dim_col]) or "(none)", "cost": round(float(row[cost_col]), 2)})
        if cur_col is not None:
            currency = str(row[cur_col])
    rows.sort(key=lambda r: r["cost"], reverse=True)
    return {
        "days": days,
        "currency": currency,
        "total": round(sum(r["cost"] for r in rows), 2),
        "count": len(rows),
        "rows": rows[:MAX_ROWS],
    }


def cost_by_service(client: Client, cfg: Config, args: Dict[str, Any]) -> Dict[str, Any]:
    return _cost(client, cfg, args["days"], "ServiceName", "service")


def cost_by_resource_group(client: Client, cfg: Config, args: Dict[str, Any]) -> Dict[str, Any]:
    return _cost(client, cfg, args["days"], "ResourceGroupName", "resource_group")


def advisor_recommendations(client: Client, cfg: Config, args: Dict[str, Any]) -> Dict[str, Any]:
    category = args["category"]
    url = (
        f"{ARM}/subscriptions/{cfg.subscription_id}/providers/Microsoft.Advisor/recommendations"
        f"?api-version=2023-01-01&$filter=Category eq '{category}'"
    ).replace(" ", "%20")
    items = []
    for r in client.call("GET", url, ARM).get("value", []):
        p = r.get("properties", {})
        short = p.get("shortDescription", {}) or {}
        items.append(
            {
                "impact": p.get("impact", ""),
                "problem": short.get("problem", ""),
                "solution": short.get("solution", ""),
                "resource_type": p.get("impactedField", ""),
                "resource": p.get("impactedValue", ""),
            }
        )
    return {"category": category, "count": len(items), "items": items[:MAX_ROWS]}


def log_ingestion(client: Client, cfg: Config, args: Dict[str, Any]) -> Dict[str, Any]:
    days = args["days"]
    workspace = client.call("GET", f"{ARM}{cfg.ops_workspace_id}?api-version=2023-09-01", ARM)
    customer_id = workspace.get("properties", {}).get("customerId", "")
    # The query is fixed; days is a validated integer, so nothing the model writes reaches KQL.
    query = (
        f"Usage | where TimeGenerated > ago({int(days)}d) | where IsBillable == true "
        "| summarize gb = round(sum(Quantity) / 1000.0, 4) by DataType | order by gb desc"
    )
    result = client.call("POST", f"{LOG_ANALYTICS}/v1/workspaces/{customer_id}/query", LOG_ANALYTICS, body={"query": query})
    table = (result.get("tables") or [{}])[0]
    names = [c.get("name") for c in table.get("columns", [])]
    rows = [dict(zip(names, row)) for row in table.get("rows", [])]
    rows = [{"data_type": str(r.get("DataType", "")), "gb": float(r.get("gb") or 0)} for r in rows]
    return {
        "days": days,
        "total_gb": round(sum(r["gb"] for r in rows), 4),
        "count": len(rows),
        "rows": rows[:MAX_ROWS],
    }


TOOLS: Dict[str, Tool] = {
    t.name: t
    for t in [
        Tool(
            "list_resources",
            "Resources in one lab resource group: name, type, location and tags.",
            _schema({"resource_group": {"type": "string", "enum": ["management", "connectivity", "dns", "opsagent"]}}),
            list_resources,
        ),
        Tool(
            "cost_by_service",
            "Actual cost for the subscription, grouped by Azure service, with the total.",
            _schema({"days": _days_param()}),
            cost_by_service,
        ),
        Tool(
            "cost_by_resource_group",
            "Actual cost for the subscription, grouped by resource group, with the total.",
            _schema({"days": _days_param()}),
            cost_by_resource_group,
        ),
        Tool(
            "advisor_recommendations",
            "Azure Advisor recommendations for the subscription in one category.",
            _schema({"category": {"type": "string", "enum": ADVISOR_CATEGORIES}}),
            advisor_recommendations,
        ),
        Tool(
            "log_ingestion",
            "Billable data ingested into the ops log workspace, by table, in GB, with the total.",
            _schema({"days": _days_param()}),
            log_ingestion,
        ),
    ]
}


def default_calls(days: int) -> List[Dict[str, Any]]:
    """The queries code runs itself when the narrative is withheld, so the report still has its tables."""
    calls: List[Dict[str, Any]] = [{"name": "list_resources", "args": {"resource_group": g}} for g in ["management", "connectivity", "dns", "opsagent"]]
    calls += [
        {"name": "cost_by_service", "args": {"days": days}},
        {"name": "cost_by_resource_group", "args": {"days": days}},
        {"name": "advisor_recommendations", "args": {"category": "Cost"}},
        {"name": "log_ingestion", "args": {"days": days}},
    ]
    return calls
