"""Seeded filesystem fixtures for the active documentation report CLI."""

from __future__ import annotations

import sys
import tempfile
from collections.abc import Callable
from pathlib import Path

from active_docs_report_common import ReportResult

def write_fixture(root: Path, kind: str) -> None:
    (root / "docs" / "CHARACTERS").mkdir(parents=True, exist_ok=True)
    (root / "docs" / "SCENES").mkdir(parents=True, exist_ok=True)
    (root / "story" / "archive").mkdir(parents=True, exist_ok=True)
    (root / "README.md").write_text(
        "# Fixture Product\n\n"
        "See [Canon](./docs/CANON.md) and [Archive](./story/archive/old.md).\n",
        encoding="utf-8",
    )
    (root / "AGENTS.md").write_text("# AGENTS.md\n\nActive fixture guide.\n", encoding="utf-8")
    (root / "TODO.md").write_text("# TODO\n\n- [ ] FIXTURE\n", encoding="utf-8")
    (root / "story" / "archive" / "old.md").write_text(
        "> **Legacy status:** `archive`\n\n# Old archive\n\n[Broken ignored link](./missing.md)\n",
        encoding="utf-8",
    )

    if kind == "clean":
        canon = """# Canon: Fixture

## Timeline

* **April 23, 1343 (St. George's Night)** - **`attested`** (Source: fixture source)
  * Fixture event.

## Names & Pronunciation

### Main Cast

* **Kalev** (The Smith) - **`invented`**
  * *Notes:* Fixture protagonist.
* **Mart** (The Apprentice) - **`invented`**
  * *Notes:* Fixture apprentice.
"""
        scene = """# Fixture Scene

**Timeline:** April 23, 1343

## Characters

* **Aita:** Mentioned in prose, not a canonical duplicate list entry.
"""
    elif kind == "invalid":
        canon = """# Canon: Fixture

## Timeline

* **April 23, 1343 (St. George's Night)** - **`attested`** (Source needed)
  * Fixture event.
* **May 14, 1343 (St. George's Night)** - **`attested`** (Source: contradictory fixture source)
  * Contradictory fixture event.

## Names & Pronunciation

### Main Cast

* **Kalev** (The Smith) - **`invented`**
  * *Notes:* Fixture protagonist.
* **Kalev** (The Other Smith) - **`invented`**
  * *Notes:* Duplicate fixture protagonist.

[Broken link](./MISSING.md)
"""
        scene = """# Fixture Scene

See [missing anchor](../CANON.md#not-a-real-anchor).
"""
    else:
        raise ValueError(f"unknown fixture kind: {kind}")

    (root / "docs" / "CANON.md").write_text(canon, encoding="utf-8")
    (root / "docs" / "SCENES" / "fixture-scene.md").write_text(scene, encoding="utf-8")


def run_fixture(
    kind: str,
    analyze_func: Callable[[Path], ReportResult] | None = None,
) -> int:
    # Keep fixture generation independent from the CLI module while preserving
    # the historical one-argument helper for callers that import it directly.
    if analyze_func is None:
        from generate_active_docs_report import analyze as analyze_func

    with tempfile.TemporaryDirectory(prefix="active-docs-fixture-") as tmp:
        fixture_root = Path(tmp)
        write_fixture(fixture_root, kind)
        result = analyze_func(fixture_root)
        print(result.rendered)
        if result.issues:
            print(f"fixture `{kind}` failed with {len(result.issues)} issue(s)", file=sys.stderr)
            return 1
        print(f"fixture `{kind}` passed with zero issues")
        return 0
