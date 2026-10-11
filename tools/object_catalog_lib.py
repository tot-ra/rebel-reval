"""Shared helpers for the physical-object catalog (content/objects/).

See docs/SYSTEMS/OBJECT_CATALOG.md. Everything here is pure Python so the
validator, the preview renderer and the agent CLI share one definition of the
handling classes and the derived lifecycle.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CATALOG_DIR = ROOT / "content" / "objects"
COVERAGE_PATH = ROOT / "docs" / "data" / "object_catalog_coverage.json"
SCHEMA_PATH = ROOT / "schemas" / "world_object.schema.json"

# handling -> (min_mass_kg exclusive, max_mass_kg inclusive); fixed has no bound.
MASS_BOUNDS: dict[str, tuple[float, float]] = {
    "pocketable": (0.0, 1.0),
    "carry_one_hand": (0.0, 8.0),
    "carry_two_hands": (1.0, 25.0),
    "heavy": (8.0, float("inf")),
}

TAKEABLE = {"pocketable", "carry_one_hand", "carry_two_hands"}
BAGGABLE = {"pocketable", "carry_one_hand"}


def res_to_path(res_path: str) -> Path:
    if not res_path.startswith("res://"):
        raise ValueError(f"not a res:// path: {res_path}")
    return ROOT / res_path[len("res://") :]


def path_to_res(path: Path) -> str:
    return "res://" + path.resolve().relative_to(ROOT).as_posix()


def catalog_files() -> list[Path]:
    return sorted(
        (p for p in CATALOG_DIR.rglob("obj.*.json")), key=lambda p: p.name.casefold()
    )


def load_json(path: Path) -> Any:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def load_catalog() -> list[dict[str, Any]]:
    return [load_json(path) for path in catalog_files()]


def dump_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def expected_lifecycle(entry: dict[str, Any]) -> str:
    """planned (no model) < usable (model) < complete (model + icon file)."""
    if entry["model"]["status"] == "missing":
        return "planned"
    icon = entry["visual"]["icon"]
    if entry["visual"]["icon_status"] != "missing" and res_to_path(icon).is_file():
        return "complete"
    return "usable"


def entry_path(entry: dict[str, Any]) -> Path:
    return CATALOG_DIR / entry["category"] / f"{entry['id']}.json"


def style_suffix() -> str:
    return (
        "grounded stylized realism, single object centred on a plain neutral "
        "background, soft three-quarter studio light, readable silhouette, "
        "weathered hand-made late-medieval Baltic (Reval, 1343) materials, "
        "no text, no hands, no modern elements"
    )
