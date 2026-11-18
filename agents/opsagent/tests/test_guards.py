"""Redaction (C-11), sanitising (C-13), the figure check (C-21) and parameter validation (C-05)."""

import unittest

from opsagent import figures
from opsagent.config import Config, ConfigError
from opsagent.redact import Redactor, scan
from opsagent.sanitise import sanitise
from opsagent.tools import TOOLS, Refused, validate

from fakes import IMAGE, SUBSCRIPTION, TENANT

REPO = "BinuForge/azure-landing-zone-entra-baseline"


class Redaction(unittest.TestCase):
    def test_identifiers_become_stable_tokens(self):
        r = Redactor(SUBSCRIPTION, TENANT)
        other = "01234567-89ab-cdef-0123-456789abcdef"
        text = r.text(f"/subscriptions/{SUBSCRIPTION.upper()}/x {other} {other} 10.20.0.0/16 a@b.com c.onmicrosoft.com {TENANT}")
        self.assertEqual(text, "/subscriptions/[subscription]/x [guid-1] [guid-1] [ip-1] [email] [tenant-domain] [tenant]")
        self.assertEqual(scan(text), [])

    def test_nested_data_and_keys_are_redacted(self):
        data = Redactor(SUBSCRIPTION, TENANT).data({SUBSCRIPTION: [{"ip": "192.168.1.4"}], "n": 3})
        self.assertEqual(data, {"[subscription]": [{"ip": "[ip-1]"}], "n": 3})

    def test_scan_finds_each_kind(self):
        self.assertEqual(scan(f"{TENANT} 10.0.0.1 x@y.io t.onmicrosoft.com"), ["GUID", "IP address", "email", "tenant domain"])


class Sanitiser(unittest.TestCase):
    def test_planted_image_is_removed(self):
        text, removed = sanitise(IMAGE, REPO)
        self.assertNotIn("example.invalid", text)
        self.assertIn("[image removed]", text)
        self.assertEqual(removed, 1)

    def test_images_go_even_from_allowed_hosts(self):
        text, _ = sanitise("![x](https://learn.microsoft.com/a.png)", REPO)
        self.assertEqual(text, "[image removed]")

    def test_links_keep_only_allowed_targets(self):
        text, removed = sanitise(
            "[ok](https://learn.microsoft.com/azure/) [repo](https://github.com/BinuForge/azure-landing-zone-entra-baseline/blob/main/README.md) "
            "[bad](https://evil.example/x) [lookalike](https://learn.microsoft.com.evil.example/) [js](javascript:alert(1))",
            REPO,
        )
        self.assertIn("[ok](https://learn.microsoft.com/azure/)", text)
        self.assertIn("[repo](https://github.com/BinuForge/", text)
        for bad in ("evil.example", "javascript"):
            self.assertNotIn(bad, text)
        self.assertEqual(removed, 3)

    def test_other_repositories_are_not_allowed(self):
        text, _ = sanitise("[x](https://github.com/BinuForge/azure-landing-zone-entra-baseline-fake/x)", REPO)
        self.assertIn("[link removed]", text)

    def test_html_reference_links_and_bare_urls_are_removed(self):
        text, removed = sanitise('<img src="https://e.example/p.png"> <b>hi</b>\n[r]: https://e.example/x\nsee http://e.example/y', REPO)
        self.assertNotIn("e.example", text)
        self.assertNotIn("<", text)
        self.assertEqual(removed, 5)

    def test_tokens_survive(self):
        text, removed = sanitise("Owner [guid-1] in [subscription].", REPO)
        self.assertEqual((text, removed), ("Owner [guid-1] in [subscription].", 0))


class Figures(unittest.TestCase):
    known = figures.known_numbers([{"cost": 12.3456, "total": 1234.5, "rows": ["3 items"]}, {"days": 7}])

    def test_figures_from_tool_results_pass_at_their_precision(self):
        self.assertEqual(figures.unsupported("Cost was 12.35, about 12.3 or 12, total 1,234.50 over 7 days; 3 items.", self.known), [])

    def test_invented_figures_fail(self):
        self.assertEqual(figures.unsupported("Spend rose 40% to 99.10.", self.known), ["40", "99.10"])

    def test_names_tokens_and_list_markers_are_not_figures(self):
        text = "1. Check lab-nsg-canary-01 and [guid-2] for T-01 on gpt-5-mini, dated 2026-11-18.\n2) Done"
        self.assertEqual(figures.unsupported(text, set()), [])


class Validation(unittest.TestCase):
    def test_parameters_must_match_the_schema(self):
        days = TOOLS["cost_by_service"]
        self.assertEqual(validate(days, {"days": 7}), {"days": 7})
        for bad in ({}, {"days": 0}, {"days": 32}, {"days": "7"}, {"days": True}, {"days": 7, "scope": "/"}, []):
            with self.subTest(bad=bad), self.assertRaises(Refused):
                validate(days, bad)

    def test_enums_are_closed(self):
        with self.assertRaises(Refused):
            validate(TOOLS["list_resources"], {"resource_group": "aiservices"})
        with self.assertRaises(Refused):
            validate(TOOLS["advisor_recommendations"], {"category": "Cost' or 1 eq 1"})

    def test_there_are_exactly_five_read_only_tools(self):
        self.assertEqual(
            sorted(TOOLS),
            ["advisor_recommendations", "cost_by_resource_group", "cost_by_service", "list_resources", "log_ingestion"],
        )


class Settings(unittest.TestCase):
    def test_bad_settings_are_refused(self):
        base = {"AZURE_TENANT_ID": TENANT, "AZURE_SUBSCRIPTION_ID": SUBSCRIPTION}
        for bad in ({"OPSAGENT_DAYS": "0"}, {"OPSAGENT_DAYS": "x"}, {"AZURE_TENANT_ID": "t"}, {"OPSAGENT_PREFIX": "LAB!"}, {"GITHUB_RUN_ID": "1;x"}):
            with self.subTest(bad=bad), self.assertRaises(ConfigError):
                Config.from_env({**base, **bad})

    def test_the_ai_services_group_is_not_readable(self):
        cfg = Config.from_env({"AZURE_TENANT_ID": TENANT, "AZURE_SUBSCRIPTION_ID": SUBSCRIPTION})
        self.assertNotIn("aiservices", " ".join(cfg.resource_groups.values()))


if __name__ == "__main__":
    unittest.main()
