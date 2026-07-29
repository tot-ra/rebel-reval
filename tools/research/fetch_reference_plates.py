#!/usr/bin/env python3
"""Fetch and verify the historical reference plates listed in ``history/reference/plates.csv``.

Reference plates are visual evidence for the research dossiers: garment cuts, floor
plans, facades, doors and ironwork, interiors, tools, ships. They are *evidence*, not
game assets. Fetched files land under ``history/reference/<domain>/<slug>/``, which is
Git-LFS tracked and hidden from Godot import by ``history/.gdignore``, and they never
appear in ``assets/SOURCES.csv``.

Only openly licensed plates are downloaded. Anything else stays a link-only row so the
manifest still records where the evidence lives without putting unclear rights in the
repository.

Usage:
    python3 tools/research/fetch_reference_plates.py --slug burgher-house-plan
    python3 tools/research/fetch_reference_plates.py --domain crafts --dry-run
    python3 tools/research/fetch_reference_plates.py --verify
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import sys
import urllib.error
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MANIFEST = REPO_ROOT / "history" / "reference" / "plates.csv"
PLATE_ROOT = REPO_ROOT / "history" / "reference"

FIELDNAMES = [
    "plate_id",
    "domain",
    "slug",
    "shows",
    "source",
    "dated",
    "origin",
    "page_url",
    "image_url",
    "creator",
    "license",
    "license_url",
    "status",
    "local_path",
    "sha256",
    "notes",
]

# Licences the project may keep a copy of. Everything else is recorded as a link only:
# the manifest still points at the evidence, the repository stays clean of unclear rights.
DOWNLOADABLE_LICENSES = {
    "public domain",
    "pd",
    "cc0",
    "cc by",
    "cc by-sa",
    "cc by 3.0",
    "cc by 4.0",
    "cc by-sa 3.0",
    "cc by-sa 4.0",
    "cc by-sa 2.0",
}

EXTENSIONS = {
    "image/jpeg": ".jpg",
    "image/jpg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/tiff": ".tif",
    "application/pdf": ".pdf",
}

# Institutional endpoints (Wikimedia in particular) reject requests without a real
# identifying User-Agent.
USER_AGENT = "RebelRevalResearchBot/1.0 (historical reference plates; contact via repository)"

# Below this a "plate" is almost always a thumbnail or an error page, not usable evidence.
MIN_BYTES = 15_000


def normalise_license(value: str) -> str:
    return value.strip().lower().replace("_", " ")


def is_downloadable(value: str) -> bool:
    return normalise_license(value) in DOWNLOADABLE_LICENSES


def load_rows(manifest: Path) -> list[dict[str, str]]:
    if not manifest.exists():
        return []
    with manifest.open(newline="", encoding="utf-8") as handle:
        return [dict(row) for row in csv.DictReader(handle)]


def save_rows(manifest: Path, rows: list[dict[str, str]]) -> None:
    manifest.parent.mkdir(parents=True, exist_ok=True)
    with manifest.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDNAMES)
        writer.writeheader()
        for row in rows:
            writer.writerow({key: row.get(key, "") for key in FIELDNAMES})


def selected(rows: list[dict[str, str]], args: argparse.Namespace) -> list[dict[str, str]]:
    out = rows
    if args.domain:
        out = [row for row in out if row.get("domain") == args.domain]
    if args.slug:
        out = [row for row in out if row.get("slug") == args.slug]
    if args.plate:
        out = [row for row in out if row.get("plate_id") == args.plate]
    return out


def download(url: str) -> tuple[bytes, str]:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        content_type = (response.headers.get("Content-Type") or "").split(";")[0].strip().lower()
        return response.read(), content_type


def fetch(rows: list[dict[str, str]], args: argparse.Namespace) -> int:
    failures = 0
    fetched = 0
    for row in selected(rows, args):
        plate_id = row.get("plate_id", "").strip()
        if not plate_id:
            continue

        if not is_downloadable(row.get("license", "")):
            row["status"] = "linked"
            row["local_path"] = ""
            row["sha256"] = ""
            continue

        if row.get("status") == "fetched" and not args.force:
            existing = REPO_ROOT / row.get("local_path", "")
            if row.get("local_path") and existing.exists():
                continue

        url = row.get("image_url", "").strip()
        if not url:
            print(f"[skip] {plate_id}: no image_url", file=sys.stderr)
            row["status"] = "linked"
            continue

        if args.dry_run:
            print(f"[dry-run] would fetch {plate_id} <- {url}")
            continue

        try:
            payload, content_type = download(url)
        except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as error:
            print(f"[fail] {plate_id}: {error}", file=sys.stderr)
            row["status"] = "failed"
            failures += 1
            continue

        extension = EXTENSIONS.get(content_type)
        if extension is None:
            print(
                f"[fail] {plate_id}: unexpected content type {content_type or 'unknown'}",
                file=sys.stderr,
            )
            row["status"] = "failed"
            failures += 1
            continue

        if len(payload) < MIN_BYTES:
            print(
                f"[fail] {plate_id}: {len(payload)} bytes is too small to be a usable plate",
                file=sys.stderr,
            )
            row["status"] = "failed"
            failures += 1
            continue

        target = PLATE_ROOT / row["domain"] / row["slug"] / f"{plate_id}{extension}"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(payload)

        row["local_path"] = str(target.relative_to(REPO_ROOT))
        row["sha256"] = hashlib.sha256(payload).hexdigest()
        row["status"] = "fetched"
        fetched += 1
        print(f"[ok] {plate_id} -> {row['local_path']} ({len(payload)} bytes)")

    if not args.dry_run:
        save_rows(args.manifest, rows)
    print(f"fetched {fetched}, failed {failures}")
    return 1 if failures else 0


def verify(rows: list[dict[str, str]], args: argparse.Namespace) -> int:
    problems: list[str] = []
    seen: set[str] = set()

    for row in selected(rows, args):
        plate_id = row.get("plate_id", "").strip()
        if not plate_id:
            problems.append("row without plate_id")
            continue
        if plate_id in seen:
            problems.append(f"{plate_id}: duplicate plate_id")
        seen.add(plate_id)

        expected_prefix = f"{row.get('domain', '')}.{row.get('slug', '')}."
        if not plate_id.startswith(expected_prefix):
            problems.append(f"{plate_id}: id does not match <domain>.<slug>.<nn>")

        for required in ("shows", "source", "dated", "license"):
            if not row.get(required, "").strip():
                problems.append(f"{plate_id}: missing {required}")

        if not row.get("page_url", "").strip():
            problems.append(f"{plate_id}: missing page_url, the plate is unciteable")

        status = row.get("status", "").strip()
        if status == "fetched":
            if not is_downloadable(row.get("license", "")):
                problems.append(f"{plate_id}: fetched under a licence that forbids storing a copy")
                continue
            local = row.get("local_path", "").strip()
            if not local:
                problems.append(f"{plate_id}: fetched without local_path")
                continue
            path = REPO_ROOT / local
            if not path.exists():
                problems.append(f"{plate_id}: {local} is missing")
                continue
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            if digest != row.get("sha256", "").strip():
                problems.append(f"{plate_id}: checksum mismatch for {local}")
        elif status not in {"linked", "pending", "failed"}:
            problems.append(f"{plate_id}: unknown status '{status}'")

    for problem in problems:
        print(f"[verify] {problem}", file=sys.stderr)
    print(f"verified {len(seen)} plates, {len(problems)} problems")
    return 1 if problems else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=MANIFEST)
    parser.add_argument("--domain", help="restrict to one dossier domain")
    parser.add_argument("--slug", help="restrict to one dossier slug")
    parser.add_argument("--plate", help="restrict to one plate_id")
    parser.add_argument("--force", action="store_true", help="re-download already fetched plates")
    parser.add_argument("--dry-run", action="store_true", help="report what would be fetched")
    parser.add_argument("--verify", action="store_true", help="check manifest and stored files only")
    args = parser.parse_args()

    rows = load_rows(args.manifest)
    if not rows:
        print(f"no plates listed in {args.manifest}")
        return 0

    return verify(rows, args) if args.verify else fetch(rows, args)


if __name__ == "__main__":
    raise SystemExit(main())
