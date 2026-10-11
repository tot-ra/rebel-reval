#!/usr/bin/env python3
"""List Godot 4 PCK contents without inferring membership from source trees.

Usage:
    python3 tools/pck_inventory.py path/to/game.pck
    python3 tools/pck_inventory.py path/to/game.pck --json out.json
    python3 tools/pck_inventory.py --app "build/Reval Rebel.app"
    python3 tools/pck_inventory.py --dmg build/rr.dmg --json out.json

Exit codes: 0 = listed, 1 = missing/invalid input, 2 = usage.
"""

from __future__ import annotations

import argparse
import json
import shutil
import struct
import subprocess
import sys
import tempfile
from collections import defaultdict
from dataclasses import asdict, dataclass
from pathlib import Path

PACK_MAGIC = 0x43504447  # "GDPC"
PACK_REL_FILEBASE = 1 << 1
PACK_FORMAT_V2 = 2
PACK_FORMAT_V3 = 3
PACK_FORMAT_V4 = 4


@dataclass(frozen=True)
class PackFile:
    path: str
    size: int
    offset: int
    flags: int


@dataclass(frozen=True)
class PackIndex:
    path: str
    pack_version: int
    godot_version: str
    pack_flags: int
    file_base: int
    files: tuple[PackFile, ...]

    @property
    def file_count(self) -> int:
        return len(self.files)

    @property
    def total_bytes(self) -> int:
        return sum(item.size for item in self.files)


def normalize_res_path(path: str) -> str:
    text = path.replace("\\", "/").split("\x00", 1)[0].strip()
    if text.startswith("res://"):
        return text
    if text.startswith("/"):
        text = text.lstrip("/")
    return f"res://{text}"


def _read_exact(handle, size: int, what: str) -> bytes:
    data = handle.read(size)
    if len(data) != size:
        raise ValueError(f"truncated PCK {what}")
    return data


def parse_pck(path: Path) -> PackIndex:
    with path.open("rb") as handle:
        header = _read_exact(handle, 24, f"header: {path}")
        magic, pack_version, major, minor, patch, pack_flags = struct.unpack("<6I", header)
        if magic != PACK_MAGIC:
            raise ValueError(f"not a Godot PCK (magic={magic:#x}): {path}")
        if pack_version not in (PACK_FORMAT_V2, PACK_FORMAT_V3, PACK_FORMAT_V4):
            raise ValueError(f"unsupported PCK version {pack_version}: {path}")
        file_base = 0
        if pack_version >= PACK_FORMAT_V2:
            (file_base,) = struct.unpack("<Q", _read_exact(handle, 8, "file_base"))
        if pack_version >= PACK_FORMAT_V3:
            # WHY: v3/v4 store the directory at the end so the pack can be written
            # in place. Seek there instead of assuming the v2 immediately-after-header layout.
            (dir_offset,) = struct.unpack("<Q", _read_exact(handle, 8, "dir_offset"))
            handle.seek(dir_offset)
        else:
            _read_exact(handle, 64, "v2 reserved header")
        (file_count,) = struct.unpack("<I", _read_exact(handle, 4, "file_count"))
        files: list[PackFile] = []
        for index in range(file_count):
            (path_length,) = struct.unpack("<I", _read_exact(handle, 4, f"path length at {index}"))
            raw_path = _read_exact(handle, path_length, f"path at {index}")
            offset, size = struct.unpack("<QQ", _read_exact(handle, 16, f"offset/size at {index}"))
            _read_exact(handle, 16, f"md5 at {index}")
            flags = 0
            if pack_version >= PACK_FORMAT_V2:
                (flags,) = struct.unpack("<I", _read_exact(handle, 4, f"flags at {index}"))
            if pack_version >= PACK_FORMAT_V3 or (pack_flags & PACK_REL_FILEBASE):
                offset = file_base + offset
            files.append(
                PackFile(
                    path=normalize_res_path(raw_path.decode("utf-8")),
                    size=size,
                    offset=offset,
                    flags=flags,
                )
            )
    return PackIndex(
        path=path.as_posix(),
        pack_version=pack_version,
        godot_version=f"{major}.{minor}.{patch}",
        pack_flags=pack_flags,
        file_base=file_base,
        files=tuple(files),
    )


def find_pck_in_app(app_path: Path) -> Path:
    resources = app_path / "Contents" / "Resources"
    if not resources.is_dir():
        raise FileNotFoundError(f"missing app Resources directory: {resources}")
    matches = sorted(resources.glob("*.pck"))
    if not matches:
        raise FileNotFoundError(f"no .pck under {resources}")
    if len(matches) > 1:
        raise ValueError(
            "multiple PCK files in app Resources: "
            + ", ".join(item.name for item in matches)
        )
    return matches[0]


