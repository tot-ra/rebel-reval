from __future__ import annotations

import json
import struct
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]

MODELS = {
    "assets/animals/hendrik_reyneke/chicken.glb": 0.46,
    "assets/birds/mallard/standing.glb": 0.56,
    "assets/animals/hendrik_reyneke/goat.glb": 1.20,
    "assets/birds/house_sparrow/perched.glb": 0.16,
}


def _glb_document(relative_path: str) -> dict:
    payload = (ROOT / relative_path).read_bytes()
    assert payload[:4] == b"glTF"
    json_length = struct.unpack_from("<I", payload, 12)[0]
    return json.loads(payload[20 : 20 + json_length])


@pytest.mark.parametrize(("relative_path", "expected_largest_axis"), MODELS.items())
def test_hendrik_model_vertices_are_metric_without_residual_node_scale(
    relative_path: str,
    expected_largest_axis: float,
) -> None:
    document = _glb_document(relative_path)

    mesh_nodes = [node for node in document.get("nodes", []) if "mesh" in node]
    assert mesh_nodes
    for node in mesh_nodes:
        assert node.get("scale", [1.0, 1.0, 1.0]) == pytest.approx([1.0, 1.0, 1.0])
        assert node.get("translation", [0.0, 0.0, 0.0]) == pytest.approx([0.0, 0.0, 0.0])

    largest_axis = max(
        max(float(high) - float(low) for low, high in zip(accessor["min"], accessor["max"]))
        for accessor in document.get("accessors", [])
        if accessor.get("type") == "VEC3" and "min" in accessor and "max" in accessor
    )
    assert largest_axis == pytest.approx(expected_largest_axis, abs=1e-4)
