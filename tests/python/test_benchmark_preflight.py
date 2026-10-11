"""R-1536: benchmark entry points resolve, and the wrappers fail fast instead of hanging."""

from __future__ import annotations

import re
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "benchmarks"))

import benchmark_preflight  # noqa: E402

GUARD = ROOT / "tools" / "benchmarks" / "benchmark_guard.sh"
# Every Godot entry point the performance wrappers launch.
ENTRY_POINTS = [
    "res://tools/benchmarks/scene_benchmark.tscn",
    "res://tools/benchmarks/large_map_benchmark.tscn",
    "res://tools/benchmarks/render_probe.tscn",
    "res://tools/benchmarks/renderer_comparison_benchmark.tscn",
    "res://tools/benchmarks/async_assembly_trace.gd",
    "res://tools/benchmarks/renderer_frame_time.gd",
    "res://tools/benchmarks/benchmark_target.gd",
    "res://tools/capture_vegetation_benchmark.gd",
]


class MissingDependenciesTest(unittest.TestCase):
    def _tree(self, files: dict[str, str]) -> Path:
        root = Path(tempfile.mkdtemp())
        for relative, text in files.items():
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
        return root

    def test_reports_transitive_missing_scene_and_preload(self) -> None:
        root = self._tree(
            {
                "bench.tscn": '[ext_resource type="PackedScene" path="res://world.tscn" id="1"]\n'
                '[ext_resource type="Script" path="res://rec.gd" id="2"]\n',
                "rec.gd": 'const A := preload("res://gone/definition.gd")\n',
            }
        )
        missing = benchmark_preflight.missing_dependencies(["res://bench.tscn"], root)
        self.assertEqual(
            missing,
            [
                "res://gone/definition.gd (needed by res://rec.gd)",
                "res://world.tscn (needed by res://bench.tscn)",
            ],
        )

    def test_clean_tree_and_cycles_pass(self) -> None:
        root = self._tree(
            {
                "a.gd": 'const B := preload("res://b.gd")\n',
                "b.gd": 'const A := preload("res://a.gd")\n',
            }
        )
        self.assertEqual(benchmark_preflight.missing_dependencies(["res://a.gd"], root), [])

    def test_missing_entry_point(self) -> None:
        root = self._tree({})
        self.assertEqual(
            benchmark_preflight.missing_dependencies(["res://nope.tscn"], root),
            ["res://nope.tscn (needed by command line)"],
        )


class EntryPointsResolveTest(unittest.TestCase):
    def test_benchmark_entry_points_resolve(self) -> None:
        self.assertEqual(benchmark_preflight.missing_dependencies(ENTRY_POINTS), [])

    def test_measured_scenes_exist(self) -> None:
        script = (ROOT / "tools" / "benchmarks" / "run_large_map_benchmark.sh").read_text()
        scenes = re.findall(r'"[a-z_]+=(res://[^"]+\.tscn)"', script)
        self.assertGreaterEqual(len(scenes), 2, "run_large_map_benchmark.sh SCENES list changed shape")
        self.assertEqual(benchmark_preflight.missing_dependencies(scenes), [])

    def test_no_benchmark_scene_instances_a_measured_scene(self) -> None:
        # Measured scenes are mounted at run time (benchmark_target.gd) so a retired
        # scene fails with exit 1 instead of leaving an empty scene idling forever.
        for scene in (ROOT / "tools" / "benchmarks").glob("*.tscn"):
            text = scene.read_text(encoding="utf-8")
            self.assertNotIn('type="PackedScene"', text, scene.name)


class BenchmarkRunTest(unittest.TestCase):
    def _run(self, command: str, timeout: str) -> tuple[int, float]:
        started = time.monotonic()
        result = subprocess.run(
            ["bash", "-c", f'ROOT="{ROOT}"; source "{GUARD}"; {command}'],
            env={"BENCHMARK_TIMEOUT_SEC": timeout, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"},
            capture_output=True,
            text=True,
            check=False,
        )
        return result.returncode, time.monotonic() - started

    def test_hanging_phase_is_killed_with_124(self) -> None:
        code, elapsed = self._run("benchmark_run sleep 60", "2")
        self.assertEqual(code, 124)
        self.assertLess(elapsed, 20)

    def test_child_of_wrapper_is_killed(self) -> None:
        # godot_render.sh runs Godot as a child; the guard must not orphan it.
        marker = f"r1536-guard-{time.time_ns()}"
        code, _ = self._run(f"benchmark_run bash -c 'sleep 61 # {marker}\nwait'", "2")
        self.assertEqual(code, 124)
        time.sleep(0.5)
        alive = subprocess.run(["pgrep", "-f", marker], capture_output=True, check=False)
        self.assertNotEqual(alive.returncode, 0, "child process survived the timeout")

    def test_exit_code_passes_through(self) -> None:
        self.assertEqual(self._run("benchmark_run bash -c 'exit 3'", "30")[0], 3)
        self.assertEqual(self._run("benchmark_run true", "30")[0], 0)

    def test_preflight_rejects_missing_scene(self) -> None:
        code, _ = self._run("benchmark_preflight res://scenes/reval_east/reval_east.tscn", "30")
        self.assertEqual(code, 1)


if __name__ == "__main__":
    unittest.main()
