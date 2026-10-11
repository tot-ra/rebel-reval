#!/usr/bin/env python3
"""Generate and verify the P0-142 renderer evaluation report.

Reads evidence from build/benchmarks/renderer_evaluation_evidence.json (produced by
tools/benchmarks/run_renderer_comparison.sh) and writes docs/reports/renderer_evaluation.md.

Usage:
    tools/benchmarks/run_renderer_comparison.sh build/benchmarks --quick
    python3 tools/generate_renderer_evaluation_report.py --write
    python3 tools/generate_renderer_evaluation_report.py --check
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "build" / "benchmarks" / "renderer_evaluation_evidence.json"
REPORT = ROOT / "docs" / "reports" / "renderer_evaluation.md"
CAPTURE_DIR = ROOT / "docs" / "reports" / "images" / "renderer_evaluation"
REQUIRED_RENDERERS = ("gl_compatibility", "mobile", "forward_plus")


def _read_json(path: Path) -> dict[str, Any]:
    parsed = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(parsed, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return parsed


def _fmt_ms(bucket: dict[str, Any]) -> str:
    if not bucket:
        return "n/a"
    return f"{float(bucket.get('median', 0.0)):.3f} ms median, p95 {float(bucket.get('p95', 0.0)):.3f} ms"


def _fmt_mib(bytes_value: int) -> str:
    return f"{float(bytes_value) / (1024.0 * 1024.0):.2f} MiB"


def _build_markdown(evidence: dict[str, Any]) -> str:
    recorded = evidence.get("recorded_utc", "unknown")
    git_commit = evidence.get("git_commit", "unknown")
    target = evidence.get("target_hardware", {})
    host = evidence.get("measurement_host", {})
    renderers = evidence.get("renderers", [])
    export_support = evidence.get("export_support", {})
    recommendation = evidence.get("recommendation", {})

    lines = [
        "# P0-142 renderer evaluation report",
        "",
        f"Recorded: {recorded}",
        "Task: `P0-142`",
        f"Git commit: `{git_commit}`",
        "",
        "## Verdict",
        "",
        f"**Recommendation: stay on `{recommendation.get('stay_on', 'gl_compatibility')}`.**",
        recommendation.get("rationale", "See recommendation section below."),
        "",
        "This spike compares Godot 4.7 rendering methods on the playable Lower Town slice.",
        "It does not switch the shipped renderer or export preset.",
        "",
        "## Repeatable procedure",
        "",
        "Run from the repository root:",
        "",
        "```bash",
        "tools/benchmarks/run_renderer_comparison.sh build/benchmarks --quick",
        "python3 tools/generate_renderer_evaluation_report.py --write",
        "python3 tools/generate_renderer_evaluation_report.py --check",
        "```",
        "",
        "Full sample count (120 frames per renderer):",
        "",
        "```bash",
        "tools/benchmarks/run_renderer_comparison.sh build/benchmarks",
        "```",
        "",
        "Non-headless GPU capture (optional, for texture memory truth):",
        "",
        "```bash",
        "BENCHMARK_HEADLESS=0 tools/benchmarks/run_renderer_comparison.sh build/benchmarks --quick",
        "```",
        "",
        "## Hardware",
        "",
        "| Field | Declared target | Measurement host |",
        "|---|---|---|",
        f"| Profile | `{target.get('profile_id', 'unknown')}` | detected at runtime |",
        f"| Status | `{target.get('status', 'unknown')}` | headless spike |",
        f"| Platform | {target.get('platform', 'unknown')} | {host.get('display_driver', 'unknown')} |",
        f"| CPU | {target.get('cpu', 'unknown')} | n/a |",
        f"| GPU | {target.get('gpu', 'unknown')} | n/a |",
        f"| Memory | {target.get('memory_gib', 'n/a')} GiB declared | n/a |",
        f"| Headless | n/a | `{host.get('headless', True)}` |",
        "",
        "## Per-renderer measurements",
        "",
        "| Renderer | Frame time | Static memory | Texture memory | Startup |",
        "|---|---|---|---|---|",
    ]

    for entry in renderers:
        if not isinstance(entry, dict):
            continue
        method = entry.get("rendering_method", "unknown")
        frame = entry.get("frame_time_ms", {})
        lines.append(
            f"| `{method}` | {_fmt_ms(frame)} | "
            f"{_fmt_mib(int(entry.get('memory_static_bytes', 0)))} | "
            f"{_fmt_mib(int(entry.get('texture_memory_bytes', 0)))} | "
            f"{float(entry.get('scene_startup_ms', 0.0)):.1f} ms |"
        )

    lines.extend(
        [
            "",
            "## Fidelity feature probe",
            "",
            "| Renderer | Glow | Tonemap | Fog | Dir. shadow | SSAO path | SSIL | SDFGI |",
            "|---|:---:|:---:|:---:|:---:|---|:---:|:---:|",
        ]
    )

    for entry in renderers:
        if not isinstance(entry, dict):
            continue
        fidelity = entry.get("fidelity_features", {})
        method = entry.get("rendering_method", "unknown")
        lines.append(
            f"| `{method}` | "
            f"{'yes' if fidelity.get('glow_enabled') else 'no'} | "
            f"{fidelity.get('tonemap_mode', -1)} | "
            f"{'yes' if fidelity.get('fog_enabled') else 'no'} | "
            f"{'yes' if fidelity.get('directional_shadow_enabled') else 'no'} | "
            f"{'yes' if fidelity.get('ssao_supported') else 'no'} | "
            f"{'yes' if fidelity.get('ssil_supported') else 'no'} | "
            f"{'yes' if fidelity.get('sdfgi_supported') else 'no'} |"
        )

    lines.extend(["", "## Side-by-side captures", ""])
    for method in REQUIRED_RENDERERS:
        lines.append(
            f"- `{method}`: `docs/reports/images/renderer_evaluation/{method}_lower_town_day.png`"
        )

    lines.extend(["", "## Export compatibility", "", "| Target | Renderer | Status | Note |", "|---|---|---|---|"])
    for key, row in sorted(export_support.items()):
        if not isinstance(row, dict):
            continue
        lines.append(
            f"| {key} | `{row.get('renderer', '')}` | "
            f"{row.get('status', '')} | {row.get('note', '')} |"
        )

    follow_up = recommendation.get("follow_up_task", "P0-157")
    lines.extend(
        [
            "",
            "## Recommendation",
            "",
            f"- **Stay on:** `{recommendation.get('stay_on', 'gl_compatibility')}`",
            f"- **Follow-up:** `{follow_up}` (decal path depends on renderer spike outcome)",
            f"- **Rationale:** {recommendation.get('rationale', '')}",
            "",
        ]
    )
    return "\n".join(lines)


def verify(evidence_path: Path, report_path: Path) -> list[str]:
    errors: list[str] = []
    if not evidence_path.is_file():
        errors.append(f"missing evidence: {evidence_path}")
        return errors

    evidence = _read_json(evidence_path)
    if evidence.get("task_id") != "P0-142":
        errors.append("evidence task_id must be P0-142")

    renderers = evidence.get("renderers", [])
    methods = {
        entry.get("rendering_method")
        for entry in renderers
        if isinstance(entry, dict)
    }
    for required in REQUIRED_RENDERERS:
        if required not in methods:
            errors.append(f"missing renderer measurement: {required}")

    if not report_path.is_file():
        errors.append(f"missing report: {report_path}")
    else:
        expected = _build_markdown(evidence)
        actual = report_path.read_text(encoding="utf-8")
        if actual != expected:
            errors.append("report markdown is stale; run --write")

    for method in REQUIRED_RENDERERS:
        capture = CAPTURE_DIR / f"{method}_lower_town_day.png"
        if not capture.is_file():
            errors.append(f"missing capture: {capture}")

    recommendation = evidence.get("recommendation", {})
    if not recommendation.get("stay_on"):
        errors.append("recommendation.stay_on is required")
    if not recommendation.get("follow_up_task"):
        errors.append("recommendation.follow_up_task is required")

    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, default=EVIDENCE)
    parser.add_argument("--report", type=Path, default=REPORT)
    parser.add_argument("--write", action="store_true", help="Write markdown report from evidence")
    parser.add_argument("--check", action="store_true", help="Verify evidence, captures, and report")
    args = parser.parse_args(argv)

    if args.write:
        evidence = _read_json(args.evidence)
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(_build_markdown(evidence), encoding="utf-8")
        print(f"Wrote {args.report}")

    if args.check:
        errors = verify(args.evidence, args.report)
        if errors:
            for error in errors:
                print(f"renderer evaluation check failed: {error}")
            return 1
        print("renderer evaluation report check passed")
        return 0

    if not args.write:
        parser.print_help()
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
