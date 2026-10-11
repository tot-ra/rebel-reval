"""Deterministic R-653 audit for minimum-hardware GPU benchmark evidence.

The benchmark report intentionally carries both the declared target and the host
that Godot actually detected. This audit keeps those identities separate and
rejects a successful-looking Apple/headless report as Intel UHD 620 evidence.
"""

from __future__ import annotations

import json
import unittest
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
TARGET_PROFILE = ROOT / "tools/benchmarks/minimum-hardware.json"
EXPECTED_CPU = "Intel Core i5-8250U"
EXPECTED_GPU = "Intel UHD Graphics 620"
EXPECTED_RENDERER = "gl_compatibility"
EXPECTED_RESOLUTION = "1920x1080"
EXPECTED_FRAME_SAMPLES = 120
DISTRIBUTION_FIELDS = ("median", "p95", "p99", "max")


@dataclass
class AuditResult:
    """Errors block target acceptance; limitations describe explicit gaps."""

    errors: list[str] = field(default_factory=list)
    limitations: list[str] = field(default_factory=list)

    @property
    def valid(self) -> bool:
        return not self.errors


def _as_dict(value: Any, field_name: str, result: AuditResult) -> dict[str, Any]:
    if not isinstance(value, dict):
        result.errors.append(f"{field_name} must be an object")
        return {}
    return value


def _text(value: Any) -> str:
    return str(value) if value is not None else ""


def _has_cpu_identity(value: Any) -> bool:
    text = _text(value).casefold()
    return "intel" in text and "i5-8250u" in text


def _has_gpu_identity(value: Any) -> bool:
    text = _text(value).casefold()
    return "intel" in text and "uhd graphics 620" in text


def _require_number(
    section: dict[str, Any],
    key: str,
    result: AuditResult,
    label: str | None = None,
) -> None:
    value = section.get(key)
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        result.errors.append(f"{label or key} must be a numeric value")


def _frame_distribution(payload: dict[str, Any], result: AuditResult) -> dict[str, Any]:
    distribution = payload.get("frame_time_ms")
    if distribution is None:
        distribution = payload.get("performance", {}).get("frame_time_ms")
    if not isinstance(distribution, dict):
        result.errors.append("missing frame-time distribution: frame_time_ms")
        return {}
    return distribution


def _audit_gpu_memory(payload: dict[str, Any], result: AuditResult) -> None:
    memory = payload.get("gpu_memory")
    if memory is None:
        # Accept the flat shape emitted by the renderer probe while retaining a
        # single error vocabulary for reports that use the grouped shape.
        memory = {
            "texture_memory_bytes": payload.get("texture_memory_bytes"),
            "render_video_memory_bytes": payload.get("render_video_memory_bytes"),
            "instrumentation_available": payload.get("gpu_memory_instrumented"),
            "limitation": payload.get("gpu_memory_instrumentation_limitation"),
        }
    if not isinstance(memory, dict):
        result.errors.append("gpu_memory must be an object")
        return

    available = memory.get("instrumentation_available")
    limitation = memory.get("limitation") or memory.get("instrumentation_limitation")
    texture = memory.get("texture_memory_bytes")
    video = memory.get("render_video_memory_bytes")
    metrics_present = texture is not None or video is not None

    if available is False:
        if not _text(limitation).strip():
            result.errors.append(
                "gpu_memory instrumentation limitation must be labeled when unavailable"
            )
        else:
            result.limitations.append(f"GPU memory instrumentation unavailable: {limitation}")
        return

    if not metrics_present:
        result.errors.append(
            "missing GPU memory metrics or explicit instrumentation limitation: gpu_memory"
        )
        return

    for field_name, value in (
        ("gpu_memory.texture_memory_bytes", texture),
        ("gpu_memory.render_video_memory_bytes", video),
    ):
        if not isinstance(value, (int, float)) or isinstance(value, bool):
            result.errors.append(f"{field_name} must be a numeric value")
        elif value <= 0:
            if _text(limitation).strip():
                result.limitations.append(f"{field_name} unavailable: {limitation}")
            else:
                result.errors.append(
                    f"{field_name} must be > 0 when instrumentation is available (got {value})"
                )


