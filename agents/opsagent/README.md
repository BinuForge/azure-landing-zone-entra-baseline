# Ops agent

Writes an operations and FinOps report about the lab. The model chooses which named queries to run and
writes the narrative. Code fetches the data, renders every figure in the tables, flags suspicious
content and checks the narrative before anything is stored. If the model is fooled, the worst case is a
bad paragraph that a person reads. It is never a change to Azure, and never a leak.

Standard library Python only: there is nothing to install and no dependency to trust (threat model C-23).

## How a run works

1. `opsagent.yml` signs in as `lab-azure-l4-opsagent-run` with GitHub OIDC, from `main` only (C-10).
2. The runner gets tokens for Azure Resource Manager, Log Analytics, Storage and the AI gateway.
3. The model gets the published [system prompt](system_prompt.md) and five tool definitions. Each tool
   result is redacted, then wrapped as untrusted data before the model sees it.
4. The narrative is sanitised, scanned for identifiers and checked figure by figure. If any check fails,
   or the guardrail blocks the request, or the gateway is off, the narrative is withheld and code runs the
   standard queries so the tables are still complete.
5. The full report goes to the private report store, which the runner can write but not read
   (ADR-0015). The run page shows counts only.

## Tools

| Tool | Parameters | Reads |
|---|---|---|
| `list_resources` | `resource_group`: management, connectivity, dns or opsagent | Resources and tags in that group |
| `cost_by_service` | `days`: 1 to 31 | Cost Management, grouped by service |
| `cost_by_resource_group` | `days`: 1 to 31 | Cost Management, grouped by resource group |
| `advisor_recommendations` | `category`: Cost, Security, HighAvailability, OperationalExcellence or Performance | Azure Advisor |
| `log_ingestion` | `days`: 1 to 31 | Billable ingestion by table in the ops workspace, from a fixed query |

The AI services group is not on the list, and the identity cannot read it (level 4, decision D1).

## Controls in the code

| Control | Where |
|---|---|
| C-01 tool results wrapped as untrusted data, suspicious text flagged by code | `untrusted.py` |
| C-03 no write tools | `tools.py`: every tool is a GET, or a POST that only queries |
| C-05 fixed, named queries with validated parameters; unknown tools refused and logged | `tools.py`, `agent.py` |
| C-11 identifiers replaced with tokens before the model; output scanned | `redact.py`, `agent.py`, `report.py` |
| C-12 full report to the private store, counts only in public | `report.py` |
| C-13 no images, no HTML, links only to Microsoft Learn and this repository | `sanitise.py` |
| C-17 system prompt published, with no secrets or identifiers | `system_prompt.md` |
| C-19 at most 8 tool calls and 4 model turns per run | `config.py`, `agent.py` |
| C-21 every figure in the narrative must appear in a tool result | `figures.py` |
| C-22 run ID sent as `x-correlation-id` on every model call | `gateway.py` |

## Run the tests

```sh
cd agents/opsagent
python3 -B -m unittest discover -s tests -v
```

The tests use fake Azure and gateway answers, including the same planted attacks as the level 4 canary,
and run in the PR gates as `agent-tests`. The same controls are then tested on the live lab by
`agent-live-tests.yml` (`tests/agent/`).

## Run the agent

Turn the gateway on (`docs/runbooks/ai-gateway.md`), then run `opsagent` from the Actions tab. To read a
report, signed in as the maintainer:

```sh
az storage blob list --account-name labstreportsprdae01 --container-name reports --auth-mode login -o table
az storage blob download --account-name labstreportsprdae01 --container-name reports --auth-mode login \
  --name <name> --file report.md
```