def find_pck_in_dmg(dmg_path: Path, mount_parent: Path | None = None) -> tuple[Path, Path | None]:
    """Return (pck_path, mount_dir_to_detach_or_none). Caller must detach when set."""
    if shutil.which("hdiutil") is None:
        raise RuntimeError("hdiutil is required to inventory a macOS DMG")
    mount_dir = Path(tempfile.mkdtemp(prefix="rr-pck-", dir=mount_parent))
    completed = subprocess.run(
        [
            "hdiutil",
            "attach",
            str(dmg_path),
            "-nobrowse",
            "-readonly",
            "-mountpoint",
            str(mount_dir),
            "-quiet",
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        shutil.rmtree(mount_dir, ignore_errors=True)
        raise RuntimeError(
            f"hdiutil attach failed for {dmg_path}: {completed.stderr.strip()}"
        )
    try:
        apps = list(mount_dir.glob("*.app"))
        if not apps:
            raise FileNotFoundError(f"DMG has no .app: {dmg_path}")
        return find_pck_in_app(apps[0]), mount_dir
    except Exception:
        subprocess.run(
            ["hdiutil", "detach", str(mount_dir), "-quiet"],
            check=False,
            capture_output=True,
        )
        shutil.rmtree(mount_dir, ignore_errors=True)
        raise


def detach_dmg(mount_dir: Path) -> None:
    subprocess.run(
        ["hdiutil", "detach", str(mount_dir), "-quiet"],
        check=False,
        capture_output=True,
    )
    shutil.rmtree(mount_dir, ignore_errors=True)


def prefix_summary(index: PackIndex, depth: int = 2) -> list[dict[str, int | str]]:
    buckets: dict[str, list[int]] = defaultdict(lambda: [0, 0])
    for item in index.files:
        relative = item.path.removeprefix("res://")
        parts = [part for part in relative.split("/") if part]
        key = "/".join(parts[:depth]) if parts else "(root)"
        buckets[key][0] += 1
        buckets[key][1] += item.size
    rows = [
        {"prefix": key, "files": counts[0], "bytes": counts[1]}
        for key, counts in buckets.items()
    ]
    rows.sort(key=lambda row: (-int(row["bytes"]), str(row["prefix"])))
    return rows


def index_to_dict(index: PackIndex, include_files: bool = True) -> dict[str, object]:
    payload: dict[str, object] = {
        "path": index.path,
        "pack_version": index.pack_version,
        "godot_version": index.godot_version,
        "pack_flags": index.pack_flags,
        "file_count": index.file_count,
        "total_bytes": index.total_bytes,
        "prefixes": prefix_summary(index),
    }
    if include_files:
        payload["files"] = [asdict(item) for item in index.files]
    return payload


def render_summary(index: PackIndex) -> str:
    lines = [
        f"PCK: {index.path}",
        f"Godot {index.godot_version} pack v{index.pack_version}",
        f"Files: {index.file_count}",
        f"Packed bytes: {index.total_bytes}",
        "",
        "Top prefixes:",
    ]
    for row in prefix_summary(index)[:30]:
        lines.append(f"  {row['bytes']:>12}  {row['files']:>6}  {row['prefix']}")
    return "\n".join(lines)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pck", nargs="?", type=Path, help="Path to a .pck file")
    parser.add_argument("--app", type=Path, help="Path to a packaged .app")
    parser.add_argument("--dmg", type=Path, help="Path to a macOS .dmg")
    parser.add_argument("--json", type=Path, help="Write the full index JSON here")
    parser.add_argument(
        "--no-files",
        action="store_true",
        help="Omit the per-file array from JSON (keep prefix totals)",
    )
    return parser.parse_args(argv)


def resolve_pck(args: argparse.Namespace) -> tuple[Path, Path | None]:
    selected = [item for item in (args.pck, args.app, args.dmg) if item is not None]
    if len(selected) != 1:
        raise SystemExit("Specify exactly one of PCK path, --app, or --dmg")
    if args.pck is not None:
        if not args.pck.is_file():
            raise FileNotFoundError(f"missing PCK: {args.pck}")
        return args.pck, None
    if args.app is not None:
        return find_pck_in_app(args.app), None
    pck_path, mount_dir = find_pck_in_dmg(args.dmg)
    return pck_path, mount_dir


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    mount_dir: Path | None = None
    try:
        pck_path, mount_dir = resolve_pck(args)
        index = parse_pck(pck_path)
        print(render_summary(index))
        if args.json is not None:
            args.json.parent.mkdir(parents=True, exist_ok=True)
            args.json.write_text(
                json.dumps(index_to_dict(index, include_files=not args.no_files), indent=2)
                + "\n",
                encoding="utf-8",
            )
            print(f"JSON report written: {args.json.name}")
        return 0
    except (FileNotFoundError, ValueError, RuntimeError) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    finally:
        if mount_dir is not None:
            detach_dmg(mount_dir)


if __name__ == "__main__":
    raise SystemExit(main())
