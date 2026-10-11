"""Tests for the local-LLM NPC latency harness (tools/benchmarks/llm_npc_latency.py)."""

from __future__ import annotations

import importlib.util
import json
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[2] / "tools" / "benchmarks" / "llm_npc_latency.py"
SPEC = importlib.util.spec_from_file_location("llm_npc_latency", MODULE_PATH)
bench = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bench)


def reply(**overrides: object) -> str:
    data = {"goal": "greet_player", "mood": "calm", "intent": "greet", "line": "Good morrow."}
    data.update(overrides)
    return json.dumps(data)


class ValidateReplyTests(unittest.TestCase):
    def test_accepts_a_valid_reply(self) -> None:
        self.assertEqual(bench.validate_reply(reply()), (True, "ok"))

    def test_rejects_text_that_is_not_json(self) -> None:
        self.assertEqual(bench.validate_reply("Good morrow!"), (False, "not_json"))

    def test_rejects_goal_outside_the_vocabulary(self) -> None:
        self.assertEqual(
            bench.validate_reply(reply(goal="burn_the_town")),
            (False, "goal_not_in_vocabulary"),
        )

    def test_rejects_extra_or_missing_keys(self) -> None:
        data = json.loads(reply())
        data["spawn_item"] = "sword"
        self.assertEqual(bench.validate_reply(json.dumps(data)), (False, "wrong_keys"))

    def test_rejects_anachronism_and_overlong_lines(self) -> None:
        self.assertEqual(
            bench.validate_reply(reply(line="Okay, whatever.")), (False, "anachronism")
        )
        self.assertEqual(
            bench.validate_reply(reply(line="a" * (bench.MAX_LINE + 1))),
            (False, "line_too_long"),
        )


class PercentileTests(unittest.TestCase):
    def test_percentile_of_empty_is_zero(self) -> None:
        self.assertEqual(bench.percentile([], 0.95), 0.0)

    def test_percentile_picks_from_sorted_values(self) -> None:
        self.assertEqual(bench.percentile([5.0, 1.0, 3.0, 2.0, 4.0], 0.5), 3.0)


class MockRunTests(unittest.TestCase):
    def test_end_to_end_against_the_mock_server(self) -> None:
        server, url = bench.start_mock()
        try:
            report = bench.run(url, runs=4, max_tokens=64, timeout=5.0, deadline=2.5)
        finally:
            server.shutdown()
        self.assertEqual(report["valid_rate"], 1.0)
        self.assertEqual(report["within_deadline_rate"], 1.0)
        self.assertEqual(report["failure_reasons"], {"ok": 4})

    def test_unreachable_server_is_reported_not_raised(self) -> None:
        report = bench.run("http://127.0.0.1:9", runs=1, max_tokens=8, timeout=1.0, deadline=1.0)
        self.assertEqual(report["valid_rate"], 0.0)
        self.assertTrue(next(iter(report["failure_reasons"])).startswith("error:"))


if __name__ == "__main__":
    unittest.main()
