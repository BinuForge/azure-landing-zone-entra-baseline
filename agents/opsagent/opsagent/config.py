"""Run settings and the names the runner builds.

The runner cannot read Terraform state, so it builds names the way the levels do (docs/naming.md), as the
gateway tests do (tests/gateway/lib.sh).
"""

from __future__ import annotations

import os
import re
from dataclasses import dataclass
from typing import Dict, Mapping

GUID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
PREFIX = re.compile(r"^[a-z]{2,5}$")

MAX_DAYS = 31

# Hard limits for one run (threat model C-19).
MAX_TOOL_CALLS = 8
MAX_MODEL_TURNS = 4


class ConfigError(ValueError):
    pass


@dataclass(frozen=True)
class Config:
    prefix: str
    tenant_id: str
    subscription_id: str
    run_id: str
    run_attempt: str
    days: int
    repository: str

    @property
    def resource_groups(self) -> Dict[str, str]:
        # The groups the runner's config reader covers (level 4 rbac.tf). AI services is not one of them (D1).
        p = self.prefix
        return {
            "management": f"{p}-rg-management-prd-ae",
            "connectivity": f"{p}-rg-connectivity-prd-ae",
            "dns": f"{p}-rg-dns-prd-ae",
            "opsagent": f"{p}-rg-opsagent-np-ae",
        }

    @property
    def ops_workspace_id(self) -> str:
        return (
            f"/subscriptions/{self.subscription_id}/resourceGroups/{self.resource_groups['management']}"
            f"/providers/Microsoft.OperationalInsights/workspaces/{self.prefix}-log-management-prd-ae"
        )

    @property
    def gateway(self) -> str:
        return f"https://{self.prefix}-apim-aiservices-prd-ae.azure-api.net/openai"

    @property
    def gateway_audience(self) -> str:
        return f"api://{self.tenant_id}/{self.prefix}-aigateway"

    @property
    def deployment(self) -> str:
        return "gpt-5-mini"

    @property
    def report_container(self) -> str:
        return f"https://{self.prefix}streportsprdae01.blob.core.windows.net/reports"

    @classmethod
    def from_env(cls, env: Mapping[str, str] = os.environ) -> "Config":
        def need(name: str) -> str:
            value = env.get(name, "").strip()
            if not value:
                raise ConfigError(f"{name} is not set")
            return value

        prefix = env.get("OPSAGENT_PREFIX", "lab")
        if not PREFIX.match(prefix):
            raise ConfigError("OPSAGENT_PREFIX must be 2 to 5 lowercase letters")

        tenant_id = need("AZURE_TENANT_ID").lower()
        subscription_id = need("AZURE_SUBSCRIPTION_ID").lower()
        for name, value in (("AZURE_TENANT_ID", tenant_id), ("AZURE_SUBSCRIPTION_ID", subscription_id)):
            if not GUID.match(value):
                raise ConfigError(f"{name} must be a GUID")

        days_text = env.get("OPSAGENT_DAYS", "7").strip()
        if not days_text.isdigit() or not 1 <= int(days_text) <= MAX_DAYS:
            raise ConfigError(f"OPSAGENT_DAYS must be a whole number from 1 to {MAX_DAYS}")

        run_id = env.get("GITHUB_RUN_ID", "local")
        run_attempt = env.get("GITHUB_RUN_ATTEMPT", "1")
        if not re.match(r"^[0-9]+$|^local$", run_id) or not run_attempt.isdigit():
            raise ConfigError("GITHUB_RUN_ID and GITHUB_RUN_ATTEMPT must be numbers")

        return cls(
            prefix=prefix,
            tenant_id=tenant_id,
            subscription_id=subscription_id,
            run_id=run_id,
            run_attempt=run_attempt,
            days=int(days_text),
            repository=env.get("GITHUB_REPOSITORY", "BinuForge/azure-landing-zone-entra-baseline"),
        )
