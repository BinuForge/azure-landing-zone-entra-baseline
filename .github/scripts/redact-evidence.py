"""Redacts an evidence pack in place, then fails if anything identifying is left (threat model T-08).

    python3 .github/scripts/redact-evidence.py <pack-dir>

Every GUID becomes a stable token (<guid-1>, <guid-2>, ...) so files stay readable and consistent with
each other. The subscription and tenant get named tokens. Nothing is attested until this passes.
"""

import os
import pathlib
import re
import sys

GUID = re.compile(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
IPV4 = re.compile(r"(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?:/\d{1,2})?(?![\d.])")
TENANT_DOMAIN = re.compile(r"[a-z0-9-]+\.onmicrosoft\.com", re.IGNORECASE)
EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")


def main(pack: pathlib.Path) -> int:
    files = sorted(p for p in pack.rglob("*") if p.is_file())
    named = {}
    for env_name, token in (("AZURE_SUBSCRIPTION_ID", "<subscription>"), ("AZURE_TENANT_ID", "<tenant>")):
        value = os.environ.get(env_name, "").lower()
        if value:
            named[value] = token

    tokens = dict(named)

    def replace(match: re.Match) -> str:
        key = match.group(0).lower()
        if key not in tokens:
            tokens[key] = f"<guid-{len(tokens) - len(named) + 1}>"
        return tokens[key]

    for path in files:
        text = path.read_text()
        text = GUID.sub(replace, text)
        text = TENANT_DOMAIN.sub("<tenant-domain>", text)
        text = EMAIL.sub("<email>", text)
        path.write_text(text)

    problems = []
    for path in files:
        text = path.read_text()
        for name, pattern in (("GUID", GUID), ("IP address", IPV4), ("tenant domain", TENANT_DOMAIN), ("email", EMAIL)):
            for match in pattern.finditer(text):
                problems.append(f"{path.relative_to(pack)}: {name} {match.group(0)!r}")

    if problems:
        print("Identifying values remain; nothing will be attested:", file=sys.stderr)
        print("\n".join(problems), file=sys.stderr)
        return 1

    print(f"Redacted {len(tokens)} identifiers across {len(files)} files; scan clean.")
    return 0


if __name__ == "__main__":
    sys.exit(main(pathlib.Path(sys.argv[1])))