def audit_report(payload: dict[str, Any]) -> AuditResult:
    """Validate the R-653 target identity and minimum evidence contract."""

    result = AuditResult()
    if not isinstance(payload, dict):
        result.errors.append("benchmark report must be a JSON object")
        return result

    target = _as_dict(payload.get("target_hardware"), "target_hardware", result)
    host = _as_dict(payload.get("measurement_host"), "measurement_host", result)

    if target.get("architecture") != "x86_64":
        result.errors.append(
            "target_hardware.architecture must be x86_64 "
            f"(got {target.get('architecture')!r})"
        )
    if not _has_cpu_identity(target.get("cpu")):
        result.errors.append(
            "target_hardware.cpu must identify Intel Core i5-8250U "
            f"(got {target.get('cpu')!r})"
        )
    if not _has_gpu_identity(target.get("gpu")):
        result.errors.append(
            "target_hardware.gpu must identify Intel UHD Graphics 620 "
            f"(got {target.get('gpu')!r})"
        )
    if target.get("display") != EXPECTED_RESOLUTION:
        result.errors.append(
            "target_hardware.display must be 1920x1080 "
            f"(got {target.get('display')!r})"
        )

    if host.get("architecture") != "x86_64":
        result.errors.append(
            "measurement_host.architecture must be x86_64 "
            f"(got {host.get('architecture')!r})"
        )
    if not _has_cpu_identity(host.get("processor_name")):
        result.errors.append(
            "measurement_host.processor_name must identify Intel Core i5-8250U "
            f"(got {host.get('processor_name')!r})"
        )
    if not _has_gpu_identity(host.get("video_adapter")):
        result.errors.append(
            "measurement_host.video_adapter must identify Intel UHD Graphics 620 "
            f"(got {host.get('video_adapter')!r})"
        )
    if host.get("headless") is not False:
        result.errors.append(
            "measurement_host.headless must be false for minimum-hardware evidence "
            f"(got {host.get('headless')!r})"
        )

    requested_renderer = payload.get("requested_renderer")
    if requested_renderer is None:
        requested_renderer = payload.get("capture", {}).get("requested_renderer")
    if requested_renderer is None:
        result.errors.append("missing requested renderer: requested_renderer")
    elif requested_renderer != EXPECTED_RENDERER:
        result.errors.append(
            "requested_renderer must be gl_compatibility "
            f"(got {requested_renderer!r})"
        )

    resolution = payload.get("resolution")
    if resolution is None:
        resolution = payload.get("capture", {}).get("resolution")
    if resolution != EXPECTED_RESOLUTION:
        result.errors.append(
            "resolution must be 1920x1080 "
            f"(got {resolution!r})"
        )

    methodology = _as_dict(payload.get("methodology"), "methodology", result)
    if methodology.get("frame_samples") != EXPECTED_FRAME_SAMPLES:
        result.errors.append(
            "methodology.frame_samples must be 120 "
            f"(got {methodology.get('frame_samples')!r})"
        )

    distribution = _frame_distribution(payload, result)
    if distribution:
        if distribution.get("samples") != EXPECTED_FRAME_SAMPLES:
            result.errors.append(
                "frame_time_ms.samples must be 120 "
                f"(got {distribution.get('samples')!r})"
            )
        for field_name in DISTRIBUTION_FIELDS:
            if field_name not in distribution:
                result.errors.append(f"frame_time_ms missing distribution field: {field_name}")
            else:
                _require_number(
                    distribution,
                    field_name,
                    result,
                    f"frame_time_ms.{field_name}",
                )

    _audit_gpu_memory(payload, result)
    return result


def _valid_report() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "target_hardware": {
            "profile_id": "minimum-hardware-intel-uhd-620",
            "architecture": "x86_64",
            "cpu": "Intel Core i5-8250U, 4 cores / 8 threads",
            "gpu": "Intel UHD Graphics 620 (24 EUs)",
            "memory_gib": 8,
            "display": "1920x1080",
        },
        "measurement_host": {
            "architecture": "x86_64",
            "processor_name": "Intel(R) Core(TM) i5-8250U CPU @ 1.60GHz",
            "video_adapter": "Intel UHD Graphics 620",
            "headless": False,
        },
        "requested_renderer": "gl_compatibility",
        "resolution": "1920x1080",
        "methodology": {"frame_samples": 120},
        "frame_time_ms": {
            "samples": 120,
            "median": 12.5,
            "p95": 16.2,
            "p99": 19.8,
            "max": 24.1,
        },
        "gpu_memory": {
            "instrumentation_available": True,
            "texture_memory_bytes": 128 * 1024 * 1024,
            "render_video_memory_bytes": 192 * 1024 * 1024,
        },
    }


class R653MinimumHardwareEvidenceTests(unittest.TestCase):
    def test_valid_intel_non_headless_report_passes(self) -> None:
        result = audit_report(_valid_report())

        self.assertTrue(result.valid, result.errors)
        self.assertEqual(result.limitations, [])

    def test_apple_headless_report_fails_with_identity_reasons(self) -> None:
        report = _valid_report()
        report["target_hardware"].update(
            {
                "architecture": "arm64",
                "cpu": "Apple M5 Pro",
                "gpu": "Apple M5 Pro",
                "display": "3456x2234",
            }
        )
        report["measurement_host"].update(
            {
                "architecture": "arm64",
                "processor_name": "Apple M5 Pro",
                "video_adapter": "Apple M5 Pro",
                "headless": True,
            }
        )

        errors = audit_report(report).errors

        self.assertTrue(any("target_hardware.architecture" in error for error in errors))
        self.assertTrue(any("measurement_host.video_adapter" in error for error in errors))
        self.assertTrue(any("measurement_host.headless" in error for error in errors))

    def test_missing_distribution_field_identifies_exact_field(self) -> None:
        report = _valid_report()
        del report["frame_time_ms"]["p99"]

        errors = audit_report(report).errors

        self.assertIn("frame_time_ms missing distribution field: p99", errors)

    def test_zero_gpu_metric_without_limitation_is_not_accepted(self) -> None:
        report = _valid_report()
        report["gpu_memory"]["texture_memory_bytes"] = 0

        errors = audit_report(report).errors

        self.assertIn(
            "gpu_memory.texture_memory_bytes must be > 0 when instrumentation is available (got 0)",
            errors,
        )

    def test_explicit_gpu_instrumentation_limitation_is_preserved(self) -> None:
        report = _valid_report()
        report["gpu_memory"] = {
            "instrumentation_available": False,
            "limitation": "driver does not expose GPU memory counters",
        }

        result = audit_report(report)

        self.assertTrue(result.valid, result.errors)
        self.assertIn(
            "GPU memory instrumentation unavailable: driver does not expose GPU memory counters",
            result.limitations,
        )

    def test_current_minimum_profile_matches_audited_target_identity(self) -> None:
        profile = json.loads(TARGET_PROFILE.read_text(encoding="utf-8"))

        self.assertEqual(profile["architecture"], "x86_64")
        self.assertIn(EXPECTED_CPU, profile["cpu"])
        self.assertIn(EXPECTED_GPU, profile["gpu"])
        self.assertEqual(profile["display"], EXPECTED_RESOLUTION)


if __name__ == "__main__":
    unittest.main()
