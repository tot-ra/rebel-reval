#!/usr/bin/env python3
"""Measure a local LLM as the NPC "mind" layer (ADR 0036, proposed).

Talks to any OpenAI-compatible streaming endpoint, for example a local
`llama-server` (llama.cpp) started with a pinned GGUF file:

    llama-server -m model.gguf --port 8080 -c 2048 -ngl 99
    python3 tools/benchmarks/llm_npc_latency.py --url http://127.0.0.1:8080 \
        --runs 30 --out build/benchmarks/llm_npc_latency.json

For each run it sends a small fixed prompt (character card + state summary),
asks for a closed-vocabulary JSON reply, and records time to first token, total
latency, chunks per second, whether the reply parses and passes the validator
(enum membership, length, anachronism list), and whether it beat the deadline.
Use --mock to exercise the harness without a model (no model numbers result).

Only the standard library is used. Results are host and model specific; record
the model file SHA-256 and the machine with every run.
"""

from __future__ import annotations

import argparse
import json
import statistics
import sys
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Any

GOALS = [
    "stay",
    "work",
    "eat",
    "pray",
    "trade",
    "gossip",
    "fetch_water",
    "go_home",
    "flee",
    "watch",
    "greet_player",
    "avoid_player",
]
MOODS = ["calm", "wary", "afraid", "cheerful", "angry", "weary"]
INTENTS = ["greet", "warn", "gossip", "refuse", "trade_offer", "farewell"]
MAX_LINE = 160
ANACHRONISMS = ["okay", "phone", "internet", "police", "hello there", "dude", "guys"]

SCHEMA = {
    "type": "object",
    "properties": {
        "goal": {"enum": GOALS},
        "mood": {"enum": MOODS},
        "intent": {"enum": INTENTS},
        "line": {"type": "string", "maxLength": MAX_LINE},
    },
    "required": ["goal", "mood", "intent", "line"],
    "additionalProperties": False,
}

SYSTEM = (
    "You voice one townsperson of Reval in April 1343. Reply only with JSON that "
    "matches the schema. Speak plainly, in period-neutral English, one or two short "
    "sentences. Never mention anything after 1343."
)

SCENARIOS = [
    "Anneke, baker's wife, age 34, practical and talkative. It is morning; the oven "
    "is hot; hunger low, fear low. The player, a smith's apprentice, greets her.",
    "Hinrik, night watchman, age 51, gruff. It is dusk; curfew soon; fear medium. "
    "The player walks past the gate carrying a hammer.",
    "Mari, fishwife, age 28, sharp-tongued. Midday at the landing; a storm is "
    "coming; fear medium. The player asks about the weather.",
    "Brother Tobias, age 60, gentle. Vespers is near; the market is quiet; fear "
    "low. The player stops near the church door.",
]


