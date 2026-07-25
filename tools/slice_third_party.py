"""Slice third-party asset and license helpers for P3-013."""

from __future__ import annotations

import csv
import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

NOTICE_HEADER_RE = re.compile(r"^##\s+(?P<notice_id>notice\.[a-z0-9_.]+)\s*$", re.MULTILINE)


@dataclass
class SliceThirdPartyReport:
    manifest_path: str
    notices_path: str
    direct_entry_count: int = 0
    bundle_asset_count: int = 0
    third_party_asset_count: int = 0
    errors: list[str] = field(default_factory=list)

    @property
    def valid(self) -> bool:
        return not self.errors


def load_manifest(root: Path, manifest_path: Path | None = None) -> dict[str, Any]:
    path = manifest_path or root / "docs/data/slice_third_party_manifest.json"
    return json.loads(path.read_text(encoding="utf-8"))


def read_sources(root: Path) -> dict[str, dict[str, str]]:
    sources_path = root / "assets" / "SOURCES.csv"
    with sources_path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        return {row["asset_id"]: row for row in reader if row.get("asset_id")}


def sources_by_path(root: Path) -> dict[str, dict[str, str]]:
    sources_path = root / "assets" / "SOURCES.csv"
    with sources_path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        return {row["path"]: row for row in reader if row.get("path")}


def notice_ids_in_file(path: Path) -> set[str]:
    if not path.is_file():
        return set()
    text = path.read_text(encoding="utf-8")
    return {match.group("notice_id") for match in NOTICE_HEADER_RE.finditer(text)}


def credits_has_section(path: Path, section_title: str) -> bool:
    if not path.is_file():
        return False
    return f"## {section_title}" in path.read_text(encoding="utf-8")


def is_approved_row(row: dict[str, str]) -> bool:
    approval = row.get("approval", "").strip().lower()
    return approval.startswith("approved") or approval.startswith("prototype approved")


def normalize_repo_path(root: Path, value: str) -> str:
    path = Path(value)
    if path.is_absolute():
        try:
            return path.relative_to(root).as_posix()
        except ValueError:
            return path.as_posix()
    return path.as_posix()


def collect_direct_sources_ids(entry: dict[str, Any]) -> list[str]:
    ids: list[str] = []
    single = entry.get("sources_id")
    if single:
        ids.append(str(single))
    ids.extend(str(value) for value in entry.get("sources_ids", []))
    return ids


def bundle_manifest_paths(root: Path, bundle: dict[str, Any]) -> list[str]:
    manifest_path = root / bundle["manifest_path"]
    paths: list[str] = []
    with manifest_path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            file_path = row.get("file", "").strip()
            if file_path:
                paths.append(normalize_repo_path(root, file_path))
    processed_manifest = bundle.get("processed_manifest_path")
    if processed_manifest:
        processed_path = root / processed_manifest
        with processed_path.open(newline="", encoding="utf-8") as handle:
            for row in csv.DictReader(handle):
                processed_file = row.get("processed_file", "").strip()
                if processed_file:
                    paths.append(normalize_repo_path(root, processed_file))
    return paths


def verify_direct_entry(
    root: Path,
    entry: dict[str, Any],
    *,
    sources: dict[str, dict[str, str]],
    notices: set[str],
    errors: list[str],
) -> int:
    notice_id = str(entry["notice_id"])
    if notice_id not in notices:
        errors.append(f"missing notice header for direct entry: {notice_id}")

    count = 0
    license_path = entry.get("license_path")
    if license_path:
        if not (root / license_path).is_file():
            errors.append(f"license file missing for {notice_id}: {license_path}")
        return 1

    for sources_id in collect_direct_sources_ids(entry):
        row = sources.get(sources_id)
        if row is None:
            errors.append(f"missing SOURCES.csv row for {notice_id}: {sources_id}")
            continue
        if not is_approved_row(row):
            errors.append(f"unapproved SOURCES.csv row for {notice_id}: {sources_id}")
        asset_path = root / row["path"]
        if not asset_path.is_file():
            errors.append(f"missing asset file for {notice_id}: {row['path']}")
        count += 1
    return count


def verify_bundle(
    root: Path,
    bundle: dict[str, Any],
    *,
    sources_by_asset_path: dict[str, dict[str, str]],
    notices: set[str],
    credits_path: Path,
    errors: list[str],
) -> int:
    notice_id = str(bundle["notice_id"])
    if notice_id not in notices:
        errors.append(f"missing notice header for bundle: {notice_id}")

    credits_section = str(bundle.get("credits_section", ""))
    if credits_section and not credits_has_section(credits_path, credits_section):
        errors.append(f"missing credits section for bundle {bundle['id']}: {credits_section}")

    prefix = str(bundle.get("sources_path_prefix", ""))
    count = 0
    for asset_path in bundle_manifest_paths(root, bundle):
        if prefix and not asset_path.startswith(prefix):
            errors.append(f"bundle {bundle['id']} path outside prefix {prefix}: {asset_path}")
        row = sources_by_asset_path.get(asset_path)
        if row is None:
            errors.append(f"missing SOURCES.csv row for bundle asset: {asset_path}")
            continue
        if not is_approved_row(row):
            errors.append(f"unapproved SOURCES.csv row for bundle asset: {asset_path}")
        if not (root / asset_path).is_file():
            errors.append(f"missing bundle asset file: {asset_path}")
        count += 1
    return count


def verify_export_notice_files(root: Path, manifest: dict[str, Any], errors: list[str]) -> None:
    for rel_path in manifest.get("export_notice_files", []):
        if not (root / rel_path).is_file():
            errors.append(f"export notice file missing: {rel_path}")


def build_report(root: Path, manifest_path: Path | None = None) -> SliceThirdPartyReport:
    manifest = load_manifest(root, manifest_path)
    notices_file = root / manifest["notices_path"]
    credits_file = root / manifest["credits_path"]
    report = SliceThirdPartyReport(
        manifest_path=(manifest_path or root / "docs/data/slice_third_party_manifest.json").as_posix(),
        notices_path=manifest["notices_path"],
    )
    errors = report.errors

    if not notices_file.is_file():
        errors.append(f"missing notices file: {manifest['notices_path']}")
        return report
    if not credits_file.is_file():
        errors.append(f"missing credits file: {manifest['credits_path']}")

    notices = notice_ids_in_file(notices_file)
    sources = read_sources(root)
    sources_paths = sources_by_path(root)

    verify_export_notice_files(root, manifest, errors)

    for entry in manifest.get("entries", []):
        report.direct_entry_count += verify_direct_entry(
            root,
            entry,
            sources=sources,
            notices=notices,
            errors=errors,
        )

    for bundle in manifest.get("bundles", []):
        report.bundle_asset_count += verify_bundle(
            root,
            bundle,
            sources_by_asset_path=sources_paths,
            notices=notices,
            credits_path=credits_file,
            errors=errors,
        )

    report.third_party_asset_count = report.direct_entry_count + report.bundle_asset_count
    return report


def format_report(report: SliceThirdPartyReport) -> str:
    lines = [
        "Slice third-party asset/license report (P3-013)",
        f"  manifest: {report.manifest_path}",
        f"  notices: {report.notices_path}",
        f"  direct entries: {report.direct_entry_count}",
        f"  bundled assets: {report.bundle_asset_count}",
        f"  total third-party assets checked: {report.third_party_asset_count}",
    ]
    if report.errors:
        lines.append("  errors:")
        lines.extend(f"    - {error}" for error in report.errors)
    else:
        lines.append("  status: OK")
    return "\n".join(lines)
