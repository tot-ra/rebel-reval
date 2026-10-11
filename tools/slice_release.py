"""Slice release manifest helpers for P3-015."""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
from dataclasses import dataclass, field
from pathlib import Path

GDSCRIPT_CONST_RE = re.compile(
    r"const\s+(?P<name>[A-Z0-9_]+)\s*:=\s*\"(?P<value>[^\"]*)\""
)
GDSCRIPT_INT_CONST_RE = re.compile(
    r"const\s+(?P<name>[A-Z0-9_]+)\s*:=\s*(?P<value>\d+)"
)


@dataclass
class SliceReleaseReport:
    release_tag: str = ""
    errors: list[str] = field(default_factory=list)

    @property
    def valid(self) -> bool:
        return not self.errors


def load_manifest(manifest_path: Path) -> dict:
    return json.loads(manifest_path.read_text(encoding="utf-8"))


def parse_godot_constants(model_path: Path) -> dict[str, str]:
    text = model_path.read_text(encoding="utf-8")
    constants: dict[str, str] = {
        match.group("name"): match.group("value")
        for match in GDSCRIPT_CONST_RE.finditer(text)
    }
    for match in GDSCRIPT_INT_CONST_RE.finditer(text):
        constants[match.group("name")] = match.group("value")
    return constants


def fingerprint_schema_files(root: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(root.glob("schemas/*.schema.json")):
        digest.update(path.name.encode("utf-8"))
        digest.update(path.read_bytes())
    return digest.hexdigest()


def fingerprint_content_directories(root: Path, directories: list[str]) -> str:
    digest = hashlib.sha256()
    files: list[Path] = []
    for directory in directories:
        base = root / directory
        if not base.is_dir():
            continue
        files.extend(sorted(base.rglob("*.json")))
    for path in files:
        digest.update(str(path.relative_to(root)).encode("utf-8"))
        digest.update(path.read_bytes())
    return digest.hexdigest()


def verify_manifest_matches_model(root: Path, manifest_path: Path) -> SliceReleaseReport:
    manifest = load_manifest(manifest_path)
    report = SliceReleaseReport(release_tag=str(manifest.get("release_tag", "")))

    model_path = root / str(manifest["godot_model"])
    if not model_path.is_file():
        report.errors.append(f"missing godot model: {model_path}")
        return report

    constants = parse_godot_constants(model_path)
    pairs = {
        "release_tag": "RELEASE_TAG",
        "content_schema_fingerprint": "CONTENT_SCHEMA_FINGERPRINT",
        "content_corpus_fingerprint": "CONTENT_CORPUS_FINGERPRINT",
    }
    for manifest_key, constant_name in pairs.items():
        expected = constants.get(constant_name, "")
        actual = str(manifest.get(manifest_key, ""))
        if actual != expected:
            report.errors.append(
                f"{manifest_key} mismatch: manifest {actual!r}, model {expected!r}"
            )

    int_pairs = {
        "save_envelope_version": "SAVE_ENVELOPE_VERSION",
        "game_state_version": "GAME_STATE_VERSION",
        "map_world_state_version": "MAP_WORLD_STATE_VERSION",
        "content_schema_version": "CONTENT_SCHEMA_VERSION",
    }
    for manifest_key, constant_name in int_pairs.items():
        expected = constants.get(constant_name, "")
        actual = str(manifest.get(manifest_key, ""))
        if actual != expected:
            report.errors.append(
                f"{manifest_key} mismatch: manifest {actual!r}, model {expected!r}"
            )

    fixture = manifest.get("published_save_fixture", {})
    if not isinstance(fixture, dict):
        report.errors.append("published_save_fixture must be an object")
    else:
        if fixture.get("id") != constants.get("PUBLISHED_SAVE_FIXTURE_ID"):
            report.errors.append("published save fixture id drifted from model")
        if fixture.get("path") != constants.get("PUBLISHED_SAVE_FIXTURE_PATH"):
            report.errors.append("published save fixture path drifted from model")

    schema_fp = fingerprint_schema_files(root)
    if schema_fp != str(manifest.get("content_schema_fingerprint", "")):
        report.errors.append(
            f"content_schema_fingerprint mismatch: manifest {manifest.get('content_schema_fingerprint')!r}, computed {schema_fp!r}"
        )

    corpus_fp = fingerprint_content_directories(
        root, [str(item) for item in manifest.get("content_directories", [])]
    )
    if corpus_fp != str(manifest.get("content_corpus_fingerprint", "")):
        report.errors.append(
            f"content_corpus_fingerprint mismatch: manifest {manifest.get('content_corpus_fingerprint')!r}, computed {corpus_fp!r}"
        )

    maintainer_report = root / str(manifest.get("maintainer_report", ""))
    if not maintainer_report.is_file():
        report.errors.append(f"missing maintainer report: {maintainer_report}")

    verify_script = root / str(manifest.get("verify_script", ""))
    if not verify_script.is_file():
        report.errors.append(f"missing verify script: {verify_script}")

    build_script = root / str(manifest.get("build_fixture_script", ""))
    if not build_script.is_file():
        report.errors.append(f"missing build fixture script: {build_script}")

    fixture_path = root / "content/saves" / str(fixture.get("path", ""))
    if not fixture_path.is_file():
        report.errors.append(f"missing published save fixture: {fixture_path}")

    released_manifest = root / "content/saves/released_manifest.json"
    if not released_manifest.is_file():
        report.errors.append("missing content/saves/released_manifest.json")
    else:
        released = json.loads(released_manifest.read_text(encoding="utf-8"))
        fixture_id = str(fixture.get("id", ""))
        rows = released.get("fixtures", [])
        if not any(str(row.get("id", "")) == fixture_id for row in rows if isinstance(row, dict)):
            report.errors.append(
                f"released_manifest.json does not list published fixture {fixture_id}"
            )

    tag = str(manifest.get("release_tag", ""))
    if tag:
        result = subprocess.run(
            ["git", "tag", "--list", tag],
            cwd=root,
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            report.errors.append(f"git tag lookup failed: {result.stderr.strip()}")
        elif tag not in result.stdout.splitlines():
            report.errors.append(f"git tag {tag!r} is not present in this checkout")

    return report


def format_report(report: SliceReleaseReport) -> str:
    lines = [
        "Slice release report (P3-015)",
        f"  release tag: {report.release_tag or '<missing>'}",
    ]
    if report.errors:
        lines.append("  errors:")
        for error in report.errors:
            lines.append(f"    - {error}")
    else:
        lines.append("  status: manifest, fingerprints, fixture, and tag are valid")
    return "\n".join(lines)
