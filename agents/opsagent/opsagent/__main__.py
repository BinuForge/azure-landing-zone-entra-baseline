"""Entry point: `python3 -m opsagent` from agents/opsagent, in a job signed in as the runner identity."""

from __future__ import annotations

import datetime as dt
import os
import sys

from .agent import Agent
from .config import Config, ConfigError
from .gateway import Gateway
from .report import blob_name, render, store, summary
from .transport import ARM, LOG_ANALYTICS, STORAGE, Client, HttpError, az_token


def main() -> int:
    try:
        cfg = Config.from_env()
    except ConfigError as error:
        print(f"Configuration: {error}", file=sys.stderr)
        return 2

    tokens = {aud: az_token(aud) for aud in (ARM, LOG_ANALYTICS, STORAGE, cfg.gateway_audience)}
    client = Client(tokens)
    outcome = Agent(cfg, client, Gateway(client, cfg)).run()

    now = dt.datetime.now(dt.timezone.utc)
    text = render(cfg, outcome, now)
    stored = False
    try:
        store(client, cfg, blob_name(cfg, now), text)
        stored = True
    except HttpError as error:
        print(f"Report store: {error}", file=sys.stderr)
    except RuntimeError as error:
        print(str(error), file=sys.stderr)

    public = summary(cfg, outcome, stored)
    print(public)
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a", encoding="utf-8") as handle:
            handle.write(public)
    return 0 if stored else 1


if __name__ == "__main__":
    sys.exit(main())