def percentile(values: list[float], p: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    index = min(len(ordered) - 1, int(p * len(ordered)))
    return ordered[index]


def validate_reply(text: str) -> tuple[bool, str]:
    """Return (ok, reason). The runtime validator will be stricter than this."""
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return False, "not_json"
    if not isinstance(data, dict) or set(data) != set(SCHEMA["required"]):
        return False, "wrong_keys"
    if data["goal"] not in GOALS:
        return False, "goal_not_in_vocabulary"
    if data["mood"] not in MOODS:
        return False, "mood_not_in_vocabulary"
    if data["intent"] not in INTENTS:
        return False, "intent_not_in_vocabulary"
    line = data["line"]
    if not isinstance(line, str) or not line.strip():
        return False, "empty_line"
    if len(line) > MAX_LINE:
        return False, "line_too_long"
    lowered = line.lower()
    for word in ANACHRONISMS:
        if word in lowered:
            return False, "anachronism"
    return True, "ok"


def one_request(url: str, scenario: str, max_tokens: int, timeout: float) -> dict[str, Any]:
    body = {
        "messages": [
            {"role": "system", "content": SYSTEM},
            {"role": "user", "content": scenario},
        ],
        "max_tokens": max_tokens,
        "temperature": 0.7,
        "stream": True,
        "response_format": {
            "type": "json_schema",
            "json_schema": {"name": "npc_mind", "schema": SCHEMA, "strict": True},
        },
    }
    request = urllib.request.Request(
        url.rstrip("/") + "/v1/chat/completions",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
    )
    started = time.perf_counter()
    first = None
    chunks = 0
    parts: list[str] = []
    with urllib.request.urlopen(request, timeout=timeout) as response:
        for raw in response:
            line = raw.decode("utf-8", "replace").strip()
            if not line.startswith("data:"):
                continue
            payload = line[5:].strip()
            if payload == "[DONE]":
                break
            try:
                event = json.loads(payload)
            except json.JSONDecodeError:
                continue
            delta = event.get("choices", [{}])[0].get("delta", {}).get("content")
            if delta:
                if first is None:
                    first = time.perf_counter()
                chunks += 1
                parts.append(delta)
    done = time.perf_counter()
    ok, reason = validate_reply("".join(parts))
    return {
        "ttft_s": (first - started) if first else None,
        "total_s": done - started,
        "chunks": chunks,
        "valid": ok,
        "reason": reason,
    }


def run(url: str, runs: int, max_tokens: int, timeout: float, deadline: float) -> dict[str, Any]:
    results = []
    for i in range(runs):
        scenario = SCENARIOS[i % len(SCENARIOS)]
        try:
            results.append(one_request(url, scenario, max_tokens, timeout))
        except Exception as error:  # noqa: BLE001 - report every transport failure
            results.append(
                {"ttft_s": None, "total_s": timeout, "chunks": 0, "valid": False,
                 "reason": f"error:{type(error).__name__}"}
            )
    totals = [r["total_s"] for r in results]
    ttfts = [r["ttft_s"] for r in results if r["ttft_s"] is not None]
    rates = [r["chunks"] / r["total_s"] for r in results if r["chunks"] and r["total_s"] > 0]
    reasons: dict[str, int] = {}
    for r in results:
        reasons[r["reason"]] = reasons.get(r["reason"], 0) + 1
    return {
        "runs": runs,
        "deadline_s": deadline,
        "ttft_p50_s": round(percentile(ttfts, 0.5), 3),
        "ttft_p95_s": round(percentile(ttfts, 0.95), 3),
        "total_p50_s": round(percentile(totals, 0.5), 3),
        "total_p95_s": round(percentile(totals, 0.95), 3),
        "chunks_per_s_median": round(statistics.median(rates), 1) if rates else 0.0,
        "valid_rate": round(sum(1 for r in results if r["valid"]) / max(1, runs), 3),
        "within_deadline_rate": round(sum(1 for t in totals if t <= deadline) / max(1, runs), 3),
        "failure_reasons": reasons,
    }


class _MockHandler(BaseHTTPRequestHandler):
    """Serves a canned, valid streaming reply so the harness can be tested."""

    reply = json.dumps(
        {"goal": "greet_player", "mood": "calm", "intent": "greet",
         "line": "Good morrow, smith's boy. The bread is warm if you have a penny."}
    )

    def do_POST(self) -> None:  # noqa: N802 - http.server API
        length = int(self.headers.get("Content-Length", "0"))
        self.rfile.read(length)
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        for i in range(0, len(self.reply), 8):
            event = {"choices": [{"delta": {"content": self.reply[i : i + 8]}}]}
            self.wfile.write(f"data: {json.dumps(event)}\n\n".encode())
            self.wfile.flush()
        self.wfile.write(b"data: [DONE]\n\n")

    def log_message(self, *_args: Any) -> None:
        return


def start_mock() -> tuple[HTTPServer, str]:
    server = HTTPServer(("127.0.0.1", 0), _MockHandler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server, f"http://127.0.0.1:{server.server_address[1]}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--url", default="http://127.0.0.1:8080")
    parser.add_argument("--runs", type=int, default=30)
    parser.add_argument("--max-tokens", type=int, default=96)
    parser.add_argument("--timeout", type=float, default=20.0)
    parser.add_argument("--deadline", type=float, default=2.5, help="seconds to a full reply")
    parser.add_argument("--out", default="")
    parser.add_argument("--mock", action="store_true", help="use a built-in fake server")
    args = parser.parse_args()
    server = None
    url = args.url
    if args.mock:
        server, url = start_mock()
    report = run(url, args.runs, args.max_tokens, args.timeout, args.deadline)
    report["mock"] = args.mock
    text = json.dumps(report, indent=2)
    print(text)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as handle:
            handle.write(text)
    if server:
        server.shutdown()
    return 0


if __name__ == "__main__":
    sys.exit(main())
