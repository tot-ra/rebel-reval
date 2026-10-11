"""Minimal GLB reader shared by the object-catalog tools (no third-party deps beyond numpy/Pillow).

Reads node names, per-node world-space bounds, and triangle soups with a flat
material colour so ``validate_object_catalog.py`` can check that a catalog
entry's ``model.node`` really exists and ``render_object_previews.py`` can draw
a preview. Only what the catalog needs is implemented (no skins, sparse
accessors, or Draco).
"""

from __future__ import annotations

import io
import json
import struct
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np

_COMPONENT = {
    5120: np.int8,
    5121: np.uint8,
    5122: np.int16,
    5123: np.uint16,
    5125: np.uint32,
    5126: np.float32,
}
_TYPE_SIZE = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


@dataclass
class Triangles:
    """World-space triangles of one node subtree: (n,3,3) verts and (n,3) rgb."""

    verts: np.ndarray
    colors: np.ndarray

    @property
    def count(self) -> int:
        return int(self.verts.shape[0])

    def bounds(self) -> tuple[np.ndarray, np.ndarray] | None:
        if self.count == 0:
            return None
        flat = self.verts.reshape(-1, 3)
        return flat.min(axis=0), flat.max(axis=0)


@dataclass
class GlbFile:
    path: Path
    gltf: dict
    blob: bytes
    _material_colors: dict[int, np.ndarray] = field(default_factory=dict)

    # -- loading -----------------------------------------------------------------
    @classmethod
    def load(cls, path: Path) -> "GlbFile":
        data = Path(path).read_bytes()
        if data[:4] != b"glTF":
            raise ValueError(f"{path}: not a binary glTF (Git LFS pointer?)")
        gltf: dict = {}
        blob = b""
        offset = 12
        while offset < len(data):
            length, kind = struct.unpack_from("<II", data, offset)
            chunk = data[offset + 8 : offset + 8 + length]
            if kind == 0x4E4F534A:
                gltf = json.loads(chunk)
            elif kind == 0x004E4942:
                blob = chunk
            offset += 8 + length
        return cls(Path(path), gltf, blob)

    # -- node graph --------------------------------------------------------------
    @property
    def nodes(self) -> list[dict]:
        return self.gltf.get("nodes", [])

    def node_names(self) -> set[str]:
        return {n["name"] for n in self.nodes if n.get("name")}

    def find_node(self, name: str) -> int | None:
        for index, node in enumerate(self.nodes):
            if node.get("name") == name:
                return index
        return None

    def root_nodes(self) -> list[int]:
        scene = self.gltf.get("scenes", [{}])[self.gltf.get("scene", 0)]
        return list(scene.get("nodes", []))

    @staticmethod
    def _local_matrix(node: dict) -> np.ndarray:
        if "matrix" in node:
            return np.array(node["matrix"], dtype=np.float64).reshape(4, 4).T
        t = node.get("translation", [0, 0, 0])
        q = node.get("rotation", [0, 0, 0, 1])
        s = node.get("scale", [1, 1, 1])
        x, y, z, w = q
        rot = np.array(
            [
                [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
            ]
        )
        m = np.eye(4)
        m[:3, :3] = rot * np.array(s)
        m[:3, 3] = t
        return m

    def _parents(self) -> dict[int, int]:
        parents: dict[int, int] = {}
        for index, node in enumerate(self.nodes):
            for child in node.get("children", []):
                parents[child] = index
        return parents

    def world_matrix(self, index: int) -> np.ndarray:
        parents = self._parents()
        chain = [index]
        while chain[-1] in parents:
            chain.append(parents[chain[-1]])
        matrix = np.eye(4)
        for node_index in reversed(chain):
            matrix = matrix @ self._local_matrix(self.nodes[node_index])
        return matrix

    # -- accessors / materials -----------------------------------------------------
    def _accessor(self, index: int) -> np.ndarray:
        acc = self.gltf["accessors"][index]
        view = self.gltf["bufferViews"][acc["bufferView"]]
        dtype = np.dtype(_COMPONENT[acc["componentType"]])
        width = _TYPE_SIZE[acc["type"]]
        start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        stride = view.get("byteStride", 0)
        count = acc["count"]
        if stride and stride != dtype.itemsize * width:
            raw = np.frombuffer(self.blob, dtype=np.uint8, count=stride * count, offset=start)
            raw = raw.reshape(count, stride)[:, : dtype.itemsize * width].copy()
            return raw.view(dtype).reshape(count, width)
        arr = np.frombuffer(self.blob, dtype=dtype, count=count * width, offset=start)
        return arr.reshape(count, width)

    def material_color(self, index: int | None) -> np.ndarray:
        if index is None:
            return np.array([0.6, 0.6, 0.6])
        if index in self._material_colors:
            return self._material_colors[index]
        material = self.gltf["materials"][index]
        pbr = material.get("pbrMetallicRoughness", {})
        factor = np.array(pbr.get("baseColorFactor", [1, 1, 1, 1])[:3], dtype=np.float64)
        color = factor
        tex = pbr.get("baseColorTexture")
        if tex is not None:
            try:
                from PIL import Image

                texture = self.gltf["textures"][tex["index"]]
                image = self.gltf["images"][texture["source"]]
                if "bufferView" in image:
                    view = self.gltf["bufferViews"][image["bufferView"]]
                    start = view.get("byteOffset", 0)
                    payload = self.blob[start : start + view["byteLength"]]
                else:
                    payload = (self.path.parent / image["uri"]).read_bytes()
                pixels = np.asarray(Image.open(io.BytesIO(payload)).convert("RGB").resize((8, 8)))
                srgb = pixels.reshape(-1, 3).mean(axis=0) / 255.0
                color = (srgb ** 2.2) * factor  # keep linear like the factor
            except Exception:
                color = factor
        self._material_colors[index] = color
        return color

    # -- geometry ----------------------------------------------------------------------
    def triangles(self, root: int | None = None) -> Triangles:
        """World-space triangles for ``root``'s subtree (or the whole scene)."""
        roots = [root] if root is not None else self.root_nodes()
        verts: list[np.ndarray] = []
        colors: list[np.ndarray] = []
        parents = self._parents()

        def base_matrix(index: int) -> np.ndarray:
            # Matrix of the parent chain above ``index`` so a sub-root keeps its place.
            chain = []
            cursor = index
            while cursor in parents:
                cursor = parents[cursor]
                chain.append(cursor)
            matrix = np.eye(4)
            for node_index in reversed(chain):
                matrix = matrix @ self._local_matrix(self.nodes[node_index])
            return matrix

        def walk(index: int, parent_matrix: np.ndarray) -> None:
            node = self.nodes[index]
            matrix = parent_matrix @ self._local_matrix(node)
            if "mesh" in node:
                for prim in self.gltf["meshes"][node["mesh"]]["primitives"]:
                    if prim.get("mode", 4) != 4 or "POSITION" not in prim.get("attributes", {}):
                        continue
                    pos = self._accessor(prim["attributes"]["POSITION"]).astype(np.float64)
                    homogeneous = np.c_[pos, np.ones(len(pos))] @ matrix.T
                    pts = homogeneous[:, :3]
                    if "indices" in prim:
                        idx = self._accessor(prim["indices"]).reshape(-1).astype(np.int64)
                    else:
                        idx = np.arange(len(pts))
                    idx = idx[: len(idx) // 3 * 3].reshape(-1, 3)
                    tri = pts[idx]
                    verts.append(tri)
                    colors.append(np.tile(self.material_color(prim.get("material")), (len(tri), 1)))
            for child in node.get("children", []):
                walk(child, matrix)

        for r in roots:
            walk(r, base_matrix(r) if root is not None else np.eye(4))
        if not verts:
            return Triangles(np.zeros((0, 3, 3)), np.zeros((0, 3)))
        return Triangles(np.concatenate(verts), np.concatenate(colors))
